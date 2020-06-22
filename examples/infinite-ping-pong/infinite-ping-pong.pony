use "../../lori"

// test app to drive the library
actor Main
  new create(env: Env) =>
    try
      // auth
      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      let conn_auth = TCPConnectAuth(env.root as AmbientAuth)

      // server
      TCPListener(listen_auth, None, {():None=> None})
      .> on(DATA, {(conn: TCPConnection ref, data: Array[U8] iso) =>
           conn.log(consume data)
           conn.send("Pong") })
      .> listen("0.0.0.0", 7670)

      // client
      let cli = TCPConnection(conn_auth, None)
      .> on(CONN, {(self: TCPConnection ref) => self.send("Ping")})
      .> on(DATA, {(self: TCPConnection ref,  data: Array[U8] iso) =>
           self.log(consume data)
           self.send("Ping") })
      .> start("127.0.0.1", 7670, "")
    end
