use "collections"

actor TCPListener[A: Any #send = None, B: Any #send = None]
  var storage: A!
  var kv: Map[String, A!] =Map[String, A!] 
  // let _auth: TCPListenerAuth
  var _host: String ="0.0.0.0"
  var _port: U32 =7669
  var _fd: U32 = -1
  var _state: TCPConnectState = STOP
  var _event: AsioEventID = AsioEvent.none()
  
  // var _on_accept: {(U32): TCPConnection} val
  var _on_storage: {():B} val
  var _on_start: {(TCPListener[A,B] ref)} val
  var _on_stop: {(TCPListener[A,B] ref)} val
  var _on_error: {(TCPListener[A,B] ref)} val
  var _on_conn: {(TCPConnection[B] ref)} val
  var _on_disconn: {(TCPConnection[B] ref)} val
  var _on_data: {(TCPConnection[B] ref, Array[U8] iso)} val
  // var _on_cmd: {(TCPListener[A,B] ref, U32, Array[E] iso)} val
  var _on_log: {(TCPListener[A,B] ref, ByteSeq)} val = {(self: TCPListener[A,B] ref, data: ByteSeq)=> None }

  new create(auth: TCPListenerAuth,
    storage': A,
    // out: OutStream,
    on_storage': {():B} val,
    on_start': (None | {()} val) =None,
    on_stop': (None | {()} val) =None,
    on_error': (None | {()} val) =None,
    // on_accept': (None | {(U32): TCPConnection} val) =None,
    on_conn': (None | {(TCPConnection[B] ref)} val) =None,
    on_disconn': (None | {(TCPConnection[B] ref)} val) =None,
    on_data': (None | {(TCPConnection[B] ref, Array[U8] iso)} val) =None)
    // on_cmd': (None | {(TCPListener[A,B] ref, U32, Array[Any] iso)} val) = None)
  =>
    // _auth = auth
    storage = consume storage'
    _on_storage = on_storage'
    _on_start = match on_start'
    | let fn: {(TCPListener[A,B] ref)} val => fn
    else {(self: TCPListener[A,B] ref)=> self.log("Echo server started.") }
    end
    _on_stop = match on_stop'
    | let fn: {(TCPListener[A,B] ref)} val => fn
    else {(self: TCPListener[A,B] ref)=> self.log("Echo server shut down.") }
    end
    _on_error = match on_error'
    | let fn: {(TCPListener[A,B] ref)} val => fn
    else {(self: TCPListener[A,B] ref)=> self.log("Couldn't start Echo server. Perhaps try another network interface?") }
    end
    // _on_cmd = {(conn: TCPListener[A, B] ref, cmd: U32, args: Array[E] iso) => None }
    _on_conn = match on_conn'
    | let fn: {(TCPConnection[B] ref)} val => fn
    else {(conn: TCPConnection[B] ref)=> conn.log("We have a new connection!") }
    end
    _on_disconn = match on_disconn'
    | let fn: {(TCPConnection[B] ref)} val => fn
    else {(conn: TCPConnection[B] ref)=> conn.log("Connection Closed.") }
    end
    _on_data = match on_data'
    | let fn: {(TCPConnection[B] ref, Array[U8] iso)} val => fn
    else
      {(conn: TCPConnection[B] ref, data: Array[U8] iso) => conn.log(consume data) }
    end
    

  new none(storage' :A, on_storage': {():B} val) =>
    storage = consume storage'
    _on_storage = on_storage'
    _on_start = {(self: TCPListener[A,B] ref)=> None }
    _on_stop = {(self: TCPListener[A,B] ref)=> None }
    _on_error = {(self: TCPListener[A,B] ref)=> None }
    // _on_cmd = {(conn: TCPListener[A, B] ref, cmd: U32, args: Array[E] iso) => None }
    _on_conn = {(conn: TCPConnection[B] ref)=> None }
    _on_disconn = {(conn: TCPConnection[B] ref)=> None }
    _on_data = {(conn: TCPConnection[B] ref, data: Array[U8] iso)=> None }
    
  fun ref _on_accept(fd :U32):TCPConnection[B] =>
    /*this, TCPAcceptAuth(_auth),*/
    let vv': B! = _on_storage()
    TCPConnection[B]._accept(fd, vv', _on_conn, _on_disconn, _on_data)

  be on(ev: TCPListenEvent, f:
    ({(TCPListener[A,B] ref)} val | {(TCPConnection[B] ref)} val | {(TCPConnection[B] ref, Array[U8] iso)} val))
  =>
    match ev
    | START => try _on_start = (f as {(TCPListener[A,B] ref)} val) end
    | STOP => try _on_stop = (f as {(TCPListener[A,B] ref)} val) end
    | ERROR => try _on_error = (f as {(TCPListener[A,B] ref)} val) end
    // | CMD => try _on_cmd = (f as {(TCPListener[A,B] ref, U32, Array[E] iso)} val) end
    | LOG => try _on_log = (f as {(TCPListener[A,B] ref, ByteSeq)} val) end
    // | ACCEPT => try _on_accept = (f as {(U32): TCPConnection} val) end
    | CONN => try _on_conn = (f as {(TCPConnection[B] ref)} val) end
    | DISCONN => try _on_disconn = (f as {(TCPConnection[B] ref)} val) end
    | DATA => try _on_data = (f as {(TCPConnection[B] ref, Array[U8] iso)} val) end
    end
  
  be listen(host: String val, port: U32 val) =>
    if _state is START then return end
    _host = host
    _port = port
    let event = PonyTCP.listen(this, _host, _port.string())
    if not event.is_null() then
      _fd = PonyAsio.event_fd(event)
      _event = event
      _state = START
      _on_start(this)
    else
      _on_error(this)
      None
    end

  be dispose() =>
    """
    Close connection
    """
    close()
    
  be command[T: Any #send](cmd: U32, args: Array[T] iso) =>
    None // _on_cmd(this, cmd, args)

  fun ref log(data: ByteSeq) =>
    _on_log(this, data)
    
  fun ref close() =>
    if _state is START then
      _state = STOP
      if not _event.is_null() then
        PonyAsio.unsubscribe(_event)
        PonyTCP.close(_fd)
        _fd = -1
        _on_stop(this)
      end
      end
      
  be _event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    if event isnt _event then
      return
    end

    if AsioEvent.readable(flags) then
      _accept(arg)
    end
    
    if AsioEvent.disposable(flags) then
      PonyAsio.destroy(_event)
      _event = AsioEvent.none()
      _state = STOP
    end

  fun ref _accept(arg: U32) =>
    match _state
    | STOP =>
      // It's possible that after closing, we got an event for a connection
      // attempt. If that is the case or the listener is otherwise not open,
      // return and do not start a new connection
      return
    | START =>
      while true do
        var fd = PonyTCP.accept(_event)
        match fd
        | -1 => None // Wouldn't block but we got an error. Keep trying.          
        | 0 => return // Would block. Bail out.
        else
          _on_accept(fd) 
          return
        end
      end
    end
