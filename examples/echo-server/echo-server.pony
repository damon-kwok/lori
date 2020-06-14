use "../../lori"

actor Main
  new create(env: Env) =>
    try
      let auth = TCPListenAuth(env.root as AmbientAuth)
      let server = TCPListener(auth, env.out)
      server.listen("", "7669")
    end
