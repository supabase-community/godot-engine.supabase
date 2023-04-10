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
var __json: JSON = JSON.new()

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
	var err: int = __json.parse(body.get_string_from_utf8())
	var result_body = __json.data if err == OK else {}
	if response_code in [200, 201, 204]:
		if _code == METHODS.DOWNLOAD:
			complete(body)
		else:
			if _code == METHODS.CREATE_SIGNED_URL:
				result_body.signedURL = get_meta("base_url") + result_body.signedURL
				var download = get_meta("options").get("download")
				if download:
					result_body.signedURL += "&download=%s" % download if (download is String) else get_meta("object")
			complete(result_body)
	else:
		if result_body.is_empty():
			result_body.statusCode = str(response_code)
		var supabase_error : SupabaseStorageError = SupabaseStorageError.new(result_body)
		complete(null, supabase_error)
	if handler != null: handler.queue_free()

func complete(_data = null, _error : SupabaseStorageError = null) -> void:
	self._complete(_data, _error)
