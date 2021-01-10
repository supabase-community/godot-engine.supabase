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
var app_metadata : Dictionary
var role : String
var confirmation_sent_at : String

func _init(user_dictionary : Dictionary) -> void:
	if user_dictionary.has("user"): 
		access_token = user_dictionary.access_token
		token_type = user_dictionary.token_type
		refresh_token = user_dictionary.refresh_token
		expires_in = user_dictionary.expires_in
		user = user_dictionary.user
		last_sign_in_at = user.last_sign_in_at 
	else: 
		user = user_dictionary
		confirmation_sent_at = user.confirmation_sent_at
	
	email = user.email
	id = user.id
	created_at = user.created_at
	updated_at = user.updated_at
	user_metadata = user.user_metadata if user.user_metadata != null else {}
	role = user.role

func _to_string():
	var to_string : String = "%-10s %s\n" % ["USER ID:", id]
	to_string += "%-10s %s\n" % ["EMAIL:", email]
	to_string += "%-10s %s\n" % ["ROLE:", role]
	return to_string
