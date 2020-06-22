use "../../lori"

actor Main
  new create(env: Env) =>
    try
      let auth = TCPConnectAuth(env.root as AmbientAuth)
      TCPConnection[None](auth, None, env.out)
      .> on(CONN, {(self: TCPConnection[None] ref) =>self.send("Hello!")})
      .> on(DATA, {(self: TCPConnection[None] ref, d: Array[U8] iso) => env.out.print(consume d) })
      .> start("127.0.0.1", 7669, "localhost")
    end
