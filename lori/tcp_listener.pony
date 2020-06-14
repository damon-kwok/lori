actor TCPListener
  var _host: String ="0.0.0.0"
  var _port: String =""
  var _fd: U32 = -1
  let _auth: TCPListenerAuth val
  var _state: TCPConnectionState = Closed
  var _event: AsioEventID = AsioEvent.none()
  let _on_accept: {(U32): TCPConnection} val
  let _on_closed: {()} val
  let _on_failure: {()} val
  let _on_listening: {()} val

  new create(auth: TCPListenerAuth,
    out: OutStream,
    on_accept': (None | {(U32): TCPConnection} val) = None,
    on_closed': (None | {()} val) = None,
    on_failure': (None | {()} val) =None,
    on_listening': (None | {()} val) =None)
  =>
    _auth = auth
    _on_accept = match on_accept'
    | let fn: {(U32): TCPConnection} val => fn
    else
      {(fd: U32):TCPConnection => TCPConnection.accept(TCPAcceptAuth(auth), fd, out) }
    end

    _on_closed = match on_closed'
    | let fn: {()} val => fn
    else {()=> out.print("Echo server shut down.") }
    end
    _on_failure = match on_failure'
    | let fn: {()} val => fn
    else {()=> out.print("Couldn't start Echo server. Perhaps try another network interface?") }
    end
    _on_listening = match on_listening'
    | let fn: {()} val => fn
    else {()=> out.print("Echo server started.") }
    end

  be listen(host: String val, port: String val) =>
    _host = host
    _port = port
    let event = PonyTCP.listen(this, _host, _port)
    if not event.is_null() then
      _fd = PonyAsio.event_fd(event)
      _event = event
      _state = Open
      _on_listening()
    else
      _on_failure()
      None
    end

  be close() =>
    if _state is Open then
      _state = Closed  
      if not _event.is_null() then
        PonyAsio.unsubscribe(_event)
        PonyTCP.close(_fd)
        _fd = -1
        _on_closed()
      end
    end

  be event_notify(flags: U32, arg: U32) =>
    _event_notify(_event, flags, arg)
  
  be _event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    if event isnt _event then
      return
    end

    if AsioEvent.disposable(flags) then
      PonyAsio.destroy(_event)
      _event = AsioEvent.none()
      _state = Closed
    end

  fun ref _accept(arg: U32) =>
    match _state
    | Closed =>
      // It's possible that after closing, we got an event for a connection
      // attempt. If that is the case or the listener is otherwise not open,
      // return and do not start a new connection
      return
    | Open =>
      while true do
        var fd = PonyTCP.accept(_event)
        match fd
        | -1 => None // Wouldn't block but we got an error. Keep trying.          
        | 0 => return // Would block. Bail out.
        else
          _on_accept(fd) 
          return
        end
      end
    end
