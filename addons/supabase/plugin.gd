@tool
extends EditorPlugin


func _enter_tree():
	add_autoload_singleton("Supabase", "res://addons/supabase/Supabase/supabase.gd")

func _exit_tree():
	remove_autoload_singleton("Supabase")
