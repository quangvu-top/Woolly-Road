# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const MAX_SAFE := 9007199254740992.0
const Num := preload("res://addons/horus_sdk/core/num.gd")
static var _needs_escape := RegEx.create_from_string("[\\x00-\\x1f\"\\\\]")
static var _decimal := RegEx.create_from_string("^[+-]?(Infinity|(\\d+\\.?\\d*|\\.\\d+)([eE][+-]?\\d+)?)$")
static var _tokens := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"|-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?")
static var _hex := RegEx.create_from_string("^0[xX][0-9a-fA-F]+$")
static var _oct := RegEx.create_from_string("^0[oO][0-7]+$")
static var _bin := RegEx.create_from_string("^0[bB][01]+$")
const _JS_SPACE := [9, 10, 11, 12, 13, 32, 160, 5760, 8192, 8193, 8194, 8195, 8196, 8197, 8198, 8199, 8200, 8201, 8202, 8232, 8233, 8239, 8287, 12288, 65279]
static func stringify(v, skip: Dictionary = {}) -> String:
	var out := _value(v, skip)
	return "null" if out == "" else out
static func _value(v, skip: Dictionary) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return "null" if is_nan(v) or is_inf(v) else num_text(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return quote(str(v))
		TYPE_DICTIONARY:
			var parts := PackedStringArray()
			for k in _js_key_order(v):
				var key := js_string(k)
				if skip.has(key):
					continue
				var t := _value(v[k], skip)
				if t != "":
					parts.append(quote(key) + ":" + t)
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var items := PackedStringArray()
			var i := 0
			for x in v:
				var t := "" if skip.has(str(i)) else _value(x, skip)
				items.append("null" if t == "" else t)
				i += 1
			return "[" + ",".join(items) + "]"
	if OS.is_debug_build():
		push_warning("Horus JSON: a %s is not a JSON value, left out" % type_string(typeof(v)))
	return ""
static func _js_key_order(d: Dictionary) -> Array:
	var index := []
	var other := []
	for k in d:
		var s := js_string(k)
		if _is_index(s):
			index.append(k)
		else:
			other.append(k)
	if index.is_empty():
		return other
	index.sort_custom(func(a, b): return js_string(a).to_int() < js_string(b).to_int())
	return index + other
static func _is_index(s: String) -> bool:
	if s == "" or s.length() > 10 or (s.length() > 1 and s[0] == "0"):
		return false
	for ch in s:
		if ch < "0" or ch > "9":
			return false
	return s.to_int() < 4294967295
static func quote(s: String) -> String:
	if _needs_escape.search(s) == null:
		return "\"" + s + "\""
	var out := PackedStringArray()
	for ch in s:
		var c := ch.unicode_at(0)
		if c == 34:
			out.append("\\\"")
		elif c == 92:
			out.append("\\\\")
		elif c >= 32:
			out.append(ch)
		elif c == 8:
			out.append("\\b")
		elif c == 9:
			out.append("\\t")
		elif c == 10:
			out.append("\\n")
		elif c == 12:
			out.append("\\f")
		elif c == 13:
			out.append("\\r")
		else:
			out.append("\\u%04x" % c)
	return "\"" + "".join(out) + "\""
static func num_text(f: float) -> String:
	return Num.text(f)
static func parse(text, fallback = null):
	if not (text is String):
		return fallback
	var j := JSON.new()
	if j.parse(text) != OK:
		return fallback
	var v = j.data
	if _has_number(v):
		var nums := PackedStringArray()
		for m in _tokens.search_all(text):
			var t := m.get_string()
			if t[0] != "\"":
				nums.append(t)
		if _count_numbers(v) == nums.size():
			return _exact(v, nums, [0])
	return ints(v)
static func _has_number(v) -> bool:
	return v is float or v is Dictionary or v is Array
static func _count_numbers(v) -> int:
	if v is float or v is int:
		return 1
	var n := 0
	if v is Dictionary:
		for k in v:
			n += _count_numbers(v[k])
	elif v is Array:
		for x in v:
			n += _count_numbers(x)
	return n
static func _exact(v, nums: PackedStringArray, at: Array):
	if v is float or v is int:
		at[0] += 1
		return _number_of(nums[at[0] - 1])
	if v is Dictionary:
		for k in v:
			v[k] = _exact(v[k], nums, at)
	elif v is Array:
		for i in v.size():
			v[i] = _exact(v[i], nums, at)
	return v
static func _number_of(t: String):
	if t.length() <= 16 and not (t.contains(".") or t.contains("e") or t.contains("E")) and t.lstrip("-").length() <= 15:
		return t.to_int()
	var f := Num.read(t)
	return int(f) if f == floorf(f) and absf(f) <= MAX_SAFE else f
static func ints(v):
	match typeof(v):
		TYPE_FLOAT:
			if v == floorf(v) and absf(v) <= MAX_SAFE:
				return int(v)
		TYPE_DICTIONARY:
			for k in v:
				v[k] = ints(v[k])
		TYPE_ARRAY:
			for i in v.size():
				v[i] = ints(v[i])
	return v
static func truthy(v) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT:
			return v != 0
		TYPE_FLOAT:
			return v != 0.0 and not is_nan(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v) != ""
	return true
static func to_number(v) -> float:
	match typeof(v):
		TYPE_NIL:
			return 0.0
		TYPE_BOOL:
			return 1.0 if v else 0.0
		TYPE_INT, TYPE_FLOAT:
			return float(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return _str_number(str(v))
		TYPE_ARRAY:
			return _str_number(js_string(v))
	return NAN
static func _str_number(s: String) -> float:
	s = js_trim(s)
	if s == "":
		return 0.0
	if _decimal.search(s) != null:
		if s.ends_with("Infinity"):
			return -INF if s.begins_with("-") else INF
		return Num.read(s)
	var base := 0
	if _hex.search(s) != null:
		base = 16
	elif _oct.search(s) != null:
		base = 8
	elif _bin.search(s) != null:
		base = 2
	if base == 0:
		return NAN
	var n := 0.0
	for ch in s.substr(2).to_lower():
		n = n * base + "0123456789abcdef".find(ch)
	return n
static func js_trim(s: String) -> String:
	var a := 0
	var b := s.length()
	while a < b and _JS_SPACE.has(s.unicode_at(a)):
		a += 1
	while b > a and _JS_SPACE.has(s.unicode_at(b - 1)):
		b -= 1
	return s.substr(a, b - a)
static func js_string(v) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			if is_nan(v):
				return "NaN"
			if is_inf(v):
				return "Infinity" if v > 0 else "-Infinity"
			return num_text(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v)
		TYPE_ARRAY:
			var parts := PackedStringArray()
			for x in v:
				parts.append("" if x == null else js_string(x))
			return ",".join(parts)
		TYPE_DICTIONARY:
			return "[object Object]"
	return str(v)
static func str_or_empty(v) -> String:
	return js_string(v) if truthy(v) else ""
static func to_int32(v) -> int:
	var n := to_number(v)
	if is_nan(n) or is_inf(n):
		return 0
	var m := fmod(n - fmod(n, 1.0), 4294967296.0)
	if m < 0.0:
		m += 4294967296.0
	if m >= 2147483648.0:
		m -= 4294967296.0
	return int(m)
static func js_round(x: float) -> float:
	if not is_finite(x):
		return x
	var r := floorf(x)
	return r + 1.0 if x - r >= 0.5 else r
static func same(a, b) -> bool:
	var na := typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var nb := typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if na or nb:
		return na and nb and float(a) == float(b)
	if typeof(a) != typeof(b):
		return false
	return a == b
static func num0(v) -> float:
	var n := to_number(v)
	return n if is_finite(n) else 0.0
