extends Reference
class_name SupabaseDatabaseError

var _error : Dictionary
var code : String = "empty"
#var id : int = -1
var message : String = "empty"
var hint : String = "empty"
var details : String = "empty"

func _init(dictionary : Dictionary = {}) -> void:
	_error = dictionary
	if not _error.empty():
			code = _error.code if _error.has("code") else "empty"
			message = _error.message
#				id = _error.error_id
			hint = _error.hint if _error.has("hint") and _error.hint != null else "empty"
			details = _error.details if _error.has("details") and _error.details != null else "empty"
### always different behavior ???

func _to_string():
	return "%s >> %s: %s (%s)" % [code, message, details, hint]
