@tool
extends Node

# Go to Project → Project Settings
# Add these properties:
# supabase/config/supabase_url (String) - Your Supabase URL
# supabase/config/supabase_key (String) - Your Supabase anon key

# Toggle to call config manually
const LOAD_ON_READY : bool = true

# Set .env file for backup
const ENVIROMENT_PATH : String = "res://addons/supabase/.env"
const ENVIRONMENT_VARIABLES : String = "supabase/config"

var auth : SupabaseAuth 
var database : SupabaseDatabase
var realtime : SupabaseRealtime
var storage : SupabaseStorage

var debug: bool = false
var setup: bool = false

var config : Dictionary = {
	"supabaseUrl": "",
	"supabaseKey": ""
}

var header : PackedStringArray = [
	"Content-Type: application/json",
	"Accept: application/json"
]

func _ready() -> void:
	if LOAD_ON_READY:
		setup = true
		_load_config()
		_load_nodes()

func set_config(url: String, key: String) -> void:
	if setup:
		return
	setup = true
	config.supabaseUrl = url
	config.supabaseKey = key
	header.append("apikey: %s"%[config.supabaseKey])
	_load_nodes()

func set_debug(debugging: bool) -> void:
	debug = debugging

func _load_config() -> void:
	# Load all config settings from ProjectSettings
	config.supabaseUrl = ProjectSettings.get_setting("supabase/config/supabase_url", "")
	config.supabaseKey = ProjectSettings.get_setting("supabase/config/supabase_key", "")
	# Check if loaded, if not try .env file
	if config.supabaseKey != "" and config.supabaseUrl != "":
		pass
	else:    
		var env = ConfigFile.new()
		var err = env.load(ENVIROMENT_PATH)
		if err == OK:
			for key in config.keys(): 
				var value : String = env.get_value(ENVIRONMENT_VARIABLES, key, "")
				if value == "":
					printerr("%s has not a valid value." % key)
				else:
					config[key] = value
		else:
			printerr("Unable to read .env file at path '%s'" % ENVIROMENT_PATH)
	header.append("apikey: %s"%[config.supabaseKey])

func _load_nodes() -> void:
	auth = SupabaseAuth.new(config, header)
	database = SupabaseDatabase.new(config, header)
	realtime = SupabaseRealtime.new(config)
	storage = SupabaseStorage.new(config)
	add_child(auth)
	add_child(database)
	add_child(realtime)
	add_child(storage)

func _print_debug(msg: String) -> void:
	if debug: print_debug(msg)

