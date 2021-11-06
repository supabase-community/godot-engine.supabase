extends Reference
class_name SupabaseAuthError

var _error : Dictionary
var type : String = "(undefined)"
var description : String = "(undefined)"

func _init(dictionary : Dictionary = {}) -> void:
	_error = dictionary
	if not _error.empty():
		type = _error.get("error", "(undefined)")
		description = _error.get("error_description", "(undefined)")
		if _error.has("code"):
			type = str(_error.get("code", -1))
			description = _error.get("msg", "(undefined)")
	# different body for same api source ???

func _to_string():
	return "%s >> %s" % [type, description]
