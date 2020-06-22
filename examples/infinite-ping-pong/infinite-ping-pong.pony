use "../../lori"

// test app to drive the library
actor Main
  new create(env: Env) =>
    try
      // auth
      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      let conn_auth = TCPConnectAuth(env.root as AmbientAuth)

      // server
      // let svr = TCPListener(listen_auth, env.out)
      TCPListener[None, None](listen_auth, None, env.out, {():None=> None})
      .> on(DATA, {(conn: TCPConnection[None] ref, data: Array[U8] iso) =>
           env.out.print(consume data)
           conn.send("Pong") })
      .> listen("0.0.0.0", 7670)

      // client
      let cli = TCPConnection[None](conn_auth, None, env.out)
      cli .> on(CONN, {(self: TCPConnection[None] ref) =>cli.send("Ping")})
          .> on(DATA, {(self: TCPConnection[None] ref,  data: Array[U8] iso) =>
               env.out.print(consume data)
               cli.send("Ping") })
          .> start("127.0.0.1", 7670, "")
    end
