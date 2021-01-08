extends Reference
class_name SupabaseUser

var email : String
var id : String
var access_token : String
var token_type : String
var refresh_token : String
var expires_in : float
var created_at : String
var updated_at : String
var last_sign_in_at : String
var user : Dictionary
var user_metadata : Dictionary
var role : String

func _init(user_dictionary : Dictionary) -> void:
	email = user_dictionary.user.email
	id = user_dictionary.user.id
	access_token = user_dictionary.access_token
	token_type = user_dictionary.token_type
	refresh_token = user_dictionary.refresh_token
	expires_in = user_dictionary.expires_in
	user = user_dictionary.user
	created_at = user_dictionary.user.created_at
	updated_at = user_dictionary.user.updated_at
	last_sign_in_at = user_dictionary.user.last_sign_in_at 
	user_metadata = user_dictionary.user.user_metadata if user_dictionary.user.user_metadata != null else {}
	role = user_dictionary.user.role

func _to_string():
	var to_string : String = "\n%-10s %s\n" % ["USER UID:", id]
	to_string += "%-10s %s\n" % ["EMAIL:", email]
	to_string += "%-10s %s\n" % ["CREATED:", created_at]
	to_string += "%-10s %s\n" % ["SIGNED IN:", last_sign_in_at]
	return to_string
