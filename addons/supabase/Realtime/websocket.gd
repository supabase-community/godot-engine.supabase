extends Node
class_name SupabaseWebSocket

var url
var channels
var connected
var params
var hb_interval
var ws_connection
var kept_alive

func _init():
	self.url = url
	self.channels = []
	self.connected = false
	self.params = params
	self.hb_interval = hb_interval
	self.ws_connection = null
	self.kept_alive = false
