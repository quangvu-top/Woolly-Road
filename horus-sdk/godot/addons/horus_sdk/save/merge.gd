# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
static func path_get(o: Variant, path: String):
	var a = o
	for k in path.split("."):
		if a is Dictionary:
			a = a.get(k)
		elif a is Array and k.is_valid_int() and int(k) >= 0 and int(k) < a.size():
			a = a[int(k)]
		else:
			return null
	return a
static func further(...fields: Array) -> Callable:
	var get_ := fields.map(func(f): return f if f is Callable else func(s): return path_get(s, str(f)))
	return func(a, b) -> bool:
		for g in get_:
			var x := Json.num0(g.call(a))
			var y := Json.num0(g.call(b))
			if x != y:
				return x > y
		return false
static func merge_purchases(into: Variant, from: Variant, o: Dictionary):
	if not Json.truthy(into) or not Json.truthy(from) or not (into is Dictionary):
		return 0
	var list: String = o.get("list", "buys")
	var token: String = o.get("token", "token")
	var time: String = o.get("time", "t")
	var keep: int = int(o.get("keep", 30))
	var flags: Array = o.get("flags", [])
	var credit: Callable = o.get("credit")
	if not (into.get(list) is Array):
		into[list] = []
	var mine: Array = into[list]
	var have := {}
	for b in mine:
		if b is Dictionary and Json.truthy(b.get(token)):
			have[b[token]] = true
	var floor_ := -INF
	if keep > 0 and mine.size() >= keep:
		floor_ = INF
		for b in mine:
			floor_ = minf(floor_, Json.num0(b.get(time) if b is Dictionary else null))
	var added := 0.0
	var theirs = from.get(list) if from is Dictionary else null
	for b in (theirs if theirs is Array else []):
		if not Json.truthy(b) or not (b is Dictionary) or not Json.truthy(b.get(token)) or have.has(b[token]) or Json.num0(b.get(time)) <= floor_:
			continue
		var got = credit.call(into, b)
		if got == null or (got is bool and got == false):
			continue
		added += Json.num0(got)
		mine.append(b.duplicate())
		have[b[token]] = true
	if from is Dictionary:
		for f in flags:
			if from.get(f) is bool and from[f] == true:
				into[f] = true
	_stable_sort(mine, time)
	return Json.ints(added)
static func _stable_sort(a: Array, time: String) -> void:
	var keyed := []
	for i in a.size():
		var b = a[i]
		keyed.append([Json.num0(b.get(time) if b is Dictionary else null), i, b])
	keyed.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	for i in keyed.size():
		a[i] = keyed[i][2]
static func conflict_rules(store: Variant, o: Dictionary) -> Rules:
	return Rules.new(store, o)
class Rules extends RefCounted:
	var _store
	var _o: Dictionary
	func _init(store, o: Dictionary) -> void:
		_store = store
		_o = o
	func read():
		return _store.read_raw()
	func parse(raw):
		return _store.parse(raw)
	func further(a, b) -> bool:
		return Json.truthy(_o.further.call(a, b))
	func merge(into, from):
		return _o.merge.call(into, from) if Json.truthy(into) and Json.truthy(from) else 0
	func adopt(s) -> void:
		var json: String = _store.stringify(s)
		_store.write_raw(json)
		if _o.get("mirror") is Callable and _o.mirror.is_valid():
			_o.mirror.call(json)
		if _o.get("flush") is Callable and _o.flush.is_valid():
			_o.flush.call()
