extends Reference
class_name SupabaseAuthError

var _error : Dictionary
var type : String = "(empty)"
var description : String = "(empty)"

func _init(dictionary : Dictionary = {}) -> void:
	_error = dictionary
	if not _error.empty():
		if _error.has("error"):
			type = _error.error 
			description = _error.error_description
		if _error.has("code"):
			type = str(_error.code)
			description = _error.msg
	# different body for same api source ???

func _to_string():
	return "%s >> %s" % [type, description]
