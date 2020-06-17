use "../../lori"


/*
interface tag Createable
  new tag create()

actor Act is Createable
  new create() =>None
    
primitive Lis[A: Createable tag = Act]
  fun listen(port:U32):(U32, A) =>
    let a = A
    (port, a)
*/

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

  fun ref on_closed() => None
    // _listener.out.print("Echo server shut down.")

  fun ref on_failure() => None
    // _listener.out.print("Couldn't start Echo server. " +
      // "Perhaps try another network interface?")

  fun ref on_listening() => None
    // _listener.out.print("Echo server started.")

actor Echoer is TCPAcceptorActor
  var _connection: TCPConnection = TCPConnection.none()
    
  new create(conn: TCPConnection iso)=>
    _connection = consume conn

  be bind(conn: TCPConnection iso) => _connection = consume conn

  fun ref connection(): TCPConnection =>
    _connection

  fun ref on_closed() => None
    // _out.print("Connection Closed")

  fun ref on_connected(conn: TCPConnection ref) => None
    // _out.print("We have a new connection!")

  fun ref on_received(data: Array[U8] iso) =>
    // _out.print("Data received. Echoing it back.")
    _connection.send(consume data)
