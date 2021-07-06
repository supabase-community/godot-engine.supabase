class_name AuthTask
extends Reference

signal completed(task)

enum Task {
    NONE,
    SIGNUP,
    SIGNIN,
    MAGICLINK,
    LOGOUT,
    USER,
    UPDATE,
    RECOVER,
    REFRESH,
    INVITE
}

var _code : int
var _method : int
var _endpoint : String
var _headers : PoolStringArray
var _payload : Dictionary

# EXPOSED VARIABLES ---------------------------------------------------------
var error : SupabaseAuthError
var user : SupabaseUser
var data : Dictionary
# ---------------------------------------------------------------------------

var _handler : HTTPRequest

func _init(code : int, endpoint : String, headers : PoolStringArray, payload : Dictionary = {}):
    _code = code
    _endpoint = endpoint
    _headers = headers
    _payload = payload
    _method = match_code(code)

func match_code(code : int) -> int:
    match code:
        Task.SIGNIN, Task.SIGNUP, Task.LOGOUT, Task.MAGICLINK, Task.RECOVER, Task.REFRESH, Task.INVITE:
            return HTTPClient.METHOD_POST
        Task.UPDATE:
            return HTTPClient.METHOD_PUT
        _, Task.USER:
            return HTTPClient.METHOD_GET

func push_request(httprequest : HTTPRequest) -> void:
    _handler = httprequest
    _handler.connect("request_completed", self, "_on_task_completed")
    _handler.request(_endpoint, _headers, true, _method, to_json(_payload))

func _on_task_completed(result : int, response_code : int, headers : PoolStringArray, body : PoolByteArray) -> void:
    var result_body : Dictionary = JSON.parse(body.get_string_from_utf8()).result if body.get_string_from_utf8() else {}
    match response_code:
        200:
            match _code:
                Task.SIGNUP, Task.SIGNIN, Task.UPDATE, Task.REFRESH:
                    complete(SupabaseUser.new(result_body), result_body)
                Task.MAGICLINK, Task.RECOVER, Task.INVITE:
                    complete()
        0, 204:
            match _code:
                Task.LOGOUT, Task.USER:
                    complete()
        _:
            if result_body == null : result_body = {}
            complete(null, {}, SupabaseAuthError.new(result_body))

func complete(_user : SupabaseUser = null, _data : Dictionary = {},  _error : SupabaseAuthError = null) -> void:
    user = _user
    data = _data
    error = _error
    emit_signal("completed", self)

        
