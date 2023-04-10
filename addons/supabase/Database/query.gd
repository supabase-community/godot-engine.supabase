@tool
extends RefCounted
class_name SupabaseQuery

var query_struct : Dictionary = {
	table = "",
	select = PackedStringArray([]),
	order = PackedStringArray([]),
	Or = PackedStringArray([]),
	eq = PackedStringArray([]),
	neq = PackedStringArray([]),
	gt = PackedStringArray([]),
	gte = PackedStringArray([]),
	lt = PackedStringArray([]),
	lte = PackedStringArray([]),
	like = PackedStringArray([]),
	ilike = PackedStringArray([]),
	Is = PackedStringArray([]),
	In = PackedStringArray([]),
	fts = PackedStringArray([]),
	plfts = PackedStringArray([]),
	phfts = PackedStringArray([]),
	wfts = PackedStringArray([])
   }

var query : String = ""
var raw_query : String = ""
var header : PackedStringArray = []
var request : int
var body : String = ""


enum REQUESTS {
	NONE,
	SELECT,
	INSERT,
	UPDATE,
	DELETE
}

enum Directions {
	Ascending,
	Descending
   }

enum Nullsorder {
	First,
	Last
   }

enum Filters {
	EQUAL,
	NOT_EQUAL,
	GREATER_THAN,
	LESS_THAN,
	GREATER_THAN_OR_EQUAL,
	LESS_THAN_OR_EQUAL,
	LIKE,
	ILIKE,
	IS,
	IN,
	FTS,
	PLFTS,
	PHFTS,
	WFTS,
	OR,
	ORDER
   }

func _init(_raw_query : String = "", _raw_type : int = -1, _raw_header : PackedStringArray = PackedStringArray([]), _raw_body : String = ""):
	if _raw_query != "":
		raw_query = _raw_query
		query = _raw_query
		request = _raw_type
		header = _raw_header as PackedStringArray
		body = _raw_body

# Build the query from the scrut
func build_query() -> String:
	if raw_query == "" and query == raw_query:
		for key in query_struct:
			if query_struct[key].is_empty(): continue
			if query.length() > 0 : if not query[query.length()-1] in ["/","?"]: query+="&"
			match key:
				"table":
					query += query_struct[key]
				"select", "order":
					if query_struct[key].is_empty(): continue
					query += (key + "=" + ",".join(PackedStringArray(query_struct[key])))
				"eq", "neq", "lt", "gt", "lte", "gte", "like", "ilike", "Is", "in", "fts", "plfts", "phfts", "wfts":
					query += "&".join(PackedStringArray(query_struct[key]))
				"Or":
					query += "or=(%s)"%[",".join(query_struct[key])]
	print(query)
	return query


func from(table_name : String) -> SupabaseQuery:
	query_struct.table = table_name+"?"
	return self

# Insert new Row
func insert(fields : Array, upsert : bool = false) -> SupabaseQuery:
	request = REQUESTS.INSERT
	body = JSON.stringify(fields)
	if upsert : header += PackedStringArray(["Prefer: resolution=merge-duplicates"])
	return self

# Select Rows
func select(columns : PackedStringArray = PackedStringArray(["*"])) -> SupabaseQuery:
	request = REQUESTS.SELECT
	query_struct.select += columns
	return self

# Update Rows
func update(fields : Dictionary) -> SupabaseQuery:
	request = REQUESTS.UPDATE
	body = JSON.stringify(fields)
	return self

# Delete Rows
func delete() -> SupabaseQuery:
	request = REQUESTS.DELETE
	return self

## [MODIFIERS] -----------------------------------------------------------------

func range(from : int, to : int) -> SupabaseQuery:
	header = PackedStringArray(["Range: "+str(from)+"-"+str(to)])
	return self

func order(column : String, direction : int = Directions.Ascending, nullsorder : int = Nullsorder.First) -> SupabaseQuery:
	var direction_str : String
	match direction:
		Directions.Ascending: direction_str = "asc"
		Directions.Descending: direction_str = "desc"
	var nullsorder_str : String
	match nullsorder:
		Nullsorder.First: nullsorder_str = "nullsfirst"
		Nullsorder.Last: nullsorder_str = "nullslast"
	query_struct.order += PackedStringArray([("%s.%s.%s" % [column, direction_str, nullsorder_str])])
	return self

## [FILTERS] -------------------------------------------------------------------- 

func filter(column : String, filter : int, value : String, _props : Dictionary = {}) -> SupabaseQuery:
	var filter_str : String = match_filter(filter)
	var array : PackedStringArray = query_struct[filter_str] as PackedStringArray
	var struct_filter : String = filter_str
	if _props.has("config"):
		struct_filter+= "({config})".format(_props)
	if _props.has("negate"):
		struct_filter = ("not."+struct_filter) if _props.get("negate") else struct_filter
	# Apply custom logic or continue with default logic
	match filter_str:
		"Or":
			if _props.has("queries"):
				for query in _props.get("queries"):
					array.append(query.build_query().replace("=",".") if (not query is String) else query)
		_:
			array.append("%s=%s.%s" % [column, struct_filter.to_lower(), value])
	query_struct[filter_str] = array
	return self

func match_filter(filter : int) -> String:
	var filter_str : String
	match filter:
		Filters.EQUAL: filter_str = "eq"
		Filters.FTS: filter_str = "fts"
		Filters.ILIKE: filter_str = "ilike"
		Filters.IN: filter_str = "in"
		Filters.IS: filter_str = "Is"
		Filters.GREATER_THAN: filter_str = "gt"
		Filters.GREATER_THAN_OR_EQUAL: filter_str = "gte"
		Filters.LIKE: filter_str = "like"
		Filters.LESS_THAN: filter_str = "lt"
		Filters.LESS_THAN_OR_EQUAL: filter_str = "lte"
		Filters.NOT_EQUAL: filter_str = "neq"
		Filters.OR: filter_str = "Or"
		Filters.PLFTS: filter_str = "plfts"
		Filters.PHFTS: filter_str = "phfts"
		Filters.WFTS: filter_str = "wfts"
	return filter_str

# Finds all rows whose value on the stated columns match the specified values.
func match(query_dict : Dictionary) -> SupabaseQuery:
	for key in query_dict.keys():
		eq(key, query_dict[key])
	return self

# Finds all rows whose value on the stated column match the specified value.
func eq(column : String, value : String) -> SupabaseQuery:
	filter(column, Filters.EQUAL, value)
	return self

# Finds all rows whose value on the stated column doesn't match the specified value.
func neq(column : String, value : String) -> SupabaseQuery:
	filter(column, Filters.NOT_EQUAL, value)
	return self

# Finds all rows whose value on the stated column is greater than the specified value
func gt(column : String, value : String) -> SupabaseQuery:
	filter(column, Filters.GREATER_THAN, value)
	return self

# Finds all rows whose value on the stated column is less than the specified value
func lt(column : String, value : String) -> SupabaseQuery:
	filter(column, Filters.LESS_THAN, value)
	return self

# Finds all rows whose value on the stated column is greater than or equal to the specified value
func gte(column : String, value : String) -> SupabaseQuery:
	filter(column, Filters.GREATER_THAN_OR_EQUAL, value)
	return self

# Finds all rows whose value on the stated column is less than or equal to the specified value
func lte(column : String, value : String) -> SupabaseQuery:
	filter(column, Filters.LESS_THAN_OR_EQUAL, value)
	return self

# Finds all rows whose value in the stated column matches the supplied pattern (case sensitive).
func like(column : String, value : String) -> SupabaseQuery:
	filter(column, Filters.LIKE, "*%s*"%value)
	return self

# Finds all rows whose value in the stated column matches the supplied pattern (case insensitive).
func ilike(column : String, value : String) -> SupabaseQuery:
	filter(column, Filters.ILIKE, value)
	return self

# A check for exact equality (null, true, false), finds all rows whose value on the stated column exactly match the specified value.
func Is(column : String, value, negate : bool = false) -> SupabaseQuery:
	filter(column, Filters.IS, str(value), {negate = negate})
	return self

# Finds all rows whose value on the stated column is found on the specified values.
func In(column : String, array : PackedStringArray) -> SupabaseQuery:
	filter(column, Filters.IN, "("+",".join(array)+")")
	return self

func Or(queries : Array) -> SupabaseQuery:
	filter("", Filters.OR, "", {queries = queries})
	return self

# Text Search
func text_seach(column : String, query : String, type : String = "", config : String = "") -> SupabaseQuery:
	var filter : int
	match type:
		"plain": filter = Filters.PLFTS
		"phrase": filter = Filters.PHFTS
		"websearch": filter = Filters.WFTS
		_: filter = Filters.FTS
	query = query.replacen(" ", "%20")
	filter(column, filter, query, {config = config} if config != "" else {})
	return self

func clean() -> void:
	query = ""
	body = ""
	header = []
	request = 0
	
	query_struct.table = ""
	query_struct.select = PackedStringArray([])
	query_struct.order = PackedStringArray([])
	query_struct.eq = PackedStringArray([])
	query_struct.neq = PackedStringArray([])
	query_struct.gt = PackedStringArray([])
	query_struct.lt = PackedStringArray([])
	query_struct.gte = PackedStringArray([])
	query_struct.lte = PackedStringArray([])
	query_struct.like = PackedStringArray([])
	query_struct.ilike = PackedStringArray([])
	query_struct.IS = PackedStringArray([])
	query_struct.In = PackedStringArray([])
	query_struct.fts = PackedStringArray([])
	query_struct.plfts = PackedStringArray([])
	query_struct.phfts = PackedStringArray([])
	query_struct.wfts = PackedStringArray([])


func _to_string() -> String:
	return build_query()
