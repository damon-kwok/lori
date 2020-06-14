use "collections"

actor TCPConnection
  var _fd: U32 = -1
  var _event: AsioEventID = AsioEvent.none()
  var _state: U32 = 0
  
  let _pending: List[(ByteSeq, USize)] = _pending.create()
  var _read_buffer: Array[U8] iso = recover Array[U8] end
  var _bytes_in_read_buffer: USize = 0
  var _read_buffer_size: USize = 16384
  var _expect: USize = 0

  let _on_closed: {()} val
  let _on_received: {(Array[U8] iso)} val
  let _on_throttled: {()} val
  let _on_unthrottled: {()} val
  let _on_connected: {()} val

  new client(auth: TCPConnectorAuth,
    host: String,
    port: String,
    from: String,
    out : OutStream,
    on_connected: (None | {()} val) =None,
    on_closed: (None | {()} val) =None,
    on_received: (None | {(Array[U8] iso)} val) =None,
    on_throttled: (None | {()} val) = None,
    on_unthrottled: (None | {()} val) =None)
  =>
    // TODO: handle happy eyeballs here - connect count
    _on_closed = match on_closed
    | let fn: {()} val => fn
    else {()=> out.print("Connection Closed.") }
    end
    _on_connected = match on_connected
    | let fn: {()} val => fn
    else {()=> out.print("We have a new connection!") }
    end
    _on_received = match on_received
    | let fn: {(Array[U8] iso)} val => fn
    else {(data: Array[U8] iso)=> out.print("Data received. Echoing it back..") }
    end
    _on_throttled = match on_throttled
    | let fn: {()} val => fn
    else {()=> out.print("Throttled!") }
    end
    _on_unthrottled = match on_unthrottled
    | let fn: {()} val => fn
    else {()=> out.print("Unthrottled!") }
    end
    PonyTCP.connect(this, host, port, from,
      AsioEvent.read_write_oneshot())

  new accept(auth: TCPAcceptorAuth,
    fd': U32,
    out : OutStream,
    on_closed: (None | {()} val) = None,
    on_received: (None | {(Array[U8] iso)} val) =None,
    on_throttled: (None | {()} val) =None,
    on_unthrottled: (None | {()} val) = None)
  =>
    _fd = fd'
    _on_closed = match on_closed
    | let fn: {()} val => fn
    else {()=> out.print("Connection Closed.") }
    end
    _on_connected = {()=> None }
    _on_received = match on_received
    | let fn: {(Array[U8] iso)} val => fn
    else {(data: Array[U8] iso)=> out.print("Data received. Echoing it back..") }
    end
    _on_throttled = match on_throttled
    | let fn: {()} val => fn
    else {()=> out.print("Throttled!") }
    end
    _on_unthrottled = match on_unthrottled
    | let fn: {()} val => fn
    else {()=> out.print("Unthrottled!") }
    end
    _event = PonyAsio.create_event(this, _fd)
    _open()

  new none() =>
    // """
    // For initializing an empty variable
    // """
    // _enclosing = None
    _on_closed = {()=> None }
    _on_connected = {()=> None }
    _on_received = {(data: Array[U8] iso)=> None }
    _on_throttled = {()=> None }
    _on_unthrottled = {()=> None }

  fun ref expect(qty: USize) ? =>
    if qty <= _read_buffer_size then
      _expect = qty
    else
      // saying you want a chunk larger than the max size would result
      // in a livelock of never being able to read it as we won't allow
      // you to surpass the max buffer size
      error
    end

  fun ref _open() =>
    // TODO: should this be private? I think so.
    // I don't think the actor that is using the connection should
    // ever need this.
    // client-  open() gets called from our event_notify
    // server- calls this
    //
    // seems like no need to call from external
    _state = BitSet.set(_state, 0)
    writeable()

  fun is_open(): Bool =>
    BitSet.is_set(_state, 0)

  be close() =>
    if is_open() then
      _state = BitSet.unset(_state, 0)
      unwriteable()
      PonyTCP.shutdown(_fd)
      PonyAsio.unsubscribe(_event)
      _fd = -1
    end

  fun is_closed(): Bool =>
    not is_open()

  be send(data: ByteSeq) =>
    if is_open() then
      if is_writeable() then
        if has_pending_writes() then
          try
            let len = PonyTCP.send(_event, data)?
            if (len < data.size()) then
              // unable to write all data
              _pending.push((data, len))
              _apply_backpressure()
            end
          else
            // TODO: is there any way to get here if connnection is open?
            return
          end
        else
          _pending.push((data, 0))
          _send_pending_writes()
        end
      else
        _pending.push((data, 0))
      end
    else
      // TODO: handle trying to send on a closed connection
      // maybe an error?
      return
    end

  fun ref _send_pending_writes() =>
    while is_writeable() and has_pending_writes() do
      try
        let node = _pending.head()?
        (let data, let offset) = node()?

        let len = PonyTCP.send(_event, data, offset)?

        if (len + offset) < data.size() then
          // not all data was sent
          node()? = (data, offset + len)
          _apply_backpressure()
        else
          _pending.shift()?
        end
      else
        // error sending. appears our connection has been shutdown.
        // TODO: handle close here
        None
      end
    end

    if has_pending_writes() then
      // all pending data was sent
      _release_backpressure()
    end

  fun is_writeable(): Bool =>
    BitSet.is_set(_state, 1)

  fun ref writeable() =>
    _state = BitSet.set(_state, 1)

  be unwriteable() =>
    _state = BitSet.unset(_state, 1)

  fun ref _read() =>
    try
      if is_open() then
        var total_bytes_read: USize = 0

        // TODO: this probably shouldn't be "while true"
        while true do
          // Handle any data already in the read buffer
          while _there_is_buffered_read_data() do
            let bytes_to_consume = if _expect == 0 then
              // if we aren't getting in `_expect` chunks,
              // we should grab all the bytes that are currently available
              _bytes_in_read_buffer
            else
              _expect
            end

            let x = _read_buffer = recover Array[U8] end
            (let data', _read_buffer) = (consume x).chop(bytes_to_consume)
            _bytes_in_read_buffer = _bytes_in_read_buffer - bytes_to_consume

            _on_received(consume data')
          end

          if total_bytes_read >= _read_buffer_size then
            _read_again()
            return
          end

          _resize_read_buffer_if_needed()

          let bytes_read = PonyTCP.receive(_event,
            _read_buffer.cpointer(_bytes_in_read_buffer),
            _read_buffer.size() - _bytes_in_read_buffer)?

          if bytes_read == 0 then
            // would block. try again later
            _mark_unreadable()
            return
          end

          _bytes_in_read_buffer = _bytes_in_read_buffer + bytes_read
          total_bytes_read = total_bytes_read + bytes_read
        end
      end
    else
      // Socket shutdown from other side
      close()
    end

  fun _there_is_buffered_read_data(): Bool =>
    (_bytes_in_read_buffer >= _expect) and (_bytes_in_read_buffer > 0)

  fun ref _resize_read_buffer_if_needed() =>
    """
    Resize the read buffer if it's empty or smaller than expected data size
    """
    if _read_buffer.size() <= _expect then
      _read_buffer.undefined(_read_buffer_size)
    end

  fun ref _apply_backpressure() =>
    if not is_throttled() then
      throttled()
      _on_throttled()
    end

  fun ref _release_backpressure() =>
    if is_throttled() then
      unthrottled()
      _on_unthrottled()
    end

  fun is_throttled(): Bool =>
    BitSet.is_set(_state, 2)

  fun ref throttled() =>
    _state = BitSet.set(_state, 2)
    // throttled means we are also unwriteable
    // being unthrottled doesn't however mean we are writable
    unwriteable()
    PonyAsio.set_unwriteable(_event)
    PonyAsio.resubscribe_write(_event)

  fun ref unthrottled() =>
    _state = BitSet.unset(_state, 2)

  fun has_pending_writes(): Bool =>
    _pending.size() != 0

  be _event_notify(event: AsioEventID,
    flags: U32,
    arg: U32)
  =>
    if event isnt _event then
      if AsioEvent.writeable(flags) then
        // TODO: this assumes the connection succeed. That might not be true.
        // more logic needs to go here
        _fd = PonyAsio.event_fd(event)
        _event = event
        _open()
        _on_connected()
        _read()
      end
    end

    if event is _event then
      if AsioEvent.readable(flags) then
        // should set that we are readable
        _read()
      end

      if AsioEvent.writeable(flags) then
        writeable()
        _send_pending_writes()
      end

      if AsioEvent.disposable(flags) then
        PonyAsio.destroy(event)
        _event = AsioEvent.none()
      end
    end

  fun _mark_unreadable() =>
    PonyAsio.set_unreadable(_event)
    // TODO: should be able to switch from one-shot to edge-triggered without
    // changing this. need a switch based on flags that we do not have at
    // the moment
    PonyAsio.resubscribe_read(_event)

  be _read_again() =>
    """
    Resume reading
    """
    _read()
