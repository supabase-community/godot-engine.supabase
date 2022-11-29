@tool
extends BaseTask
class_name StorageTask

enum METHODS {
	LIST_BUCKETS,
	GET_BUCKET,
	CREATE_BUCKET,
	UPDATE_BUCKET,
	EMPTY_BUCKET,
	DELETE_BUCKET,
	
	LIST_OBJECTS,
	UPLOAD_OBJECT,
	UPDATE_OBJECT,
	MOVE_OBJECT,
	CREATE_SIGNED_URL,
	DOWNLOAD,
	GET_PUBLIC_URL,
	REMOVE
   }

var bytepayload : PackedByteArray

func match_code(code : int) -> int:
	match code:
		METHODS.LIST_BUCKETS, METHODS.GET_BUCKET, METHODS.DOWNLOAD: return HTTPClient.METHOD_GET
		METHODS.CREATE_BUCKET, METHODS.UPDATE_BUCKET, METHODS.EMPTY_BUCKET, \
		METHODS.LIST_OBJECTS, METHODS.UPLOAD_OBJECT, METHODS.MOVE_OBJECT, \
		METHODS.CREATE_SIGNED_URL: return HTTPClient.METHOD_POST
		METHODS.UPDATE_OBJECT: return HTTPClient.METHOD_PUT
		METHODS.DELETE_BUCKET, METHODS.REMOVE: return HTTPClient.METHOD_DELETE
		_: return HTTPClient.METHOD_GET

func _on_task_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray, handler: HTTPRequest) -> void:
	var result_body: Dictionary = JSON.parse_string(body.get_string_from_utf8())
	if response_code in [200, 201, 204]:
		if _code == METHODS.DOWNLOAD:
			complete(body)
		else:
			complete(result_body)
	else:
		var supabase_error : SupabaseStorageError = SupabaseStorageError.new(result_body)
		complete(null, supabase_error)
	if handler != null: handler.queue_free()

func complete(_data = null, _error : SupabaseStorageError = null) -> void:
	self._complete(_data, _error)
