"""
tcp.pony ---  I love pony 🐎.
Date: 2020-06-17

Copyright (C) 2016-2020, The Pony Developers
Copyright (C) 2003-2020, Damon Kwok <damon-kwok@outlook.com>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""
primitive TCPServer[A: TCPListenerActor =TCPSimpleListenActor]
  """
  TCPServer
  """
  fun listen(host: String, port: U32, env: Env) =>
    try
      let auth = TCPListenAuth(env.root as AmbientAuth)
      A(recover TCPListener(auth, host, port.string(), env.out) end)
    end

primitive TCPClient[A: TCPConnectionActor =TCPSimpleClientActor]
  """
  TCPClient
  """
  fun connect(host: String, port: U32, env: Env) =>
    try
      let auth = TCPConnectAuth(env.root as AmbientAuth)
      A(recover TCPConnection.client(auth, host, port.string(), "", env.out) end)
    end

// TCPSimpleListenActor
actor TCPSimpleListenActor is TCPListenerActor
  var _listen:TCPListener = TCPListener.none()

  new create(listen: TCPListener iso) => _listen = consume listen

  be bind(listen: TCPListener iso) => _listen = consume listen

  fun ref listener(): TCPListener => _listen

  fun ref on_accept(fd: U32): TCPConnectionActor =>
    try
      let auth = TCPAcceptAuth(listener().auth as TCPListenerAuth)
      TCPSimpleAcceptActor(recover TCPConnection.accept(auth, fd) end)
    else
      TCPSimpleAcceptActor(recover TCPConnection.none() end)
    end

// TCPSimpleClientActor
actor TCPSimpleClientActor is TCPClientActor
  var _conn: TCPConnection = TCPConnection.none()

  new create(conn: TCPConnection iso) => _conn = consume conn

  fun ref bind(conn: TCPConnection iso) => _conn = consume conn

  fun ref connection(): TCPConnection => _conn

// TCPSimpleAcceptActor
actor TCPSimpleAcceptActor is TCPAcceptorActor
  var _conn: TCPConnection = TCPConnection.none()

  new create(conn: TCPConnection iso) => _conn = consume conn

  fun ref bind(conn: TCPConnection iso) => _conn = consume conn

  fun ref connection(): TCPConnection => _conn


