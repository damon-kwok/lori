primitive NetAuth
  new create(from: AmbientAuth) =>
    None

primitive TCPAuth
  new create(from: (AmbientAuth | NetAuth)) =>
    None

primitive TCPListenAuth
  new create(from: (AmbientAuth | NetAuth | TCPAuth)) =>
    None

primitive TCPConnectAuth
  new create(from: (AmbientAuth | NetAuth | TCPAuth)) =>
    None

primitive TCPAcceptAuth
  new create(from: (AmbientAuth | NetAuth | TCPAuth | TCPListenAuth)) =>
    None

// Listener
type TCPListenerAuth is (AmbientAuth | NetAuth | TCPAuth | TCPListenAuth)

// Outgoing
type TCPConnectorAuth is (AmbientAuth | NetAuth | TCPAuth | TCPConnectAuth)

// Incoming
type TCPAcceptorAuth is (AmbientAuth | NetAuth | TCPAuth | TCPAcceptAuth)
