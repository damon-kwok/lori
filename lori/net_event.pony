// primitive Open
// primitive Closed
primitive START
primitive STOP

primitive ACCEPT
primitive ERROR

primitive DATA
primitive CONN
primitive DISCONN
primitive THROTTLED
primitive UNTHROTTLED

type TCPConnectState is (START | STOP)
type TCPListenEvent is (START | STOP | ACCEPT | CONN | DISCONN | DATA | ERROR)
type TCPConnectEvent is (CONN | DISCONN | DATA | THROTTLED | UNTHROTTLED)
