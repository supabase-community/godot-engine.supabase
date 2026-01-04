@tool
extends RefCounted
class_name BaseTask

signal completed(task: BaseTask)

var _code : int
var _method : int
var _endpoint : String
var _headers : PackedStringArray
var _payload : String

# EXPOSED VARIABLES -------------
var error : BaseError
var data
# -------------------------------

func _init(data = null, error: BaseError = null) -> void:
	self.data = data
	self.error = error

func _setup(code: int, endpoint: String, headers: PackedStringArray, payload: String = "") -> BaseTask:
	_code = code
	_endpoint = endpoint
	_headers = headers
	_payload = payload
	_method = match_code(code)
	return self

func match_code(code : int) -> int:
	return -1

func push_request(httprequest : HTTPRequest) -> void:
	reference()
	httprequest.request_completed.connect(_on_task_completed.bind(httprequest))
	httprequest.request(_endpoint, _headers, _method, _payload)

func _on_task_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray, handler: HTTPRequest) -> void:
	pass

func _complete(_data = null, _error : BaseError = null) -> void:
	data = _data
	error = _error
	completed.emit(self)
	unreference()

func _to_string() -> String:
	return "%s, %s" % [data, error]
