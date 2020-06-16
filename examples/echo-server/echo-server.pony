use "../../lori"

actor Main
  new create(env: Env) =>
    try
      let auth = TCPListenAuth(env.root as AmbientAuth)
      TCPListener(auth, env.out)
      .> on(DATA, {(c: TCPConnection, d: Array[U8] iso) => c.send(consume d) })
      .> listen("0.0.0.0", 7669)
    end
