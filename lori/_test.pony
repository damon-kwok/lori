use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    // test(_BitSet)
    // test(_TCPConnectionState)
    test(_PingPong)
    test(_TestBasicExpect)

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
    let a = TCPConnection[None].none(None)

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
      let svr = TCPListener[None, I32](svr_auth, None, {(): I32 => 0 } val)

      let ping_auth = TCPConnectAuth(h.env.root as AmbientAuth)
      var ping= TCPConnection[I32](ping_auth, 0)

      // server
      svr
      .> on(START,{(self: TCPListener[None,I32] ref)=> ping.start("127.0.0.1", 7671, "") } val)
      .> on(STOP,{(self: TCPListener[None,I32] ref)=> ping.dispose() } val)
      .> on(ERROR,{(self: TCPListener[None,I32] ref)=> h.fail("Unable to open _TestPongerListener") } val)
      .> on(CONN,{(c: TCPConnection[I32] ref)=> h.log("has new conn!!!") } val)
      .> on(DISCONN,{(c: TCPConnection[I32] ref)=> c.dispose() } val)
      .> on(DATA, {(c: TCPConnection[I32] ref, d: Array[U8] iso) =>
        h.log("Pong:"+ c.storage.string())
        if c.storage < 10 then
          c.send("Pong")
          c.storage= c.storage+1
        elseif c.storage == 10 then
          c.send("Pong")
        else
          h.fail("Too many pings received")
            
        end } val)
      .> listen("0.0.0.0", 7671)

      // client
      ping
      .> on(CONN,{(self: TCPConnection[I32] ref)=>
        h.log("ping-start")
        self.send("Ping")
        self.storage= 1 })
      .> on(DATA, {(self: TCPConnection[I32] ref, d: Array[U8] iso)=>
          h.log("Ping:"+ self.storage.string())
          if self.storage < 10 then
            self.send("Ping")
            self.storage= self.storage+1
          else
            h.complete(true)
          end } val)

      // done
      h.dispose_when_done(svr)
    end //try

    h.long_test(5_000_000_000)

class iso _TestBasicExpect is UnitTest
  fun name(): String => "TestBasicExpect"

  fun apply(h: TestHelper) =>
    h.expect_action("server listening")
    h.expect_action("client connected")
    h.expect_action("expected data received")

    try
      let la = TCPListenAuth(h.env.root as AmbientAuth)
      let ca = TCPConnectAuth(h.env.root as AmbientAuth)
      let svr = TCPListener[None, U8](la, None, {():U8 => 0})
      let cli = TCPConnection[None](ca, None)

      // server
      svr
      .> on(START, {(self: TCPListener[None, U8] ref)=>
        h.complete_action("server listening")
        cli.start("127.0.0.1", 7672, "") }val)
      .> on(STOP, {(self: TCPListener[None, U8] ref)=> cli.dispose() }val)
      .> on(ERROR, {(self: TCPListener[None, U8] ref) => h.fail("Unable to open _TestBasicExpectListener") }val)
      .> on(CONN, {(conn: TCPConnection[U8] ref)=> try h.log("------------expect:4");conn.expect(4)? end}val)
      .> on(DATA, {(conn: TCPConnection[U8] ref, data: Array[U8] iso)=>
        conn.storage = conn.storage + 1
        if conn.storage == 1 then
          h.assert_eq[String]("hi t", String.from_array(consume data))
        elseif conn.storage == 2 then
          h.assert_eq[String]("here", String.from_array(consume data))
        elseif conn.storage == 3 then
          h.assert_eq[String](", ho", String.from_array(consume data))
        elseif conn.storage == 4 then
          h.assert_eq[String]("w ar", String.from_array(consume data))
        elseif conn.storage == 5 then
          h.assert_eq[String]("e yo", String.from_array(consume data))
        elseif conn.storage == 6 then
          h.assert_eq[String]("u???", String.from_array(consume data))
          h.complete_action("expected data received")
          conn.close()
        end }val)
      .> listen("0.0.0.0", 7672)

      // client
      cli
      .> on(CONN, {(self: TCPConnection ref)=>
        h.complete_action("client connected")
        self.send("hi there, how are you???")})
      .> on(DATA, {(self: TCPConnection ref, d: Array[U8] iso)=>
        h.fail("Client shouldn't get data")})

      // done
      h.dispose_when_done(svr)
    else
      h.fail("unable to start _TestBasicExpect")
    end // try

    h.long_test(2_000_000_000)
