class_name RealtimeChannel
extends Reference

signal delete(old_record, channel)
signal insert(new_record, channel)
signal update(old_record, new_record, channel)
signal all(old_record, new_record, channel)

var _client
var topic : String
var subscribed : bool

func _init(topic : String, client) -> void:
    self.topic = topic
    _client = client

func publish(message : Dictionary):
    if not subscribed: return
    match message.event:
        _client.SupabaseEvents.DELETE:
            emit_signal("delete", message.payload.old_record, self)
        _client.SupabaseEvents.UPDATE:
            emit_signal("update", message.payload.old_record, message.payload.new_record, self)
        _client.SupabaseEvents.INSERT:
            emit_signal("insert", message.payload.record, self)
    emit_signal("all", message.payload.get("old_record", {}), message.payload.get("new_record", {}), self)
        
            
func subscribe():
    _client.send_message({
      "topic": topic,
      "event": _client.PhxEvents.JOIN,
      "payload": {},
      "ref": null
    })
    subscribed = true

            
func unsubscribe():
    _client.send_message({
      "topic": topic,
      "event": _client.PhxEvents.LEAVE,
      "payload": {},
      "ref": null
    })
    subscribed = false
    
func remove() -> void:
    _client.erase(self)
