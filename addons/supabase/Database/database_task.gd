@tool
extends BaseTask
class_name DatabaseTask

func match_code(code : int) -> int:
	match code:
		SupabaseQuery.REQUESTS.INSERT: return HTTPClient.METHOD_POST
		SupabaseQuery.REQUESTS.SELECT: return HTTPClient.METHOD_GET
		SupabaseQuery.REQUESTS.UPDATE: return HTTPClient.METHOD_PATCH
		SupabaseQuery.REQUESTS.DELETE: return HTTPClient.METHOD_DELETE
		_: return HTTPClient.METHOD_POST

func _on_task_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray, handler: HTTPRequest) -> void:
	var result_body: Variant = JSON.parse_string(body.get_string_from_utf8())
	if response_code < 300:
		complete(result_body)
	else:
		var supabase_error : SupabaseDatabaseError = SupabaseDatabaseError.new(result_body)
		complete(null, supabase_error)
	handler.queue_free()

func complete(_data = null, _error : SupabaseDatabaseError = null) -> void:
	super._complete(_data, _error)
