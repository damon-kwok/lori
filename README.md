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
      let server = TCPListener(auth, env.out)
      server.listen("0.0.0.0", "7669")
    end
```

### Client
```pony
actor Main
  new create(env: Env) =>
    try
      let auth = TCPConnectAuth(env.root as AmbientAuth)
      TCPConnection.client(auth, "0.0.0.0", "7669", "localhost", env.out)
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
      let server = TCPListener(listen_auth, env.out)
      server.on(Received, {(conn: TCPConnection, data: Array[U8] iso) =>
        env.out.print(consume data)
        conn.send("Pong") })
      server.listen("0.0.0.0", "7669")

      // client
      let client = TCPConnection.client(connect_auth, "127.0.0.1", "7669", "", env.out)
      client.on(Connected, {() =>client.send("Ping")})
      client.on(Received, {(data: Array[U8] iso) =>
        env.out.print(consume data)
        client.send("Ping") })
    end
```
