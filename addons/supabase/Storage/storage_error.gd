@tool
extends BaseError
class_name SupabaseStorageError

func _init(dictionary : Dictionary = {}) -> void:
	_error = dictionary
	if not _error.is_empty():
		code = _error.get("statusCode", "empty")
		details = _error.get("error", "empty")
		message = _error.get("message", "empty")
