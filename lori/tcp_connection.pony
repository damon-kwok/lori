use "collections"

class TCPConnection
  var fd: U32
  var event: AsioEventID = AsioEvent.none()
  var _state: U32 = 0
  let _pending: List[(ByteSeq, USize)] = _pending.create()

  new client() =>
    fd = -1

  new server(fd': U32) =>
    fd = fd'

  fun ref open() =>
    _state = BitSet.set(_state, 0)
    writeable()

  fun is_open(): Bool =>
    BitSet.is_set(_state, 0)

  fun ref close() =>
    if is_open() then
      _state = BitSet.unset(_state, 0)
      unwriteable()
      PonyTCP.shutdown(fd)
      PonyASIO.unsubscribe(event)
      fd = -1
    end

  fun is_closed(): Bool =>
    not is_open()

  fun ref send(sender: TCPConnectionActor ref, data: ByteSeq) =>
    if is_open() then
      if is_writeable() then
        if has_pending_writes() then
          try
            let len = PonyTCP.send(event, data)?
            if (len < data.size()) then
              // unable to write all data
              _pending.push((data, len))
              _apply_backpressure(sender)
            end
          else
            // TODO: is there any way to get here if connnection is open?
            return
          end
        else
          _pending.push((data, 0))
          _send_pending_writes(sender)
        end
      else
        _pending.push((data, 0))
      end
    end

  fun ref _send_pending_writes(sender: TCPConnectionActor ref) =>
    while is_writeable() and has_pending_writes() do
      try
        let node = _pending.head()?
        (let data, let offset) = node()?

        let len = PonyTCP.send(event, data, offset)?

        if (len + offset) < data.size() then
          // not all data was sent
          node()? = (data, offset + len)
          _apply_backpressure(sender)
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
      _release_backpressure(sender)
    end

  fun is_writeable(): Bool =>
    BitSet.is_set(_state, 1)

  fun ref writeable() =>
    _state = BitSet.set(_state, 1)

  fun ref unwriteable() =>
    _state = BitSet.unset(_state, 1)

  fun ref _apply_backpressure(sender: TCPConnectionActor ref) =>
    if not is_throttled() then
      throttled()
      sender.on_throttled()
    end

  fun ref _release_backpressure(sender: TCPConnectionActor ref) =>
    if is_throttled() then
      unthrottled()
      sender.on_unthrottled()
    end

  fun is_throttled(): Bool =>
    BitSet.is_set(_state, 2)

  fun ref throttled() =>
    _state = BitSet.set(_state, 2)
    // throttled means we are also unwriteable
    // being unthrottled doesn't however mean we are writable
    unwriteable()
    PonyASIO.set_unwriteable(event)

  fun ref unthrottled() =>
    _state = BitSet.unset(_state, 2)

  fun has_pending_writes(): Bool =>
    _pending.size() != 0
