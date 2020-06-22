type TCPListenerAuth is (AmbientAuth | NetAuth | TCPAuth | TCPListenAuth)

primitive TCPListener
  // let host: String
  // let port: String
  // var _event: AsioEventID = AsioEvent.none()
  // var _fd: U32 = -1
  // var state: TCPConnectionState = Closed
  // var _enclosing: (TCPListenerActor ref | None)

  fun listen(auth: TCPListenerAuth, host': String, port': String,
    enclosing: TCPListenerActor ref):(String, String, AsioEventID, U32):TCPListenerActor
  =>
    // host = host'
    // port = port'
    // _enclosing = enclosing
    
    // var _event: AsioEventID = AsioEvent.none()
    var _fd: U32 = -1
    var state: TCPConnectionState = Closed
    var _enclosing: (TCPListenerActor ref | None) =enclosing 
  
    let event = PonyTCP.listen(enclosing, host, port)
    if not event.is_null() then
      _fd = PonyAsio.event_fd(event)
      _event = event
      state = Open
      enclosing.on_listening()
    else
      enclosing.on_failure()
    end
    (host', port', event, _fd, state)

  // new none() =>
    // host = ""
    // port = ""
    // _enclosing = None

  fun ref close() =>
    match _enclosing
    | let e: TCPListenerActor ref =>
      // TODO: when in debug mode we should blow up if listener is closed
      if state is Open then
        state = Closed

        if not _event.is_null() then
          PonyAsio.unsubscribe(_event)
          PonyTCP.close(_fd)
          _fd = -1
          e.on_closed()
        end
      end
    | None =>
      // TODO: blow up here, deal with this
      None
    end

  fun ref event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    if event isnt _event then
      return
    end

    if AsioEvent.readable(flags) then
      _accept(arg)
    end

    if AsioEvent.disposable(flags) then
      PonyAsio.destroy(_event)
      _event = AsioEvent.none()
      state = Closed
    end

  fun ref _accept(arg: U32) =>
    match _enclosing
    | let e: TCPListenerActor ref =>
      match state
      | Closed =>
        // It's possible that after closing, we got an event for a connection
        // attempt. If that is the case or the listener is otherwise not open,
        // return and do not start a new connection
        return
      | Open =>
        while true do
          var fd = PonyTCP.accept(_event)

          match fd
            | -1 =>
            // Wouldn't block but we got an error. Keep trying.
            None
            | 0 =>
            // Would block. Bail out.
            return
          else
            e.on_accept(fd)
            return
          end
        end
      end
    | None =>
      // TODO: blow up here!
      None
    end
