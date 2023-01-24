@tool
class_name SupabaseRealtime
extends Node

var _config : Dictionary

func _init(config : Dictionary) -> void:
	_config = config
	name = "Realtime"
	
func _ready():
	pass # Replace with function body.

func client(url : String = _config.supabaseUrl, apikey : String = _config.supabaseKey, timeout : float = 30.) -> RealtimeClient:
	var realtime_client : RealtimeClient =  RealtimeClient.new(url, apikey, timeout)
	add_child(realtime_client)
	return realtime_client
