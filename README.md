<p align="center"><img src="addons/supabase/icon.svg" width="80px"/></p>

# Godot Engine - Supabase
A lightweight addon which integrates Supabase REST APIs for Godot Engine out of the box.  

### examples and demos
A collection of examples and live demos is available at [*fenix-hub/godot-engine.supabase-examples*](https://github.com/fenix-hub/godot-engine.supabase-examples), both with source code and exported binaries.  

### how to use
A wiki is available [*here*](https://github.com/fenix-hub/godot-engine.supabase/wiki).  
Even though it is still not complete, Classes and APIs references are always listed and updated.  

### code snippet
![code-snapshot](imgs/code-snapshot.png)

Multiple approaches!

```gdscript
func _ready() -> void:
	# Connect required signals
	Supabase.auth.connect("signed_in",self,"_on_signed_in")
	Supabase.auth.connect("error", self, "_on_error")
	Supabase.database.connect("selected", self, "_on_selected")
	Supabase.database.connect("error",self,"_on_error")

	# email/password sign in
	Supabase.auth.sign_in("user@usermail.mail","userpasswrd")

	# write a query
	var query : SupabaseQuery = SupabaseQuery.new()
	query.from('test-table').select().eq("id","1")
	
func _on_signed_in(user : SupabaseUser) -> void:
	print(user)
	Supabase.database.query(query)

func _on_selected(query_result : Array) -> void: 
	print(query_result)

func _on_error(error : Dictionary) -> void: 
	print(error)
```
  
```gdscript
func _ready() -> void:
	# email/password sign in
	var authtask : AuthTask = yield(Supabase.auth.sign_in("user@usermail.mail","userpasswrd"), "completed")
	if authtask.user != null:
		# write a query
		var dbtask : DatabaseTask = yield(SupabaseQuery.new().from('test-table').select().eq("id","1"), "completed")
		if dbtask.error == null:
			print(dbtask.data)
		else:
			print(dbtas.error)
```
