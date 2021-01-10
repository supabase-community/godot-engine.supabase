extends Reference
class_name SupabaseQuery

var query : String = ""
var header : PoolStringArray = []
var body : String = ""
var request : int

enum REQUESTS {
	NONE,
	SELECT,
	INSERT,
	UPDATE,
	DELETE
}


func _init():
	pass

func from(table_name : String) -> SupabaseQuery:
	query += table_name+"?"
	return self


# Insert new Row
func insert(fields : Array, upsert : bool = false) -> SupabaseQuery:
	request = REQUESTS.INSERT
	body = JSON.print(fields)
	if upsert : header += PoolStringArray(["Prefer: resolution=merge-duplicates"])
	return self

# Select Rows
func select(columns : PoolStringArray) -> SupabaseQuery:
	request = REQUESTS.SELECT
	query += columns.join(",")+"&"
	return self

# Update Rows
func update(fields : Dictionary) -> SupabaseQuery:
	request = REQUESTS.UPDATE
	body = JSON.print(fields)
	return self

# Delete Rows
func delete() -> SupabaseQuery:
	request = REQUESTS.DELETE
	return self

func range(from : int, to : int) -> SupabaseQuery:
	header = PoolStringArray(["Range: "+str(from)+"-"+str(to)])
	return self

func eq(column : String, value : String) -> SupabaseQuery:
	query += (column+"=eq."+value)
	return self

func gt(column : String, value : String) -> SupabaseQuery:
	query += (column+"=gt."+value)
	return self

func lt(column : String, value : String) -> SupabaseQuery:
	query += (column+"=lt."+value)
	return self

func gte(column : String, value : String) -> SupabaseQuery:
	query += (column+"=gte."+value)
	return self

func lte(column : String, value : String) -> SupabaseQuery:
	query += (column+"=lte."+value)
	return self

func like(column : String, value : String) -> SupabaseQuery:
	query += (column+"=like."+value)
	return self

func ilike(column : String, value : String) -> SupabaseQuery:
	query += (column+"=ilike."+value)
	return self

func is_(column : String, value) -> SupabaseQuery:
	query += (column+"=is."+str(value))
	return self

func in(column : String, array : PoolStringArray) -> SupabaseQuery:
	query += (column+"=in.("+array.join(",")+")")
	return self

func neq(column : String, value : String) -> SupabaseQuery:
	query += (column+"=neq."+value)
	return self

func clean() -> void:
	query = ""
	body = ""
	header = []
	request = 0
