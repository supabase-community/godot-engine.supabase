extends HTTPRequest
class_name SupabaseAuth

signal signed_up(signed_user)
signal signed_in(signed_user)
signal logged_out()
signal got_user()
signal error(supabase_error)

const _auth_endpoint : String = "/auth/v1"
const _signup_endpoint : String = _auth_endpoint+"/signup"
const _signin_endpoint : String = _auth_endpoint+"/token?grant_type=password"
const _logout_endpoint : String = _auth_endpoint+"/logout"
const _user_endpoint : String = _auth_endpoint+"/user"

var requests_queue : Array = []

enum REQUEST_CODES {
	NONE,
	SIGNUP,
	SIGNIN,
	LOGOUT,
	USER
}

var _config : Dictionary = {}
var _header : PoolStringArray = []
var _bearer : PoolStringArray = ["Authorization: Bearer %s"]
var _request_code : int = REQUEST_CODES.NONE

var _auth : String = ""
var _expires_in : float = 0

var client : SupabaseUser

func _init(conf : Dictionary, head : PoolStringArray) -> void:
	_config = conf
	_header = head
	connect("request_completed", self, "_on_request_completed")

# Allow your users to sign up and create a new account.
func sign_up(email : String, password : String) -> void:
	if _request_code != REQUEST_CODES.NONE: 
		requests_queue.append([REQUEST_CODES.SIGNUP, email, password])
		return
	_request_code = REQUEST_CODES.SIGNUP
	request(_config.supabaseUrl + _signup_endpoint, _header, true, HTTPClient.METHOD_POST, JSON.print({"email":email, "password":password}))

# If an account is created, users can login to your app.
func sign_in(email : String, password : String) -> void:
	if _request_code != REQUEST_CODES.NONE: 
		requests_queue.append([REQUEST_CODES.SIGNIN, email, password])
		return
	_request_code = REQUEST_CODES.SIGNIN
	request(_config.supabaseUrl + _signin_endpoint, _header, true, HTTPClient.METHOD_POST, JSON.print({"email":email, "password":password}))

# If a user is logged in, this will log it out
func log_out() -> void:
	if client == null : return
	if _request_code != REQUEST_CODES.NONE:
		requests_queue.append([REQUEST_CODES.LOGOUT])
		return
	_request_code = REQUEST_CODES.LOGOUT
	print(_config.supabaseUrl + _logout_endpoint)
	print(_header + _bearer)
	request(_config.supabaseUrl + _logout_endpoint, _header + _bearer, true, HTTPClient.METHOD_POST)


# Get the JSON object for the logged in user.
func user(user_access_token : String = _auth) -> void:
	if _request_code != REQUEST_CODES.NONE: 
		requests_queue.append([REQUEST_CODES.USER, user_access_token])
		return
	_request_code = REQUEST_CODES.USER
	request(_config.supabaseUrl + _user_endpoint, _header + _bearer, true, HTTPClient.METHOD_GET)


func _on_request_completed(result : int, response_code : int, headers : PoolStringArray, body : PoolByteArray) -> void:
	var result_body : Dictionary = JSON.parse(body.get_string_from_utf8()).result if body.get_string_from_utf8() else {}
	if response_code == 200:
		match _request_code:
			REQUEST_CODES.SIGNUP: 
				var signed_user : SupabaseUser = SupabaseUser.new(result_body)
				client = signed_user
				_bearer[0] = _bearer[0] % _auth
				_expires_in = float(result_body.expires_in)
				emit_signal("signed_up", signed_user)
			REQUEST_CODES.SIGNIN: 
				var signed_user : SupabaseUser = SupabaseUser.new(result_body)
				client = signed_user
				_auth = result_body.access_token
				_bearer[0] = _bearer[0] % _auth
				_expires_in = float(result_body.expires_in)
				emit_signal("signed_in", signed_user)
	elif response_code in [0, 204]:
		match _request_code:
			REQUEST_CODES.LOGOUT:
				_auth = ""
				_bearer[0] = "Authorization: Bearer %s"
				_expires_in = 0
				client = null
				emit_signal("logged_out")
			REQUEST_CODES.USER:
				emit_signal("got_user")
	else:
		if result_body == null : result_body = {}
		var supabase_error : SupabaseAuthError = SupabaseAuthError.new(result_body)
		emit_signal("error", supabase_error)
	_request_code = REQUEST_CODES.NONE
	check_queue()

func check_queue() -> void:
	if requests_queue.size() > 0 :
		var request : Array = requests_queue.pop_front()
		match request[0]:
			REQUEST_CODES.SIGNUP: sign_up(request[1], request[2])
			REQUEST_CODES.SIGNIN: sign_in(request[1], request[2])
			REQUEST_CODES.LOGOUT: log_out()
			REQUEST_CODES.USER: user(request[1])
