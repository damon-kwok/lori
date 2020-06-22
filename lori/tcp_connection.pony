use "collections"

actor TCPConnection[A: Any #send = None]
  var _fd: U32 = -1
  // var _host: String =""
  // var _port: U32 = 0
  // var _from: String = ""
  var _event: AsioEventID = AsioEvent.none()
  var _state: U32 = 0
  var storage: A!
  var kv: Map[String, A!] =Map[String, A!]

  let _pending: List[(ByteSeq, USize)] = _pending.create()
  var _read_buffer: Array[U8] iso = recover Array[U8] end
  var _bytes_in_read_buffer: USize = 0
  var _read_buffer_size: USize = 16384
  var _expect_size: USize = 0

  var _on_conn: {(TCPConnection[A] ref)} val
  var _on_disconn: {(TCPConnection[A] ref)} val
  var _on_data: {(TCPConnection[A] ref, Array[U8] iso)} val
  // var _on_cmd: {(TCPConnection[A] ref, U32, Array[Any] iso)} val
  var _on_log: {(TCPConnection[A] ref, ByteSeq)} val = {(self: TCPConnection[A] ref, data: ByteSeq)=> None }
  var _on_throttled: {(TCPConnection[A] ref)} val
  var _on_unthrottled: {(TCPConnection[A] ref)} val

  new create(auth: TCPConnectorAuth,
    storage': A,
    on_conn: (None | {(TCPConnection[A] ref)} val) =None,
    on_disconn: (None | {(TCPConnection[A] ref)} val) =None,
    on_data: (None | {(TCPConnection[A] ref, Array[U8] iso)} val) =None,
    on_throttled: (None | {(TCPConnection[A] ref)} val) =None,
    on_unthrottled: (None | {(TCPConnection[A] ref)} val) =None)
  =>
    // TODO: handle happy eyeballs here - connect count
    storage = consume storage'
    _on_conn = match on_conn
    | let fn: {(TCPConnection[A] ref)} val => fn
    else {(self: TCPConnection[A] ref)=> self.log("Connection!") }
    end
    _on_disconn = match on_disconn
    | let fn: {(TCPConnection[A] ref)} val => fn
    else {(self: TCPConnection[A] ref)=> self.log("Disconnected!") }
    end
    _on_data = match on_data
    | let fn: {(TCPConnection[A] ref, Array[U8] iso)} val => fn
    else {(self: TCPConnection[A] ref, data: Array[U8] iso)=> self.log("Data received. Echoing it back.") }
    end
    // _on_cmd = {(self: TCPConnection[A] ref, cmd: U32, args: Array[Any] iso)=> None }
    _on_throttled = match on_throttled
    | let fn: {(TCPConnection[A] ref)} val => fn
    else {(self: TCPConnection[A] ref)=> self.log("Throttled!") }
    end
    _on_unthrottled = match on_unthrottled
    | let fn: {(TCPConnection[A] ref)} val => fn
    else {(self: TCPConnection[A] ref)=> self.log("Unthrottled!") }
    end

  // new _accept[L: Any #send](//listen: TCPListener[L,A],
  new _accept(
    // auth: TCPAcceptorAuth,
    fd': U32,
    storage': A!,
    fn_conn: {(TCPConnection[A] ref)} val,
    fn_disconn: {(TCPConnection[A] ref)} val,
    fn_data: {(TCPConnection[A] ref, Array[U8] iso)} val)
  =>
    _fd = fd'
    storage = consume storage'
    _on_conn = fn_conn
    _on_disconn = fn_disconn
    _on_data = fn_data
    // _on_cmd = {(self: TCPConnection[A] ref, cmd: U32, args: Array[Any] iso)=> None }
    _on_throttled = {(self: TCPConnection[A] ref)=> None }
    _on_unthrottled = {(self: TCPConnection[A] ref)=> None }
    _event = PonyAsio.create_event(this, _fd)
    _on_conn(this)
    _open()

  new none(storage': A) =>
    """
    For initializing an empty variable
    """
    storage = consume storage'
    _on_disconn = {(self: TCPConnection[A] ref)=> None }
    _on_conn = {(self: TCPConnection[A] ref)=> None }
    _on_data = {(self: TCPConnection[A] ref, data: Array[U8] iso)=> None }
    // _on_cmd = {(self: TCPConnection[A] ref, cmd: U32, args: Array[Any] iso)=> None }
    _on_throttled = {(self: TCPConnection[A] ref)=> None }
    _on_unthrottled = {(self: TCPConnection[A] ref)=> None }

  be start(host: String, port: U32, from: String="")=>
    if is_closed() then
      PonyTCP.connect(this, host, port.string(), from,
      AsioEvent.read_write_oneshot())
    end

  be on(ev: TCPConnectEvent, f: ({(TCPConnection[A] ref)} val | {(TCPConnection[A] ref, Array[U8] iso)} val)) =>
    match ev
    | CONN => try _on_conn = (f as {(TCPConnection[A] ref)} val) end
    | DISCONN => try _on_disconn = (f as {(TCPConnection[A] ref)} val) end
    | DATA => try _on_data = (f as {(TCPConnection[A] ref, Array[U8] iso)} val) end
    // | CMD => try _on_cmd = (f as {(TCPConnection[A] ref, U32, Array[Any] iso)} val) end
    | LOG => try _on_log = (f as {(TCPConnection[A] ref, ByteSeq)} val) end
    | THROTTLED => try _on_throttled = (f as {(TCPConnection[A] ref)} val) end
    | UNTHROTTLED => try _on_unthrottled = (f as {(TCPConnection[A] ref)} val) end
    end

  be command(f: {(TCPConnection[A] ref)} val) =>
    f(this)

  fun ref log(data: ByteSeq) =>
    _on_log(this, data)

  fun ref expect(qty: USize) ? =>
    if qty <= _read_buffer_size then
      _expect_size = qty
    else
      // saying you want a chunk larger than the max size would result
      // in a livelock of never being able to read it as we won't allow
      // you to surpass the max buffer size
      error
    end

  fun ref _open() =>
    """
    TODO: should this be private? I think so.
    I don't think the actor that is using the connection should
    ever need this.
    client-  open() gets called from our event_notify
    server- calls this
    
    seems like no need to call from external
    """
    _state = BitSet.set(_state, 0)
    _writeable()

  fun is_open(): Bool =>
    BitSet.is_set(_state, 0)

  be close() =>
    if is_open() then
      _state = BitSet.unset(_state, 0)
      _unwriteable()
      PonyTCP.shutdown(_fd)
      PonyAsio.unsubscribe(_event)
      _fd = -1
    end

  fun is_closed(): Bool =>
    not is_open()

  be send(data: ByteSeq) =>
    if is_open() then
      if _is_writeable() then
        if _has_pending_writes() then
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
    while _is_writeable() and _has_pending_writes() do
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

    if _has_pending_writes() then
      // all pending data was sent
      _release_backpressure()
    end

  fun _is_writeable(): Bool =>
    BitSet.is_set(_state, 1)

  fun ref _writeable() =>
    _state = BitSet.set(_state, 1)

  fun ref _unwriteable() =>
    _state = BitSet.unset(_state, 1)

  fun ref _read() =>
    try
      if is_open() then
        var total_bytes_read: USize = 0

        // TODO: this probably shouldn't be "while true"
        while true do
          // Handle any data already in the read buffer
          while _there_is_buffered_read_data() do
            let bytes_to_consume = if _expect_size == 0 then
              // if we aren't getting in `_expect_size` chunks,
              // we should grab all the bytes that are currently available
              _bytes_in_read_buffer
            else
              _expect_size
            end

            let x = _read_buffer = recover Array[U8] end
            (let data', _read_buffer) = (consume x).chop(bytes_to_consume)
            _bytes_in_read_buffer = _bytes_in_read_buffer - bytes_to_consume

            _on_data(this, consume data')
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
    (_bytes_in_read_buffer >= _expect_size) and (_bytes_in_read_buffer > 0)

  fun ref _resize_read_buffer_if_needed() =>
    """
    Resize the read buffer if it's empty or smaller than expected data size
    """
    if _read_buffer.size() <= _expect_size then
      _read_buffer.undefined(_read_buffer_size)
    end

  fun ref _apply_backpressure() =>
    if not _is_throttled() then
      _throttled()
      _on_throttled(this)
    end

  fun ref _release_backpressure() =>
    if _is_throttled() then
      _unthrottled()
      _on_unthrottled(this)
    end

  fun _is_throttled(): Bool =>
    BitSet.is_set(_state, 2)

  fun ref _throttled() =>
    _state = BitSet.set(_state, 2)
    // throttled means we are also unwriteable
    // being unthrottled doesn't however mean we are writable
    _unwriteable()
    PonyAsio.set_unwriteable(_event)
    PonyAsio.resubscribe_write(_event)

  fun ref _unthrottled() =>
    _state = BitSet.unset(_state, 2)

  fun _has_pending_writes(): Bool =>
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
        _on_conn(this)
        _read()
      end
    end

    if event is _event then
      if AsioEvent.readable(flags) then
        // should set that we are readable
        _read()
      end

      if AsioEvent.writeable(flags) then
        _writeable()
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

  fun ref _read_again() =>
    """
    Resume reading
    """
    _read()

  be dispose() =>
    """
    Stop listening
    """
    close()
