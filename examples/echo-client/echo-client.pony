use "../../lori"

actor Main
  new create(env: Env) =>
    try
      let auth = TCPConnectAuth(env.root as AmbientAuth)
      TCPConnection(auth, None)
      .> on(CONN, {(self: TCPConnection ref) =>self.send("Hello!")})
      .> on(DATA, {(self: TCPConnection ref, d: Array[U8] iso) => self.log(consume d) })
      .> start("127.0.0.1", 7669, "localhost")
    end
