use "../../lori"

// test app to drive the library
actor Main
  new create(env: Env) =>
    try
      // auth
      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      let conn_auth = TCPConnectAuth(env.root as AmbientAuth)

      // server
      let svr = TCPListener(listen_auth, env.out)
      svr.on(DATA, {(conn: TCPConnection, data: Array[U8] iso) =>
        env.out.print(consume data)
        conn.send("Pong") })
      svr.listen("0.0.0.0", "7669")

      // client
      let cli = TCPConnection(conn_auth, "127.0.0.1", "7669", "", env.out)
      cli.on(CONN, {() =>cli.send("Ping")})
      cli.on(DATA, {(data: Array[U8] iso) =>
        env.out.print(consume data)
        cli.send("Ping") })
    end
