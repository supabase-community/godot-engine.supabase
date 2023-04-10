@tool
extends RefCounted
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
var dict : Dictionary = {}
var user_metadata : Dictionary = {}
var app_metadata : Dictionary = {}
var role : String
var confirmation_sent_at : String

func _init(user_dictionary : Dictionary) -> void:
	if user_dictionary.has("user"): 
		access_token = user_dictionary.get("access_token", "")
		token_type = user_dictionary.get("token_type", "")
		refresh_token = user_dictionary.get("refresh_token", "")
		expires_in = user_dictionary.get("expires_in", 0.0)
		dict = user_dictionary.get("user", {})
		last_sign_in_at = dict.get("last_sign_in_at", "") 
	else: 
		dict = user_dictionary
		confirmation_sent_at = dict.get("confirmation_sent_at", "")
	
	email = dict.get("email", "")
	id = dict.get("id", "")
	created_at = dict.get("created_at", "")
	updated_at = dict.get("updated_at", "")
	user_metadata = ({} if dict.get("user_metadata") == null else dict.get("user_metadata"))
	role = dict.get("role", "")

func _to_string():
	var to_string : String = "%-10s %s\n" % ["USER ID:", id]
	to_string += "%-10s %s\n" % ["EMAIL:", email]
	to_string += "%-10s %s\n" % ["ROLE:", role]
	return to_string
