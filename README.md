# Lori

Pony TCP classes reimagined.

## Status

![vs-ponyc-latest](https://github.com/seantallen/lori/workflows/vs-ponyc-latest/badge.svg)

This is an experimental project and shouldn't be used in a production environment.

## Installation

* Install [corral](https://github.com/ponylang/corral)
* `corral add github.com/seantallen/lori.git`
* `corral fetch` to fetch your dependencies
* `use "lori"` to include this package
* `corral run -- ponyc` to compile your application

## Example

### Server
```pony
actor Main
  new create(env: Env) =>
    try
      let auth = TCPListenAuth(env.root as AmbientAuth)
      TCPListener(auth, env.out)
      .> on(DATA, {(c: TCPConnection, d: Array[U8] iso) => c.send(consume d) })
      .> listen("0.0.0.0", 7669)
    end
```

### Client
```pony
actor Main
  new create(env: Env) =>
    try
      let auth = TCPConnectAuth(env.root as AmbientAuth)
      let cli = TCPConnection(auth, env.out)
      cli .> on(CONN, {() =>cli.send("Hello!")})
          .> on(DATA, {(d: Array[U8] iso) => env.out.print(consume d) })
          .> start("127.0.0.1", 7669, "localhost")
    end
```

### Ping-Pong
```pony
actor Main
  new create(env: Env) =>
    try
      // auth
      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      let conn_auth = TCPConnectAuth(env.root as AmbientAuth)

      // server
      // let svr = TCPListener(listen_auth, env.out)
      TCPListener(listen_auth, env.out)
      .> on(DATA, {(conn: TCPConnection, data: Array[U8] iso) =>
           env.out.print(consume data)
           conn.send("Pong") })
      .> listen("0.0.0.0", 7670)

      // client
      let cli = TCPConnection(conn_auth,  env.out)
      cli .> on(CONN, {() =>cli.send("Ping")})
          .> on(DATA, {(data: Array[U8] iso) =>
               env.out.print(consume data)
               cli.send("Ping") })
          .> start("127.0.0.1", 7670, "")
    end
```
