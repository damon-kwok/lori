use "../../lori"


/*
interface tag Createable
  new tag create()

actor Act is Createable
  new create() =>None
    
primitive Lis[A: Createable tag = Act]
  fun listen(port:U32):(U32, A) =>
    let a = A
    (port, a)
*/

actor Main
  new create(env: Env) =>
    TCPServer.listen("0.0.0.0", 7669, env)

