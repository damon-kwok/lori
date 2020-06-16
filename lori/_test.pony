use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_BitSet)
    // test(_TCPConnectionState)
    test(_PingPong)
    // test(_TestBasicExpect)

class iso _BitSet is UnitTest
  fun name(): String => "BitSet"

  fun apply(h: TestHelper) =>
    var x: U32 = 0

    h.assert_false(BitSet.is_set(x, 0))
    x = BitSet.set(x, 0)
    h.assert_true(BitSet.is_set(x, 0))
    x = BitSet.set(x, 0)
    h.assert_true(BitSet.is_set(x, 0))

    h.assert_false(BitSet.is_set(x, 1))
    x = BitSet.set(x, 1)
    h.assert_true(BitSet.is_set(x, 0))
    h.assert_true(BitSet.is_set(x, 1))

    x = BitSet.unset(x, 0)
    h.assert_false(BitSet.is_set(x, 0))
    h.assert_true(BitSet.is_set(x, 1))

class iso _TCPConnectionState is UnitTest
  """
  Test that connection state works correctly
  """
  fun name(): String => "ConnectionState"

  fun tag apply(h: TestHelper) =>
    // TODO: turn this into several different tests
    let a = TCPConnection.none()

    // a.is_open()
    // h.assert_false(a.is_open())
    // a.open()
    // h.assert_true(a.is_open())
    // a.close()
    // h.assert_true(a.is_closed())
    // a.open()
    // h.assert_true(a.is_open())
    // h.assert_true(a.is_writeable())
    // h.assert_true(a.is_open())
    // a.throttled()
    // h.assert_true(a.is_throttled())
    // h.assert_false(a.is_writeable())
    // h.assert_true(a.is_open())
    // a.writeable()
    // h.assert_true(a.is_writeable())
    // a.writeable()
    // h.assert_true(a.is_writeable())

class iso _PingPong is UnitTest
  """
  Test sending and receiving via a simple Ping-Pong application
  """
  fun name(): String => "PingPong"

  fun apply(h: TestHelper) =>
    h.log("test==ping-pong>")
    try
      let svr_auth = TCPListenAuth(h.env.root as AmbientAuth)
      let svr = TCPListener(svr_auth, h.env.out)

      let ping_auth = TCPConnectAuth(h.env.root as AmbientAuth)
      var ping= TCPConnection(ping_auth, h.env.out)

      let on_cli_data = {(d: Array[U8] iso)=>
        try
          let str = String.from_array(consume d)
          let n = str.read_int[I32]()?._1
          if n < 10 then ping.send((n+1).string()) else h.complete(true) end
        end
        }val
            
      ping
      .> on(CONN,{()=> h.log("ping-start");ping.send("0")})
      .> on(DATA, on_cli_data)

      let on_data = {(c: TCPConnection, d: Array[U8] iso) =>
        try
          let str = String.from_array(consume d)
          let n = str.read_int[I32]()?._1 + 1
          if n < 10 then ping.send(n.string()) else h.complete(true) end
        end
        } val
        
      svr
      .> on(DATA, on_data)
      .> on(START,{()=> ping.start("127.0.0.1", 7671, "") })
      .> on(STOP,{()=> ping.dispose() })
      .> on(ERROR,{()=> h.fail("Unable to open _TestPongerListener") })
      .> on(CONN,{(c: TCPConnection)=> h.log("has new conn!!!")})
      .> on(DISCONN,{(c: TCPConnection)=> c.dispose() })
      .> listen("0.0.0.0", 7671)
      
      h.dispose_when_done(svr)
    end

    h.long_test(5_000_000_000)
/*
class iso _TestBasicExpect is UnitTest
  fun name(): String => "TestBasicExpect"

  fun apply(h: TestHelper) =>
    h.expect_action("server listening")
    h.expect_action("client connected")
    h.expect_action("expected data received")

    try
      let la = TCPListenAuth(h.env.root as AmbientAuth)
      let ca = TCPConnectAuth(h.env.root as AmbientAuth)
      let s = _TestBasicExpectListener(la, ca, h)

      h.dispose_when_done(s)
    else
      h.fail("unable to start _TestBasicExpect")
    end

    h.long_test(2_000_000_000)

actor _TestBasicExpectClient// is TCPClientActor
  var _connection: TCPConnection = TCPConnection.none()
  let _h: TestHelper

  new create(auth: TCPConnectorAuth, h: TestHelper) =>
    _h = h
    _connection = TCPConnection.client(auth, "127.0.0.1", "7670", "", this)

  fun ref connection(): TCPConnection =>
    _connection

  fun ref on_connected() =>
    _h.complete_action("client connected")
    _connection.send("hi there, how are you???")

  fun ref on_received(data: Array[U8] iso) =>
    _h.fail("Client shouldn't get data")
actor _TestBasicExpectListener// is TCPListenerActor
  let _h: TestHelper
  var _listener: TCPListener = TCPListener.none()
  let _server_auth: TCPListenAuth
  let _client_auth: TCPConnectAuth
  var _client: (_TestBasicExpectClient | None) = None

  new create(listener_auth: TCPListenerAuth,
    client_auth: TCPConnectAuth,
    h: TestHelper)
  =>
    _h = h
    _client_auth = client_auth
    _server_auth = TCPListenAuth(listener_auth)
    _listener = TCPListener(listener_auth, "127.0.0.1", "7670", this)

  fun ref listener(): TCPListener =>
    _listener

  fun ref on_accept(fd: U32): _TestBasicExpectServer =>
    _TestBasicExpectServer(_server_auth, fd, _h)

  fun ref on_closed() =>
    try (_client as _TestBasicExpectClient).dispose() end

  fun ref on_listening() =>
    _h.complete_action("server listening")
    _client =_TestBasicExpectClient(_client_auth, _h)

  fun ref on_failure() =>
    _h.fail("Unable to open _TestBasicExpectListener")

actor _TestBasicExpectServer// is TCPServerActor
  let _h: TestHelper
  var _connection: TCPConnection = TCPConnection.none()
  var _received_count: U8 = 0

  new create(auth: TCPAcceptorAuth, fd: U32, h: TestHelper) =>
    _h = h
    _connection = TCPConnection.server(auth, fd, this)
    try _connection.expect(4)? end

  fun ref connection(): TCPConnection =>
    _connection

  fun ref on_received(data: Array[U8] iso) =>
    _received_count = _received_count + 1

    if _received_count == 1 then
      _h.assert_eq[String]("hi t", String.from_array(consume data))
    elseif _received_count == 2 then
      _h.assert_eq[String]("here", String.from_array(consume data))
    elseif _received_count == 3 then
      _h.assert_eq[String](", ho", String.from_array(consume data))
    elseif _received_count == 4 then
      _h.assert_eq[String]("w ar", String.from_array(consume data))
    elseif _received_count == 5 then
      _h.assert_eq[String]("e yo", String.from_array(consume data))
    elseif _received_count == 6 then
      _h.assert_eq[String]("u???", String.from_array(consume data))
      _h.complete_action("expected data received")
      _connection.close()
    end
*/
