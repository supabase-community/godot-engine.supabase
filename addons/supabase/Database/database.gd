class_name SupabaseDatabase
extends Node

signal rpc_completed(query_result)
signal selected(query_result)
signal inserted(query_result)
signal updated(query_result)
signal deleted(query_result)
signal error(body)

const _rest_endpoint : String = "/rest/v1/"

var _config : Dictionary = {}
var _header : PoolStringArray = ["Prefer: return=representation"]
var _bearer : PoolStringArray = ["Authorization: Bearer %s"]

var _pooled_tasks : Array = []

func _init(conf : Dictionary, head : PoolStringArray) -> void:
	_config = conf
	_header += head
	name = "Database"


# Issue a query on your database
func query(supabase_query : SupabaseQuery) -> DatabaseTask:
	_bearer = get_parent().auth._bearer
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + supabase_query.build_query()
	var task : DatabaseTask = DatabaseTask.new()
	task._setup(
		supabase_query,
		supabase_query.request, 
		endpoint, 
		_header + _bearer + supabase_query.header, 
		supabase_query.body)
	_process_task(task)
	return task

# Issue an rpc() call to a function
func rpc(function_name : String, arguments : Dictionary = {}, supabase_query : SupabaseQuery = null) -> DatabaseTask:
	_bearer = get_parent().auth._bearer
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + "rpc/{function}".format({function = function_name}) + (supabase_query.build_query() if supabase_query != null else "")
	var task : DatabaseTask = DatabaseTask.new()
	task._setup(
		supabase_query,
		-2, 
		endpoint, 
		_header + _bearer, 
		to_json(arguments))
	_process_task(task)
	return task    

func _process_task(task : DatabaseTask) -> void:
	var httprequest : HTTPRequest = HTTPRequest.new()
	add_child(httprequest)
	task.connect("completed", self, "_on_task_completed")
	task.push_request(httprequest)
	_pooled_tasks.append(task)

# Handle HTTPRequest completed
func _on_task_completed(task : DatabaseTask) -> void:
	if task._handler != null: task._handler.queue_free()
	if task.data != null and not task.data.empty():    
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
