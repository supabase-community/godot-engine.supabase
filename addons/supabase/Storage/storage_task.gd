class_name StorageTask
extends Reference

signal completed(task)

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

var _code : int
var _method : int
var _endpoint : String
var _headers : PoolStringArray
var _payload : String
var _bytepayload : PoolByteArray

# EXPOSED VARIABLES ---------------------------------------------------------
var data 
var error : SupabaseStorageError
# ---------------------------------------------------------------------------

var _handler : HTTPRequest = null

func _init(data = null, error : SupabaseStorageError = null) -> void:
	self.data = data
	self.error = error

func _setup(code : int, endpoint : String, headers : PoolStringArray,  payload : String = "", bytepayload : PoolByteArray = []):
	_code = code
	_endpoint = endpoint
	_headers = headers
	_payload = payload
	_bytepayload = bytepayload
	_method = match_code(code)


func match_code(code : int) -> int:
	match code:
		METHODS.LIST_BUCKETS, METHODS.GET_BUCKET, METHODS.DOWNLOAD: return HTTPClient.METHOD_GET
		METHODS.CREATE_BUCKET, METHODS.UPDATE_BUCKET, METHODS.EMPTY_BUCKET, \
		METHODS.LIST_OBJECTS, METHODS.UPLOAD_OBJECT, METHODS.MOVE_OBJECT, \
		METHODS.CREATE_SIGNED_URL: return HTTPClient.METHOD_POST
		METHODS.UPDATE_OBJECT: return HTTPClient.METHOD_PUT
		METHODS.DELETE_BUCKET, METHODS.REMOVE: return HTTPClient.METHOD_DELETE
		_: return HTTPClient.METHOD_GET


func push_request(httprequest : HTTPRequest) -> void:
	_handler = httprequest
	httprequest.connect("request_completed", self, "_on_task_completed")
	httprequest.request(_endpoint, _headers, true, _method, _payload)


func _on_task_completed(result : int, response_code : int, headers : PoolStringArray, body : PoolByteArray) -> void:
	var result_body = JSON.parse(body.get_string_from_utf8()).result if body.get_string_from_utf8() else {}
	if response_code in [200, 201, 204]:
		if _code == METHODS.DOWNLOAD:
			complete(body)
		else:
			complete(result_body)
	else:
		var supabase_error : SupabaseStorageError = SupabaseStorageError.new(result_body)
		complete(null, supabase_error)

func complete(_result,  _error : SupabaseStorageError = null) -> void:
	data = _result
	error = _error
	if _handler: _handler.queue_free()
	emit_signal("completed", self)
