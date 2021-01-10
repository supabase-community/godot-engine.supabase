extends HTTPRequest
class_name SupabaseDatabase

signal selected(query_result)
signal inserted()
signal updated()
signal deleted()
signal error(body)

const _rest_endpoint : String = "/rest/v1/"

var _config : Dictionary = {}
var _header : PoolStringArray = []
var _bearer : PoolStringArray = ["Authorization: Bearer %s"]
var _request_code : int

var _requests_queue : Array = []

func _init(conf : Dictionary, head : PoolStringArray) -> void:
	_config = conf
	_header = head
	connect("request_completed", self, "_on_request_completed")

# Issue a query on your database
func query(supabase_query : SupabaseQuery) -> void:
	if _request_code != SupabaseQuery.REQUESTS.NONE : 
		_requests_queue.append(supabase_query)
		return
	_bearer = Supabase.auth._bearer
	_request_code = supabase_query.request
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + supabase_query.query
	var method : int
	match supabase_query.request:
		SupabaseQuery.REQUESTS.INSERT: method = HTTPClient.METHOD_POST
		SupabaseQuery.REQUESTS.SELECT: method = HTTPClient.METHOD_GET
		SupabaseQuery.REQUESTS.UPDATE: method = HTTPClient.METHOD_PATCH
		SupabaseQuery.REQUESTS.DELETE: method = HTTPClient.METHOD_DELETE
	request(endpoint, _header + _bearer + supabase_query.header, true, method, supabase_query.body)
	supabase_query.clean()

# .............. HTTPRequest completed
func _on_request_completed(result : int, response_code : int, headers : PoolStringArray, body : PoolByteArray) -> void:
	var result_body = JSON.parse(body.get_string_from_utf8()).result if body.get_string_from_utf8() else {}
	if response_code in [200, 201, 204]:
		match _request_code:
			SupabaseQuery.REQUESTS.SELECT: emit_signal("selected", result_body)
			SupabaseQuery.REQUESTS.INSERT: emit_signal("inserted")
			SupabaseQuery.REQUESTS.UPDATE: emit_signal("updated")
			SupabaseQuery.REQUESTS.DELETE: emit_signal("deleted")
	else:
		if result_body == null : result_body = {}
		var supabase_error : SupabaseDatabaseError = SupabaseDatabaseError.new(result_body)
		emit_signal("error", supabase_error)
	_request_code = SupabaseQuery.REQUESTS.NONE
	check_queue()

func check_queue() -> void:
	if _requests_queue.size() > 0 :
		var request : SupabaseQuery = _requests_queue.pop_front()
		query(request)
