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

### EchoServer
```pony
actor Main
  new create(env: Env) =>
    try
      let auth = TCPListenAuth(env.root as AmbientAuth)
      let server = TCPListener(auth, env.out)
      server.listen("0.0.0.0", "7669")
    end
```
