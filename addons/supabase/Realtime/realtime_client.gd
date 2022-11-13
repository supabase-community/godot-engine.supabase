class_name RealtimeClient
extends Node

signal connected()
signal disconnected()
signal error(message)

class PhxEvents:
	const JOIN := "phx_join"
	const REPLY := "phx_reply"
	const LEAVE := "phx_leave"
	const ERROR := "phx_error"
	const CLOSE := "phx_close"

class SupabaseEvents:
	const DELETE:= "DELETE"
	const UPDATE:= "UPDATE"
	const INSERT:= "INSERT"
	const ALL := "*"

var channels : Array = []

var _db_url : String
var _apikey : String

var _ws_client = WebSocketPeer.new()
var _heartbeat_timer : Timer = Timer.new()

func _init(url : String, apikey : String, timeout : float) -> void:
	set_process_internal(false)
	_db_url = url.replace("http","ws")+"/realtime/v1/websocket"
	_apikey = apikey
	_heartbeat_timer.set_wait_time(timeout)
	_heartbeat_timer.name = "PhxHeartbeat"
	name = "RealtimeClient"
	
func _ready() -> void:
	add_child(_heartbeat_timer)

func _connect_signals() -> void:
	_ws_client.connection_closed.connect(_closed)
	_ws_client.connection_error.connect(_error)
	_ws_client.connection_established.connect(_connected)
	_ws_client.data_received.connect(_on_data)
	_heartbeat_timer.timeout.connect(_on_timeout)

func _disconnect_signals() -> void:
	_ws_client.disconnection_closed.connect(_closed)
	_ws_client.disconnection_error.connect(_error)
	_ws_client.disconnection_established.connect(_connected)
	_ws_client.disdata_received.connect(_on_data)
	_heartbeat_timer.timeout.connect(_on_timeout)

func connect_client() -> int:
	set_process_internal(true)
	_connect_signals()
	var err = _ws_client.connect_to_url("{url}?apikey={apikey}".format({url = _db_url, apikey = _apikey}))
	if err != OK:
		_disconnect_signals()
		_heartbeat_timer.stop()
	else:
		_heartbeat_timer.start()
	return err

func disconnect_client() -> void:
	_ws_client.disconnect_from_host(1000, "Disconnection requested from client.")
	set_process_internal(false)

func remove_client() -> void:
	queue_free()

func channel(schema : String, table : String = "", col_value : String = "") -> RealtimeChannel:
	var topic : String = _build_topic(schema, table, col_value)
	var channel : RealtimeChannel = get_channel(topic)
	if channel == null:
		channel = RealtimeChannel.new(topic, self)
		_add_channel(channel)
	return channel

func _build_topic(schema : String, table : String = "", col_value : String = "") -> String:
	var topic : String = "realtime:"+schema
	if table != "":
		topic+=":"+table
		if col_value!= "":
			topic+=":"+col_value
	return topic
		
func _add_channel(channel : RealtimeChannel) -> void:
	channels.append(channel)

func _remove_channel(channel : RealtimeChannel) -> void:
	channels.erase(channel)

func _connected(proto = ""):
	emit_signal("connected")

func _closed(was_clean : bool = false):
	channels = []
	_disconnect_signals()
	emit_signal("disconnected")
	

func _error(msg : String = "") -> void: 
	emit_signal("error", msg)

func _on_data() -> void:
	var data : Dictionary = get_message(_ws_client.get_peer(1).get_packet())
	match data.event:
		PhxEvents.REPLY:
			if _check_response(data) == 0:
				pass
				get_parent().get_parent()._print_debug("Received reply = %s" % JSON.stringify(data))
		PhxEvents.JOIN:
			if _check_response(data) == 0:
				pass
				get_parent().get_parent()._print_debug("Joined topic '%s'" % data.topic)
		PhxEvents.LEAVE:
			if _check_response(data) == 0:
				pass
				get_parent().get_parent()._print_debug("Left topic '%s'" % data.topic)
		PhxEvents.CLOSE:
			pass
			get_parent().get_parent()._print_debug("Channel closed.")
		PhxEvents.ERROR:
			emit_signal("error", data.payload)
		SupabaseEvents.DELETE, SupabaseEvents.INSERT, SupabaseEvents.UPDATE:
			get_parent().get_parent()._print_debug("Received %s event..." % data.event)
			var channel : RealtimeChannel = get_channel(data.topic)
			if channel != null:
				channel._publish(data)

func get_channel(topic : String) -> RealtimeChannel:
	for channel in channels:
		if channel.topic == topic:
			return channel
	return null

func _check_response(message : Dictionary):
	if message.payload.status == "ok":
		return 0

func get_message(pb : PackedByteArray) -> Dictionary:
	return JSON.parse_string(pb.get_string_from_utf8())
		
func send_message(json_message : Dictionary) -> void:
	if not _ws_client.get_peer(1).is_connected_to_host():
		await connected
		_ws_client.get_peer(1).put_packet(JSON.stringify(json_message).to_utf8_buffer())
	else:
		_ws_client.get_peer(1).put_packet(JSON.stringify(json_message).to_utf8_buffer())
		
		
func _send_heartbeat() -> void:
	send_message({
		topic = "phoenix",
		event = "heartbeat",
		payload = {},
		ref = null
	})
	
func _on_timeout() -> void:
	if _ws_client.get_peer(1).is_connected_to_host():
		_send_heartbeat()

func _notification(what) -> void:
	match what:
		NOTIFICATION_INTERNAL_PROCESS:
			_internal_process(get_process_delta_time())

func _internal_process(_delta : float) -> void:
	_ws_client.poll()
	
