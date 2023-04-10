@tool
class_name StorageBucket
extends Node

const MIME_TYPES : Dictionary = {
	"bmp": "image/bmp",
	"css": "text/css",
	"csv": "text/csv",
	"gd": "text/plain",
	"htm": "text/html",
	"html": "text/html",
	"jpeg": "image/jpeg",
	"jpg": "image/jpeg",
	"json": "application/json",
	"mp3": "audio/mpeg",
	"mpeg": "video/mpeg",
	"ogg": "audio/ogg",
	"ogv": "video/ogg",
	"pdf": "application/pdf",
	"png": "image/png",
	"res": "text/plain",
	"shader": "text/plain",
	"svg": "image/svg+xml",
	"tif": "image/tiff",
	"tiff": "image/tiff",
	"tres": "text/plain",
	"tscn": "text/plain",
	"txt": "text/script",
	"wav": "audio/wav",
	"webm": "video/webm",
	"webp": "video/webm",
	"xml": "text/xml",
}

signal listed_objects(details)
signal uploaded_object(details)
signal updated_object(details)
signal moved_object(details)
signal removed_objects(details)
signal created_signed_url(details)
signal downloaded_object(details)
signal error(error)

const _rest_endpoint : String = "/storage/v1/object/"

var _config : Dictionary
var _header : PackedStringArray = ["Content-Type: %s", "Content-Disposition: attachment"]

var _pooled_tasks : Array = []

var _http_client : HTTPClient = HTTPClient.new()
var _current_task : StorageTask = null

var _reading_body : bool = false
var requesting_raw : bool = false
var _response_headers : PackedStringArray
var _response_data : PackedByteArray
var _content_length : int
var _response_code : int


var id : String

func _init(id : String , config : Dictionary) -> void:
	_config = config
	self.id = id
	name = "Bucket_"+id
	set_process_internal(false)


func list(prefix : String = "", limit : int = 100, offset : int = 0, sort_by : Dictionary = {column = "name", order = "asc"} ) -> StorageTask:
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + "/list/" + id
	var task : StorageTask = StorageTask.new()
	var header : PackedStringArray = [_header[0] % "application/json"]
	task._setup(
		task.METHODS.LIST_OBJECTS, 
		endpoint, 
		header + get_parent().get_parent().get_parent().auth.__get_session_header(),
		JSON.stringify({ prefix = prefix, limit = limit, offset = offset, sortBy = sort_by })
	)
	_process_task(task)
	return task


func upload(object : String, file_path : String, upsert : bool = false) -> StorageTask:
	requesting_raw = true
	var task : StorageTask = StorageTask.new()
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + id + "/" + object
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null: 
		printerr("could not open %s. Reason: %s" % [file_path, file.get_open_error()])
		task.complete({})
		return task
	var header : PackedStringArray = [_header[0] % MIME_TYPES.get(file_path.get_extension(), "application/octet-stream")]
	header.append("Content-Length: %s" % file.get_length())
	header.append("x-upsert: %s" % upsert)
	task.completed.connect(_on_task_completed)
	task._setup(
		task.METHODS.UPLOAD_OBJECT, 
		endpoint, 
		header + get_parent().get_parent().get_parent().auth.__get_session_header()
	)
	task.bytepayload = file.get_buffer(file.get_length())
	
	_current_task = task
	set_process_internal(requesting_raw)
	file.close()
	return task


func update(bucket_path : String, file_path : String) -> StorageTask:
	requesting_raw = true
	var task : StorageTask = StorageTask.new()
	task.completed.connect(_on_task_completed)
	
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + id + "/" + bucket_path
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null: 
		printerr("could not open %s. Reason: %s" % [file_path, file.get_open_error()])
		task.complete({})
		return task
	var header : PackedStringArray = [_header[0] % MIME_TYPES[file_path.get_extension()]]
	header.append("Content-Length: %s" % file.get_len())
	
	task._setup(
		task.METHODS.UPDATE_OBJECT, 
		endpoint, 
		header + get_parent().get_parent().get_parent().auth.__get_session_header()
	)
	task.bytepayload = file.get_buffer(file.get_len())
	
	_current_task = task
	set_process_internal(requesting_raw)
	file.close()
	return task


func move(source_path : String, destination_path : String) -> StorageTask:
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + "move"
	var task : StorageTask = StorageTask.new()
	var header : PackedStringArray = [_header[0] % "application/json"]
	task._setup(
		task.METHODS.MOVE_OBJECT, 
		endpoint, 
		header + get_parent().get_parent().get_parent().auth.__get_session_header(),
		JSON.stringify({bucketId = id, sourceKey = source_path, destinationKey = destination_path}))
	_process_task(task)
	return task


func download(object : String, to_path : String = "", private : bool = false, options: Dictionary = {
	transform = { height = 100, width = 100, format = "origin", resize = "cover", quality = 80 }
}  ) -> StorageTask:
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + \
		("authenticated/" if private else "public/") + id + "/" + object + \
		_get_transform_query(options.get("transform", {}))
	var task : StorageTask = StorageTask.new()
	var header : PackedStringArray = [_header[0] % "application/json"]
	task._setup(
		task.METHODS.DOWNLOAD, 
		endpoint, 
		header + get_parent().get_parent().get_parent().auth.__get_session_header()
		)
	_process_task(task, {download_file = to_path})
	return task


func create_signed_url(object : String, expires_in : int = 60000, options: Dictionary = {
	download = true, transform = { format = "origin" , quality = 80 , resize = "cover" , height = 100, width = 100 }
}) -> StorageTask:
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + "sign/" + id + "/" + object
	var task : StorageTask = StorageTask.new()
	var header : PackedStringArray = [_header[0] % "application/json"]
	task._setup(
		task.METHODS.CREATE_SIGNED_URL, 
		endpoint, 
		header + get_parent().get_parent().get_parent().auth.__get_session_header(),
		JSON.stringify({expiresIn = expires_in, transform = options.get("transform", {}) })
	)
	task.set_meta("object", object)
	task.set_meta("options", options)
	task.set_meta("base_url", _config.supabaseUrl + _rest_endpoint.replace("/object/", ""))
	_process_task(task)
	return task



func get_public_url(object: String, options: Dictionary = { transform = {
	height = 100, width = 100, format = "origin", resize = "cover", quality = 80
} }) -> String:
	var url: String = _config.supabaseUrl + _rest_endpoint + "public/" + id + "/" + object
	return url + _get_transform_query(options.get("transform", {}))


func remove(objects : PackedStringArray) -> StorageTask:
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + id + ("/" + objects[0] if objects.size() == 1 else "")
	var task : StorageTask = StorageTask.new()
	var header : PackedStringArray = [_header[0] % "application/json"]
	task._setup(
		task.METHODS.REMOVE, 
		endpoint, 
		header + get_parent().get_parent().get_parent().auth.__get_session_header(),
		JSON.stringify({prefixes = objects}) if objects.size() > 1 else "" )
	_process_task(task)
	return task



func _get_transform_query(transform: Dictionary) -> String:
	var query: String = ""
	if not transform.keys().is_empty():
		query += "?"
	for key in transform.keys():
		query += "&%s=%s" % [key, transform.get(key)]
	return query

func _notification(what : int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS:
		_internal_process(get_process_delta_time())

func _internal_process(_delta : float) -> void:
	if not requesting_raw:
		set_process_internal(false)
		return
	
	var task : StorageTask = _current_task
	
	match _http_client.get_status():
		HTTPClient.STATUS_DISCONNECTED:
			_http_client.connect_to_host(_config.supabaseUrl, 443)
		
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_REQUESTING, HTTPClient.STATUS_CONNECTING:
			_http_client.poll()

		HTTPClient.STATUS_CONNECTED:
			var err : int = _http_client.request_raw(task._method, task._endpoint.replace(_config.supabaseUrl, ""), task._headers, task.bytepayload)
			if err :
				task.error = SupabaseStorageError.new({statusCode = HTTPRequest.RESULT_CONNECTION_ERROR})
				_on_task_completed(task)
		
		HTTPClient.STATUS_BODY:
			if _http_client.has_response() or _reading_body:
				_reading_body = true
				
				# If there is a response...
				if _response_headers.is_empty():
					_response_headers = _http_client.get_response_headers() # Get response headers.
					_response_code = _http_client.get_response_code()
					
					for header in _response_headers:
						if "Content-Length" in header:
							_content_length = header.trim_prefix("Content-Length: ").to_int()
				
				_http_client.poll()
				var chunk : PackedByteArray = _http_client.read_response_body_chunk() # Get a chunk.
				if chunk.size() == 0:
					# Got nothing, wait for buffers to fill a bit.
					pass
				else:
					_response_data += chunk # Append to read buffer.
					if _content_length != 0:
						pass
				if _http_client.get_status() != HTTPClient.STATUS_BODY:
					task._on_task_completed(0, _response_code, _response_headers, [], null)
			else:
				task._on_task_completed(0, _response_code, _response_headers, [], null)
				
		HTTPClient.STATUS_CANT_CONNECT:
			task.error = SupabaseStorageError.new({statusCode = HTTPRequest.RESULT_CANT_CONNECT})
		HTTPClient.STATUS_CANT_RESOLVE:
			task.error = SupabaseStorageError.new({statusCode = HTTPRequest.RESULT_CANT_RESOLVE})
		HTTPClient.STATUS_CONNECTION_ERROR:
			task.error = SupabaseStorageError.new({statusCode = HTTPRequest.RESULT_CONNECTION_ERROR})
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			task.error = SupabaseStorageError.new({statusCode = HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR})


# ---

func _process_task(task : StorageTask, _params : Dictionary = {}) -> void:
	var httprequest : HTTPRequest = HTTPRequest.new()
	add_child(httprequest)
	if not _params.is_empty():
		httprequest.download_file = _params.get("download_file", "")
	task.completed.connect(_on_task_completed)
	task.push_request(httprequest)
	_pooled_tasks.append(task)

# .............. HTTPRequest completed
func _on_task_completed(task : StorageTask) -> void:
	if requesting_raw:
		_clear_raw_request()
	if task.data!=null and not task.data.is_empty():    
		match task._code:
			task.METHODS.LIST_OBJECTS: emit_signal("listed_objects", task.data)
			task.METHODS.UPLOAD_OBJECT: emit_signal("uploaded_object", task.data)
			task.METHODS.UPDATE_OBJECT: emit_signal("updated_object", task.data)
			task.METHODS.MOVE_OBJECT: emit_signal("moved_object", task.data)
			task.METHODS.REMOVE: emit_signal("removed_objects", task.data)
			task.METHODS.CREATE_SIGNED_URL: emit_signal("created_signed_url", task.data)
			task.METHODS.DOWNLOAD: emit_signal("downloaded_object", task.data)
	elif task.error != null:
		emit_signal("error", task.error)
	_pooled_tasks.erase(task)

func _clear_raw_request() -> void:
	requesting_raw = false
	_current_task = null
	_reading_body = false
	_response_headers = []
	_response_data = []
	_content_length = -1
	_response_code = -1
	set_process_internal(requesting_raw)
	_http_client.close()
