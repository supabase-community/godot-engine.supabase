@tool
extends RefCounted
class_name RealtimeChannel

signal delete(old_record, channel)
signal insert(new_record, channel)
signal update(old_record, new_record, channel)
signal all(old_record, new_record, channel)

var _client: RealtimeClient
var topic : String
var subscribed : bool

func _init(topic : String, client) -> void:
	self.topic = topic
	_client = client

func _publish(message : Dictionary) -> void:
	if not subscribed: return
	match message.event:
		_client.SupabaseEvents.DELETE:
			emit_signal("delete", message.payload.old_record, self)
		_client.SupabaseEvents.UPDATE:
			emit_signal("update", message.payload.old_record, message.payload.record, self)
		_client.SupabaseEvents.INSERT:
			emit_signal("insert", message.payload.record, self)
	emit_signal("all", message.payload.get("old_record", {}), message.payload.get("record", {}), self)
  
func on(event: String, callable: Callable) -> RealtimeChannel:
	connect(event, callable)
	return self      

func subscribe() -> RealtimeChannel:
	if subscribed: 
		_client._error("Already subscribed to topic: %s" % topic)
		return self
	_client.send_message({
		topic = topic,
		event = _client.PhxEvents.JOIN,
		payload = {},
		ref = null
	})
	subscribed = true
	return self

func unsubscribe() -> RealtimeChannel:
	if not subscribed: 
		_client._error("Already unsubscribed from topic: %s" % topic)
		return self
	_client.send_message({
		topic = topic,
		event = _client.PhxEvents.LEAVE,
		payload = {},
		ref = null
	})
	subscribed = false
	return self

func close() -> void:
	_client._remove_channel(self)
