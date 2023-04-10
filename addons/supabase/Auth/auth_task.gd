@tool
extends BaseTask
class_name AuthTask

enum Task {
	NONE,
	SIGNUP,
	SIGNUPPHONEPASSWORD,
	SIGNIN,
	SIGNINANONYM,
	SIGNINOTP,
	MAGICLINK,
	LOGOUT,
	USER,
	UPDATE,
	RECOVER,
	REFRESH,
	INVITE,
	VERIFYOTP
}

# EXPOSED VARIABLES ---------------------------------------------------------
var user : SupabaseUser
# ---------------------------------------------------------------------------

func match_code(code: int = Task.NONE) -> int:
	match code:
		Task.SIGNIN, Task.SIGNUP, Task.LOGOUT, Task.MAGICLINK, Task.RECOVER, Task.REFRESH, Task.INVITE, Task.VERIFYOTP:
			return HTTPClient.METHOD_POST
		Task.UPDATE:
			return HTTPClient.METHOD_PUT
		_, Task.USER:
			return HTTPClient.METHOD_GET

func _on_task_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray, handler: HTTPRequest) -> void:
	if result != 0:
		complete(null, {}, SupabaseAuthError.new({ error = "Could not connect", code = result }))
		return
	
	var result_body : Dictionary
	
	if(!body.is_empty()):
		result_body = JSON.parse_string(body.get_string_from_utf8())
	
	match response_code:
		200:
			match _code:
				Task.SIGNUP, Task.SIGNIN, Task.UPDATE, Task.REFRESH, Task.VERIFYOTP:
					complete(SupabaseUser.new(result_body), result_body)
				Task.MAGICLINK, Task.RECOVER, Task.INVITE:
					complete()
		0, 204:
			match _code:
				Task.LOGOUT, Task.USER:
					complete()
		_:
			complete(null, {}, SupabaseAuthError.new(result_body))
	handler.queue_free()

func complete(_user : SupabaseUser = null, _data : Dictionary = {},  _error : SupabaseAuthError = null) -> void:
	user = _user
	super._complete(_data, _error)


