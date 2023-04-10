@tool
class_name SupabaseAuth
extends Node

class Providers:
	const APPLE := "apple"
	const BITBUCKET := "bitbucket"
	const DISCORD := "discord"
	const FACEBOOK := "facebook"
	const GITHUB := "github"
	const GITLAB := "gitlab"
	const GOOGLE := "google"
	const TWITTER := "twitter"

signal signed_up(signed_user: SupabaseUser)
signal signed_up_phone(signed_user: SupabaseUser)
signal signed_in(signed_user: SupabaseUser)
signal signed_in_otp(signed_user: SupabaseUser)
signal otp_verified()
signal signed_in_anonyous()
signal signed_out()
signal got_user()
signal user_updated(updated_user: SupabaseUser)
signal magic_link_sent()
signal reset_email_sent()
signal token_refreshed(refreshed_user: SupabaseUser)
signal user_invited()
signal error(supabase_error: SupabaseAuthError)

const _auth_endpoint : String = "/auth/v1"
const _provider_endpoint : String = _auth_endpoint+"/authorize"
const _signin_endpoint : String = _auth_endpoint+"/token?grant_type=password"
const _signin_otp_endpoint : String = _auth_endpoint+"/otp"
const _verify_otp_endpoint : String = _auth_endpoint+"/verify"
const _signup_endpoint : String = _auth_endpoint+"/signup"
const _refresh_token_endpoint : String = _auth_endpoint+"/token?grant_type=refresh_token"
const _logout_endpoint : String = _auth_endpoint+"/logout"
const _user_endpoint : String = _auth_endpoint+"/user"
const _magiclink_endpoint : String = _auth_endpoint+"/magiclink"
const _invite_endpoint : String = _auth_endpoint+"/invite"
const _reset_password_endpoint : String = _auth_endpoint+"/recover"

var tcp_server : TCPServer = TCPServer.new()
var tcp_timer : Timer = Timer.new()

var _config : Dictionary = {}
var _header : PackedStringArray = []
var _bearer : PackedStringArray = ["Authorization: Bearer %s"]

var _auth : String = ""
var _expires_in : float = 0

var client : SupabaseUser

func _init(conf : Dictionary, head : PackedStringArray) -> void:
	_config = conf
	_header = head
	name = "Authentication"  

func __get_session_header() -> PackedStringArray :
	return PackedStringArray([_bearer[0] % ( _auth if not _auth.is_empty() else _config.supabaseKey )])

func _check_auth() -> AuthTask:
	var auth_task : AuthTask = AuthTask.new()
	auth_task.completed.emit()
	return auth_task

# Allow your users to sign up and create a new account.
func sign_up(email : String, password : String) -> AuthTask:
	if _auth != "": return _check_auth()
	var payload : Dictionary = {"email":email, "password":password}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.SIGNUP,
		_config.supabaseUrl + _signup_endpoint, 
		_header,
		JSON.stringify(payload)
	)
	_process_task(auth_task)
	return auth_task


# Allow your users to sign up and create a new account using phone/password combination.
# NOTE: the OTP sent to the user must be verified.
func sign_up_phone(phone : String, password : String) -> AuthTask:
	if _auth != "": return _check_auth()
	var payload : Dictionary = {"phone":phone, "password":password}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.SIGNUPPHONEPASSWORD,
		_config.supabaseUrl + _signup_endpoint, 
		_header,
		JSON.stringify(payload))
	_process_task(auth_task)
	return auth_task


# If an account is created, users can login to your app.
func sign_in(email : String, password : String = "") -> AuthTask:
	if _auth != "": return _check_auth()
	var payload : Dictionary = {"email":email, "password":password}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.SIGNIN,
		_config.supabaseUrl + _signin_endpoint, 
		_header,
		JSON.stringify(payload)
	)
	_process_task(auth_task)
	return auth_task


# If an account is created, users can login to your app using phone/password combination.
# NOTE: this requires sign_up_phone() and verify_otp() to work
func sign_in_phone(phone : String, password : String = "") -> AuthTask:
	if _auth != "": return _check_auth()
	var payload : Dictionary = {"phone":phone, "password":password}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.SIGNIN,
		_config.supabaseUrl + _signin_endpoint, 
		_header,
		JSON.stringify(payload))
	_process_task(auth_task)
	return auth_task


# Sign in using OTP - the user won't need to use a password but the token must be validated.
# This method always requires to use OTP verification, unlike sign_in_phone()
func sign_in_otp(phone : String) -> AuthTask:
	if _auth != "": return _check_auth()
	var payload : Dictionary = {"phone":phone}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.SIGNINOTP,
		_config.supabaseUrl + _signin_otp_endpoint, 
		_header,
		JSON.stringify(payload))
	_process_task(auth_task)
	return auth_task


# Verify the OTP token sent to a user as an SMS
func verify_otp(phone : String, token : String) -> AuthTask:
	if _auth != "": return _check_auth()
	var payload : Dictionary = {phone = phone, token = token, type = "sms"}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.VERIFYOTP,
		_config.supabaseUrl + _verify_otp_endpoint, 
		_header,
		JSON.stringify(payload))
	_process_task(auth_task)
	return auth_task

# Verify the OTP token sent to a user as an email
func verify_otp_email(email : String, token : String, type : String) -> AuthTask:
	if _auth != "": return _check_auth()
	var payload : Dictionary = {email = email, token = token, type = type}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.VERIFYOTP,
		_config.supabaseUrl + _verify_otp_endpoint, 
		_header,
		JSON.stringify(payload))
	_process_task(auth_task)
	return auth_task

# Sign in as an anonymous user
func sign_in_anonymous() -> AuthTask:
	if _auth != "": return _check_auth()
	var auth_task : AuthTask = AuthTask.new()._setup(AuthTask.Task.SIGNINANONYM, "", [])
	auth_task.user = SupabaseUser.new({user = {}, access_token = _config.supabaseKey})
	_process_task(auth_task, true)
	return auth_task


# [     CURRENTLY UNSUPPORTED       ]
# Sign in with a Provider
# @provider = Providers.PROVIDER
func sign_in_with_provider(provider : String, grab_from_browser : bool = true, port : int = 3000) -> void:
	OS.shell_open(_config.supabaseUrl + _provider_endpoint + "?provider="+provider)
	# ! to be implemented
	pass


# If a user is logged in, this will log it out
func sign_out() -> AuthTask:
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.LOGOUT,
		_config.supabaseUrl + _logout_endpoint, 
		_header + __get_session_header())
	_process_task(auth_task)
	return auth_task


# If an account is created, users can login to your app with a magic link sent via email.
# NOTE: this method currently won't work unless the fragment (#) is *MANUALLY* replaced with a query (?) and the browser is reloaded
# [https://github.com/supabase/supabase/issues/1698]
func send_magic_link(email : String)  -> AuthTask:
	var payload : Dictionary = {"email":email}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.MAGICLINK,
		_config.supabaseUrl + _magiclink_endpoint, 
		_header,
		JSON.stringify(payload))
	_process_task(auth_task)
	return auth_task


# Get the JSON object for the logged in user.
func user(user_access_token : String = _auth) -> AuthTask:
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.USER,
		_config.supabaseUrl + _user_endpoint, 
		_header + __get_session_header())
	_process_task(auth_task)
	return auth_task


# Update credentials of the authenticated user, together with optional metadata
func update(email : String, password : String = "", data : Dictionary = {}) -> AuthTask:
	var payload : Dictionary = {"email":email, "password":password, "data" : data}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.UPDATE,
		_config.supabaseUrl + _user_endpoint, 
		_header + __get_session_header(),
		JSON.stringify(payload))
	_process_task(auth_task)
	return auth_task

# Update email of the authenticated user
func update_email(email : String) -> AuthTask:
	var payload : Dictionary = {"email":email}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.UPDATE,
		_config.supabaseUrl + _user_endpoint, 
		_header + __get_session_header(),
		JSON.stringify(payload))
	_process_task(auth_task)
	return auth_task

# Request a reset password mail to the specified email
func reset_password_for_email(email : String) -> AuthTask:
	var payload : Dictionary = {"email":email}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.RECOVER,
		_config.supabaseUrl + _reset_password_endpoint, 
		_header,
		JSON.stringify(payload))
	_process_task(auth_task)
	return auth_task


# Invite another user by their email
func invite_user_by_email(email : String) -> AuthTask:
	var payload : Dictionary = {"email":email}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.INVITE,
		_config.supabaseUrl + _invite_endpoint, 
		_header + __get_session_header(),
		JSON.stringify(payload))
	_process_task(auth_task)
	return auth_task


# Refresh the access_token of the authenticated client using the refresh_token
# No need to call this manually except specific needs, since the process will be handled automatically
func refresh_token(refresh_token : String = client.refresh_token, expires_in : float = client.expires_in) -> AuthTask:
	await get_tree().create_timer(expires_in - 10).timeout
	var payload : Dictionary = {refresh_token = refresh_token}
	var auth_task : AuthTask = AuthTask.new()._setup(
		AuthTask.Task.REFRESH,
		_config.supabaseUrl + _refresh_token_endpoint, 
		_header + __get_session_header(),
		JSON.stringify(payload))
	_process_task(auth_task)
	return auth_task 



# Retrieve the response from the server
func _get_link_response(delta : float) -> String:
	await get_tree().create_timer(delta).timeout
	var peer : StreamPeer = tcp_server.take_connection()
	if peer != null:
		var raw_result : String = peer.get_utf8_string(peer.get_available_bytes())
		return raw_result
	else:
		_get_link_response(delta)
		return ""


# Process a specific task
func _process_task(task : AuthTask, _fake : bool = false) -> void:
	task.completed.connect(_on_task_completed)
	if _fake:
		await get_tree().create_timer(0.5).timeout
		task.complete(task.user, task.data, task.error)
	else:
		var httprequest : HTTPRequest = HTTPRequest.new()
		add_child(httprequest)
		task.push_request(httprequest)


func _on_task_completed(task : AuthTask) -> void:
	if task.error != null:
		error.emit(task.error)
	else:
		if task.user != null:
			client = task.user
			_auth = client.access_token
			_expires_in = client.expires_in
			match task._code:
				AuthTask.Task.SIGNUP:
					signed_up.emit(client)
				AuthTask.Task.SIGNUPPHONEPASSWORD:
					signed_up_phone.emit(client)
				AuthTask.Task.SIGNIN:
					signed_in.emit(client)
				AuthTask.Task.SIGNINOTP:
					signed_in_otp.emit(client)
				AuthTask.Task.UPDATE: 
					user_updated.emit(client)
				AuthTask.Task.REFRESH:
					token_refreshed.emit(client)
				AuthTask.Task.VERIFYOTP:
					otp_verified.emit(client)
				AuthTask.Task.SIGNINANONYM:
					signed_in_anonyous.emit()
			refresh_token()
		else: 
			if task.data.is_empty() or task.data == null:
				match task._code:
					AuthTask.Task.MAGICLINK:
						magic_link_sent.emit()
					AuthTask.Task.RECOVER:
						reset_email_sent.emit()
					AuthTask.Task.INVITE:
						user_invited.emit()
					AuthTask.Task.LOGOUT:
						client = null
						_auth = ""
						_expires_in = 0
						signed_out.emit()

# A timer used to listen through TCP on the redirect uri of the request
func _tcp_stream_timer() -> void:
	var peer : StreamPeer = tcp_server.take_connection()
	# ! to be implemented
	pass
