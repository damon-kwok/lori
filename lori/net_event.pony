primitive CMD
primitive LOG

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
type TCPListenEvent is (START | STOP | ACCEPT | CONN | DISCONN | DATA | ERROR | CMD | LOG)
type TCPConnectEvent is (CONN | DISCONN | DATA | THROTTLED | UNTHROTTLED | CMD | LOG)
