extends HTTPRequest
class_name SupabaseAuth

signal signed_up(signed_user)
signal signed_in(signed_user)
signal got_user()
signal error(error_body)

const _auth_endpoint : String = "/auth/v1/"
const _signup_endpoint : String = _auth_endpoint+"/signup"
const _signin_endpoint : String = _auth_endpoint+"/token?grant_type=password"
const _user_endpoint : String = _auth_endpoint+"/user"

enum REQUEST_CODES {
	NONE
	SIGNUP
	SIGNIN
	USER
}

var _config : Dictionary = {}
var _header : PoolStringArray = []
var _bearer : PoolStringArray = ["Authorization: Bearer %s"]
var _request_code : int = REQUEST_CODES.NONE

var _auth : String = ""
var _expires_in : float = 0

func _init(conf : Dictionary, head : PoolStringArray) -> void:
	_config = conf
	_header = head
	connect("request_completed", self, "_on_request_completed")

# Allow your users to sign up and create a new account.
func sign_up(email : String, password : String) -> void:
	_request_code = REQUEST_CODES.SIGNUP
	request(_config.supabaseUrl+_signup_endpoint, _header, true, HTTPClient.METHOD_POST, JSON.print({"email":email, "password":password}))

# If an account is created, users can login to your app.
func sign_in(email : String, password : String) -> void:
	_request_code = REQUEST_CODES.SIGNIN
	request(_config.supabaseUrl+_signin_endpoint, _header, true, HTTPClient.METHOD_POST, JSON.print({"email":email, "password":password}))

# Get the JSON object for the logged in user.
func user(access_token : String = _auth) -> void:
	_request_code = REQUEST_CODES.USER
	request(_config.supabaseUrl+_user_endpoint, _header + _bearer, true, HTTPClient.METHOD_GET)

func _on_request_completed(result : int, response_code : int, headers : PoolStringArray, body : PoolByteArray) -> void:
	var result_body : Dictionary = JSON.parse(body.get_string_from_utf8()).result
	print(result_body)
	
	if response_code == 200:
		match _request_code:
			REQUEST_CODES.SIGNUP, REQUEST_CODES.SIGNIN: 
				var signed_in_user : SupabaseUser = SupabaseUser.new(result_body)
				emit_signal("signed_in" if _request_code == REQUEST_CODES.SIGNIN else "signed_up", signed_in_user)
				_auth = result_body.access_token
				_bearer[0] = _bearer[0] % _auth
				_expires_in = float(result_body.expires_in)
				print(_header + _bearer)
			REQUEST_CODES.USER:
				emit_signal("got_user")
	else:
		emit_signal("error", result_body)
	_request_code = REQUEST_CODES.NONE
