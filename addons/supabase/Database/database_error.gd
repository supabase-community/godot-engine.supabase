extends Reference
class_name SupabaseDatabaseError

var _error : Dictionary
var code : String = "empty"
#var id : int = -1
var message : String = "empty"
var hint : String = "empty"
var details

func _init(dictionary : Dictionary = {}) -> void:
	_error = dictionary
	if not _error.empty():
			code = _error.code if _error.has("code") else "empty"
			message = _error.message
			hint = _error.hint if _error.has("hint") and _error.hint != null else "empty"
			details = _error.get("details", "")
### always different behavior ???

func _to_string():
	return "%s >> %s: %s (%s)" % [code, message, details, hint]
