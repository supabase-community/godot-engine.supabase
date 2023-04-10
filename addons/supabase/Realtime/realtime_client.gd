@tool
class_name RealtimeClient
extends Node

signal connected()
signal disconnected()
signal error(message: Dictionary)
signal message_received(message: Dictionary)

@export var handshake_headers : PackedStringArray
@export var supported_protocols : PackedStringArray
@export var tls_trusted_certificate : X509Certificate

var tls_options: TLSOptions = TLSOptions.client(tls_trusted_certificate)

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

var _db_url : String
var _apikey : String

var channels := []
var last_state := WebSocketPeer.STATE_CLOSED
var _ws_client := WebSocketPeer.new()
var _heartbeat_timer := Timer.new()

func _init(url : String, apikey : String, timeout : float) -> void:
	_db_url = url.replace("http","ws")+"/realtime/v1/websocket"
	_apikey = apikey
	_heartbeat_timer.set_wait_time(timeout)
	_heartbeat_timer.name = "PhxHeartbeat"
	name = "RealtimeClient"
	
func _ready() -> void:
	message_received.connect(_on_data)
	add_child(_heartbeat_timer)
	_heartbeat_timer.timeout.connect(
		func() -> void:
			if last_state == _ws_client.STATE_OPEN:
				_send_heartbeat()
	)

func connect_client() -> int:
	_ws_client.supported_protocols = supported_protocols
	_ws_client.handshake_headers = handshake_headers
	
	var err := _ws_client.connect_to_url(
		"{url}?apikey={apikey}".format({url = _db_url, apikey = _apikey}), 
		tls_options
		)
	if err != OK:
		return err
	last_state = _ws_client.get_ready_state()
	return OK

func disconnect_client(code : int = 1000, reason : String = "") -> void:
	_ws_client.close(code, reason)
	last_state = _ws_client.get_ready_state()

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

func _on_data(data : Dictionary) -> void:
	match data.event:
		PhxEvents.REPLY:
			if _check_response(data) == OK:
				pass
				get_parent().get_parent()._print_debug("Received reply = %s" % JSON.stringify(data))
		PhxEvents.JOIN:
			if _check_response(data) == OK:
				pass
				get_parent().get_parent()._print_debug("Joined topic '%s'" % data.topic)
		PhxEvents.LEAVE:
			if _check_response(data) == OK:
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

func _check_response(message : Dictionary) -> int:
	if message.payload.status == "ok":
		return OK
	return FAILED

func send_message(json_message : Dictionary) -> int:
	return _ws_client.send(JSON.stringify(json_message).to_utf8_buffer())

func _send_heartbeat() -> void:
	send_message({
		topic = "phoenix",
		event = "heartbeat",
		payload = {},
		ref = null
	})
	
func _notification(what : int) -> void:
	match what:
		NOTIFICATION_INTERNAL_PROCESS:
			_process(get_process_delta_time())

func _process(_delta : float) -> void:
	if _ws_client.get_ready_state() != _ws_client.STATE_CLOSED:
		_ws_client.poll()
	
	var state := _ws_client.get_ready_state()
	
	if last_state != state:
		last_state = state
		if state == _ws_client.STATE_OPEN:
			_heartbeat_timer.start()
			connected.emit()
		elif state == _ws_client.STATE_CLOSED:
			channels = []
			_heartbeat_timer.stop()
			disconnected.emit()
	while _ws_client.get_ready_state() == _ws_client.STATE_OPEN and _ws_client.get_available_packet_count():
		message_received.emit(JSON.parse_string(get_message()))
	
func get_message() -> Variant:
	if _ws_client.get_available_packet_count() < 1:
		return null
	var pkt := _ws_client.get_packet()
	if _ws_client.was_string_packet():
		return pkt.get_string_from_utf8()
	return bytes_to_var(pkt)
