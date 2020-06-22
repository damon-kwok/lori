use "../../lori"

actor Main
  new create(env: Env) =>
    try
      let auth = TCPListenAuth(env.root as AmbientAuth)
      TCPListener(auth, None, {():None => None} val)
      .> on(DATA, {(c: TCPConnection ref, d: Array[U8] iso) => c.send(consume d) })
      .> listen("0.0.0.0", 7669)
    end
