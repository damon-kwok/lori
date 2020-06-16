use "../../lori"

actor Main
  new create(env: Env) =>
    try
      let auth = TCPConnectAuth(env.root as AmbientAuth)
      let cli = TCPConnection(auth, env.out)
      cli .> on(CONN, {() =>cli.send("Hello!")})
          .> on(DATA, {(d: Array[U8] iso) => env.out.print(consume d) })
          .> start("127.0.0.1", 7669, "localhost")
    end
