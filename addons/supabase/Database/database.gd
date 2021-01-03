extends HTTPRequest
class_name SupabaseDatabase

signal selected(query_result)
signal error(body)

const _rest_endpoint : String = "/rest/v1/"

enum REQUEST_CODES {
	NONE,
	TABLE
}

var _config : Dictionary = {}
var _header : PoolStringArray = []
var _bearer : PoolStringArray = ["Authorization: Bearer %s"]
var _request_code : int = REQUEST_CODES.NONE

func _init(conf : Dictionary, head : PoolStringArray) -> void:
	_config = conf
	_header = head
	_bearer[0] = _bearer[0] % _config.supabaseKey
	_header += _bearer
	connect("request_completed", self, "_on_request_completed")

# Issue a query on your database
func query(supabaseQuery : SupabaseQuery) -> void:
	_request_code = REQUEST_CODES.TABLE
	var endpoint : String = _config.supabaseUrl + _rest_endpoint + supabaseQuery.query
	request(endpoint, _header + supabaseQuery.header, true, HTTPClient.METHOD_GET)
	supabaseQuery.clean()

# .............. HTTPRequest completed
func _on_request_completed(result : int, response_code : int, headers : PoolStringArray, body : PoolByteArray) -> void:
	var result_body = JSON.parse(body.get_string_from_utf8()).result
	
	if response_code == 200:
		match _request_code:
			REQUEST_CODES.TABLE:
				emit_signal("selected", result_body)
	else:
		emit_signal("error", result_body)
	_request_code = REQUEST_CODES.NONE
