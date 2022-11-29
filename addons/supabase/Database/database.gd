@tool
extends Node
class_name SupabaseDatabase

signal rpc_completed(query_result)
signal selected(query_result)
signal inserted(query_result)
signal updated(query_result)
signal deleted(query_result)
signal error(body)

const _rest_endpoint : String = "/rest/v1/"

var _config : Dictionary = {}
var _header : PackedStringArray = ["Prefer: return=representation"]
var _bearer : PackedStringArray = ["Authorization: Bearer %s"]

var _pooled_tasks : Array = []

func _init(conf : Dictionary, head : PackedStringArray) -> void:
	_config = conf
	_header += head
	name = "Database"

# Issue a query on your database
func query(supabase_query : SupabaseQuery) -> DatabaseTask:
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + supabase_query.build_query()
	var task : DatabaseTask = DatabaseTask.new()
	task._setup(
		supabase_query.request, 
		endpoint, 
		_header + get_parent().auth.__get_session_header() + supabase_query.header, 
		supabase_query.body
		)
	_process_task(task)
	return task

# Issue an rpc() call to a function
func Rpc(function_name : String, arguments : Dictionary = {}, supabase_query : SupabaseQuery = null) -> DatabaseTask:
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + "rpc/{function}".format({function = function_name}) + (supabase_query.build_query() if supabase_query!=null else "")
	var task : DatabaseTask = DatabaseTask.new()
	task._setup(
		-2, 
		endpoint, 
		_header + get_parent().auth.__get_session_header(), 
		JSON.stringify(arguments)
		)
	_process_task(task)
	return task    

func _process_task(task : DatabaseTask) -> void:
	var httprequest : HTTPRequest = HTTPRequest.new()
	add_child(httprequest)
	task.completed.connect(_on_task_completed)
	_pooled_tasks.append(task)
	task.push_request(httprequest)

# .............. HTTPRequest completed
func _on_task_completed(task : DatabaseTask) -> void:
	if task.data!=null and not task.data.is_empty():    
		match task._code:
			SupabaseQuery.REQUESTS.SELECT: emit_signal("selected", task.data)
			SupabaseQuery.REQUESTS.INSERT: emit_signal("inserted", task.data)
			SupabaseQuery.REQUESTS.UPDATE: emit_signal("updated", task.data)
			SupabaseQuery.REQUESTS.DELETE: emit_signal("deleted", task.data)
			_:
				emit_signal("rpc_completed", task.data)
	elif task.error != null:
		emit_signal("error", task.error)
	_pooled_tasks.erase(task)
