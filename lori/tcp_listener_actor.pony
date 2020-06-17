interface tag TCPListenerActor//[A: TCPAcceptorActor]
  new tag create(a: TCPListener iso)

  fun ref listener(): TCPListener

  fun ref on_accept(fd: U32): TCPConnectionActor// =>
    """
    Called when a connection is accepted
    """
    /*
    recover
    let c = A
    // var o:TCPConnection iso = recover TCPConnection.none() end
    // c.bind(consume o)
    // let auth = TCPAcceptAuth(listener().auth)
    // c.bind(recover TCPConnection.accept(auth, fd, c) end)
    c.bind(recover TCPConnection.none() end)
    c
    end*/

  fun ref on_closed() =>
    """
    Called after the listener is closed
    """
    None

  fun ref on_failure() =>
    """
    Called if we are unable to open the listener
    """
    None

  fun ref on_listening() =>
    """
    Called once the listener is ready to accept connections
    """
    None

  be dispose() =>
    """
    Stop listening
    """
    listener().close()

  be _event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    listener().event_notify(event, flags, arg)
