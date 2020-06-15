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
      let svr = TCPListener(auth, env.out)
      svr.on(Received, {(conn: TCPConnection, data: Array[U8] iso) =>
        conn.send(consume data) })
      svr.listen("0.0.0.0", "7669")
    end
```

### Client
```pony
actor Main
  new create(env: Env) =>
    try
      let auth = TCPConnectAuth(env.root as AmbientAuth)
      let cli = TCPConnection(auth, "127.0.0.1", "7669", "localhost", env.out)
      cli.on(Connected, {() =>cli.send("Ping")})
    end
```

### Ping-Pong
```pony
actor Main
  new create(env: Env) =>
    try
      // auth
      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      let connect_auth = TCPConnectAuth(env.root as AmbientAuth)

      // server
      let svr = TCPListener(listen_auth, env.out)
      svr.on(Received, {(conn: TCPConnection, data: Array[U8] iso) =>
        env.out.print(consume data)
        conn.send("Pong") })
      svr.listen("0.0.0.0", "7669")

      // client
      let cli = TCPConnection(connect_auth, "127.0.0.1", "7669", "", env.out)
      cli.on(Connected, {() =>cli.send("Ping")})
      cli.on(Received, {(data: Array[U8] iso) =>
        env.out.print(consume data)
        cli.send("Ping") })
    end
```
