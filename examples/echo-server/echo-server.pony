use "../../lori"

actor Main
  new create(env: Env) =>
    TCPServer[EchoServer].listen("0.0.0.0", 7669, env)

actor EchoServer is TCPListenerActor
  var _listener: TCPListener  = TCPListener.none()
  new create(a: TCPListener iso)=>
    _listener = consume a
    _listener.listen(this)
    
  fun ref listener(): TCPListener =>
    _listener

  fun ref on_accept(fd: U32): TCPConnectionActor =>
    try
      let auth = TCPAcceptAuth(listener().auth as TCPListenerAuth)
      Echoer(recover TCPConnection.accept(auth, fd) end)
    else
      Echoer(recover TCPConnection.none() end)
    end

  fun ref on_closed() =>
    _listener.log("Echo server shut down.")

  fun ref on_failure() =>
    _listener.log("Couldn't start Echo server. " +
      "Perhaps try another network interface?")

  fun ref on_listening() =>
    _listener.log("Echo server started.")

actor Echoer is TCPAcceptorActor
  var _connection: TCPConnection = TCPConnection.none()
    
  new create(conn: TCPConnection iso)=>
    _connection = consume conn

  be bind(conn: TCPConnection iso) => _connection = consume conn

  fun ref connection(): TCPConnection =>
    _connection

  fun ref on_closed() =>
    _connection.log("Connection Closed")

  fun ref on_connected(conn: TCPConnection ref) =>
    _connection.log("We have a new connection!")

  fun ref on_received(data: Array[U8] iso) =>
    _connection.log("Data received. Echoing it back.")
    _connection.send(consume data)
