<p align="center"><img src="addons/supabase/icon.svg" width="80px"/></p>

👉 [3.x](https://github.com/supabase-community/godot-engine.supabase/tree/main)

# Godot Engine - Supabase (4.x)
A lightweight addon which integrates Supabase APIs for Godot Engine out of the box.  

- [x] Authentication (/auth)
- [x] Database (/database)
- [x] Realtime (/realtime)
- [x] Storage (/storage)


### UI Library
A drag&drop UI Library is available at [supabase-ui](https://github.com/fenix-hub/godot-engine.supabase-ui).

### examples and demos
A collection of examples and live demos is available at [*fenix-hub/godot-engine.supabase-examples*](https://github.com/fenix-hub/godot-engine.supabase-examples), both with source code and exported binaries.  

### how to use
A wiki is available [*here*](https://github.com/fenix-hub/godot-engine.supabase/wiki).  
Even though it is still not complete, Classes and APIs references are always listed and updated.  

### code snippet
Multiple approaches!

*Asynchronous (signals)*
```gdscript
# method 1 (connecting to `Supabase.auth.signed_in` signal)
func _ready():
	Supabase.auth.signed_in.connect(_on_signed_in)
	Supabase.auth.sign_in(
		"user@supabase.email",
		"userpwd"
	)

func _on_signed_in(user: SupabaseUser) -> void:
	print(user)

# method 2 (using lambdas, connecting to the `AuthTask.completed` signal)
func _ready():
	Supabase.auth.sign_in(
		"user@supabase.email",
		"userpwd"
	).completed.connect(
		func(authTask: AuthTask) -> void:
			print(auth_task.user)
	)
```

*Synchronous (await)*
```gdscript
func _ready():
	var auth_task: AuthTask = await Supabase.auth.sign_in(
		"user@supabase.email",
		"userpwd"
	).completed
	print(auth_task.user)
```
