extends Reference
class_name SupabaseError

var _error : Dictionary
var type : String 
var description : String

func _init(dictionary : Dictionary = {}) -> void:
	_error = dictionary
	if not _error.empty():
		if _error.has("error"):
			type = "[%s]" % _error.error
			description = _error.error_description
		if _error.has("code"):
			type = "[%s]" % _error.code
			description = _error.message
	else:
		type = "(empty)"
		description = "(empty)"

