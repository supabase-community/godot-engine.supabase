@tool
extends BaseError
class_name SupabaseDatabaseError

func _init(dictionary : Dictionary = {}) -> void:
	_error = dictionary
	if not _error.is_empty():
		code = _error.code if _error.has("code") else "empty"
		message = _error.message if _error.has("message") else "empty"
		hint = _error.hint if _error.has("hint") and _error.hint != null else "empty"
		details = _error.get("details", "")
### always different behavior ???

