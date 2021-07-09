class_name DatabaseTask
extends Reference

signal completed(task)

var _code : int
var _method : int
var _endpoint : String
var _headers : PoolStringArray
var _payload : String
var _query : SupabaseQuery

# EXPOSED VARIABLES ---------------------------------------------------------
var data 
var error : SupabaseDatabaseError
# ---------------------------------------------------------------------------

var _handler : HTTPRequest

func _init(data = null, error : SupabaseDatabaseError = null) -> void:
    self.data = data
    self.error = error

func _setup(query : SupabaseQuery, code : int, endpoint : String, headers : PoolStringArray,  payload : String = ""):
    _query = query
    _code = code
    _endpoint = endpoint
    _headers = headers
    _payload = payload
    _method = match_code(code)


func match_code(code : int) -> int:
    match code:
        SupabaseQuery.REQUESTS.INSERT: return HTTPClient.METHOD_POST
        SupabaseQuery.REQUESTS.SELECT: return HTTPClient.METHOD_GET
        SupabaseQuery.REQUESTS.UPDATE: return HTTPClient.METHOD_PATCH
        SupabaseQuery.REQUESTS.DELETE: return HTTPClient.METHOD_DELETE
        _: return HTTPClient.METHOD_POST

func push_request(httprequest : HTTPRequest) -> void:
    _handler = httprequest
    httprequest.connect("request_completed", self, "_on_task_completed")
    httprequest.request(_endpoint, _headers, true, _method, _payload)

func _on_task_completed(result : int, response_code : int, headers : PoolStringArray, body : PoolByteArray) -> void:
    var result_body = JSON.parse(body.get_string_from_utf8()).result if body.get_string_from_utf8() else {}
    if response_code in [200, 201, 204]:
        complete(result_body)
    else:
        var supabase_error : SupabaseDatabaseError = SupabaseDatabaseError.new(result_body)
        complete(null, supabase_error)
    if _query!=null: _query.clean()

func complete(_result,  _error : SupabaseDatabaseError = null) -> void:
    data = _result
    error = _error
    if _handler : _handler.queue_free()
    emit_signal("completed", self)
