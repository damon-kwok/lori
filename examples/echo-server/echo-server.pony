use "../../lori"

actor Main
  new create(env: Env) =>
    try
      let auth = TCPListenAuth(env.root as AmbientAuth)
      TCPListener[None, None](auth, None, env.out, {():None => None} val)
      .> on(DATA, {(c: TCPConnection[None] ref, d: Array[U8] iso) => c.send(consume d) })
      .> listen("0.0.0.0", 7669)
    end
