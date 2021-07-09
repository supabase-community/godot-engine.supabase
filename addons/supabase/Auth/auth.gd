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

signal signed_up(signed_user)
signal signed_in(signed_user)
signal logged_out()
signal got_user()
signal user_updated(updated_user)
signal magic_link_sent()
signal reset_email_sent()
signal token_refreshed(refreshed_user)
signal user_invited()
signal error(supabase_error)

const _auth_endpoint : String = "/auth/v1"
const _provider_endpoint : String = _auth_endpoint+"/authorize"
const _signin_endpoint : String = _auth_endpoint+"/token?grant_type=password"
const _signup_endpoint : String = _auth_endpoint+"/signup"
const _refresh_token_endpoint : String = _auth_endpoint+"/token?grant_type=refresh_token"
const _logout_endpoint : String = _auth_endpoint+"/logout"
const _user_endpoint : String = _auth_endpoint+"/user"
const _magiclink_endpoint : String = _auth_endpoint+"/magiclink"
const _invite_endpoint : String = _auth_endpoint+"/invite"
const _reset_password_endpoint : String = _auth_endpoint+"/recover"

var tcp_server : TCP_Server = TCP_Server.new()
var tcp_timer : Timer = Timer.new()

var _config : Dictionary = {}
var _header : PoolStringArray = []
var _bearer : PoolStringArray = ["Authorization: Bearer %s"]

var _auth : String = ""
var _expires_in : float = 0

var _pooled_tasks : Array = []

var client : SupabaseUser

func _init(conf : Dictionary, head : PoolStringArray) -> void:
    _config = conf
    _header = head
    name = "Authentication"


# Allow your users to sign up and create a new account.
func sign_up(email : String, password : String) -> AuthTask:
    var payload : Dictionary = {"email":email, "password":password}
    var auth_task : AuthTask = AuthTask.new(
        AuthTask.Task.SIGNUP,
        _config.supabaseUrl + _signup_endpoint, 
        _header,
        payload)
    _process_task(auth_task)
    return auth_task


# If an account is created, users can login to your app.
func sign_in(email : String, password : String = "") -> AuthTask:
    var payload : Dictionary = {"email":email, "password":password}
    var auth_task : AuthTask = AuthTask.new(
        AuthTask.Task.SIGNIN,
        _config.supabaseUrl + _signin_endpoint, 
        _header,
        payload)
    _process_task(auth_task)
    return auth_task


# Sign in as an anonymous user
func sign_in_anonymous() -> void:
    _auth = _config.supabaseKey
    _bearer[0] = _bearer[0] % _auth
    emit_signal("signed_in", null)

# Sign in with a Provider
# @provider = Providers.PROVIDER
func sign_in_with_provider(provider : String, grab_from_browser : bool = true, port : int = 3000) -> void:
    OS.shell_open(_config.supabaseUrl + _provider_endpoint + "?provider="+provider)
    # ! to be implemented
    pass


# If a user is logged in, this will log it out
func sign_out() -> AuthTask:
    var auth_task : AuthTask = AuthTask.new(
        AuthTask.Task.LOGOUT,
        _config.supabaseUrl + _logout_endpoint, 
        _header)
    _process_task(auth_task)
    return auth_task


# If an account is created, users can login to your app with a magic link sent via email.
# NOTE: this method currently won't work unless the fragment (#) is *MANUALLY* replaced with a query (?) and the browser is reloaded
# [https://github.com/supabase/supabase/issues/1698]
func send_magic_link(email : String)  -> AuthTask:
    var payload : Dictionary = {"email":email}
    var auth_task : AuthTask = AuthTask.new(
        AuthTask.Task.MAGICLINK,
        _config.supabaseUrl + _magiclink_endpoint, 
        _header,
        payload)
    _process_task(auth_task)
    return auth_task

# Get the JSON object for the logged in user.
func user(user_access_token : String = _auth) -> AuthTask:
    var auth_task : AuthTask = AuthTask.new(
        AuthTask.Task.USER,
        _config.supabaseUrl + _user_endpoint, 
        _header + _bearer)
    _process_task(auth_task)
    return auth_task


# Update credentials of the authenticated user, together with optional metadata
func update(email : String, password : String = "", data : Dictionary = {}) -> AuthTask:
    var payload : Dictionary = {"email":email, "password":password, "data" : data}
    var auth_task : AuthTask = AuthTask.new(
        AuthTask.Task.UPDATE,
        _config.supabaseUrl + _user_endpoint, 
        _header + _bearer,
        payload)
    _process_task(auth_task)
    return auth_task


# Request a reset password mail to the specified email
func reset_password_for_email(email : String) -> AuthTask:
    var payload : Dictionary = {"email":email}
    var auth_task : AuthTask = AuthTask.new(
        AuthTask.Task.RECOVER,
        _config.supabaseUrl + _reset_password_endpoint, 
        _header,
        payload)
    _process_task(auth_task)
    return auth_task


# Invite another user by their email
func invite_user_by_email(email : String) -> AuthTask:
    var payload : Dictionary = {"email":email}
    var auth_task : AuthTask = AuthTask.new(
        AuthTask.Task.INVITE,
        _config.supabaseUrl + _invite_endpoint, 
        _header + _bearer,
        payload)
    _process_task(auth_task)
    return auth_task


# Refresh the access_token of the authenticated client using the refresh_token
# No need to call this manually except specific needs, since the process will be handled automatically
func refresh_token(refresh_token : String = client.refresh_token, expires_in : float = client.expires_in) -> AuthTask:
    yield(get_tree().create_timer(expires_in), "timeout")
    var payload : Dictionary = {refresh_token = refresh_token}
    var auth_task : AuthTask = AuthTask.new(
        AuthTask.Task.REFRESH,
        _config.supabaseUrl + _refresh_token_endpoint, 
        _header + _bearer,
        payload)
    _process_task(auth_task)
    return auth_task 



# Retrieve the response from the server
func _get_link_response(delta : float) -> void:
    yield(get_tree().create_timer(delta), "timeout")
    var peer : StreamPeer = tcp_server.take_connection()
    if peer != null:
        var raw_result : String = peer.get_utf8_string(peer.get_available_bytes())
        return raw_result
    else:
        _get_link_response(delta)

# Process a specific task
func _process_task(task : AuthTask) -> void:
    var httprequest : HTTPRequest = HTTPRequest.new()
    httprequest.use_threads = true
    add_child(httprequest)
    task.connect("completed", self, "_on_task_completed")
    task.push_request(httprequest)
    _pooled_tasks.append(task)


func _on_task_completed(task : AuthTask) -> void:
    task._handler.queue_free()
    if task.user != null:
        client = task.user
        _auth = client.access_token
        _bearer[0] = _bearer[0] % _auth
        _expires_in = client.expires_in
        match task._code:
            AuthTask.Task.SIGNUP:
                emit_signal("signed_up", client)
            AuthTask.Task.SIGNIN:
                emit_signal("signed_in", client)
            AuthTask.Task.UPDATE: 
                emit_signal("user_updated", client)
            AuthTask.Task.REFRESH:
                emit_signal("token_refreshed", client)
        refresh_token()
    elif task.data == null:
        match task._code:
            AuthTask.Task.MAGICLINK:
                emit_signal("magic_link_sent")
            AuthTask.Task.RECOVER:
                emit_signal("reset_email_sent")
            AuthTask.Task.INVITE:
                emit_signal("user_invited")
            AuthTask.Task.LOGOUT:
                emit_signal("logged_out")
                client = null
                _auth = ""
                _bearer = ["Authorization: Bearer %s"]
                _expires_in = 0
    elif task.error != null:
        emit_signal("error", task.error)
    

# A timer used to listen through TCP on the redirect uri of the request
func _tcp_stream_timer() -> void:
    var peer : StreamPeer = tcp_server.take_connection()
    # ! to be implemented
    pass
