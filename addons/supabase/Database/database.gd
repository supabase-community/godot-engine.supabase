class_name SupabaseDatabase
extends Node

signal selected(query_result)
signal inserted(query_result)
signal updated(query_result)
signal deleted(query_result)
signal error(body)

const _rest_endpoint : String = "/rest/v1/"

var _config : Dictionary = {}
var _header : PoolStringArray = ["Prefer: return=representation"]
var _bearer : PoolStringArray = ["Authorization: Bearer %s"]

func _init(conf : Dictionary, head : PoolStringArray) -> void:
    _config = conf
    _header += head


# Issue a query on your database
func query(supabase_query : SupabaseQuery) -> DatabaseTask:
    _bearer = Supabase.auth._bearer
    var endpoint : String = _config.supabaseUrl + _rest_endpoint + supabase_query.build_query()
    var task : DatabaseTask = DatabaseTask.new(
        supabase_query,
        supabase_query.request, 
        endpoint, 
        _header + _bearer + supabase_query.header, 
        supabase_query.body)
    _process_task(task)
    return task


func _process_task(task : DatabaseTask) -> void:
    var httprequest : HTTPRequest = HTTPRequest.new()
    add_child(httprequest)
    task.connect("completed", self, "_on_task_completed")
    task.push_request(httprequest)
    add_child(task)


# .............. HTTPRequest completed
func _on_task_completed(task : DatabaseTask) -> void:
    if task.data != []:    
        match task._code:
            SupabaseQuery.REQUESTS.SELECT: emit_signal("selected", task.data)
            SupabaseQuery.REQUESTS.INSERT: emit_signal("inserted", task.data)
            SupabaseQuery.REQUESTS.UPDATE: emit_signal("updated", task.data)
            SupabaseQuery.REQUESTS.DELETE: emit_signal("deleted", task.data)
    elif task.error != null:
        emit_signal("error", task.error)
