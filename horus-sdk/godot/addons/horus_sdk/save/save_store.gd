# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
class_name HorusSaveStore
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
const Seal := preload("res://addons/horus_sdk/save/seal.gd")
const Merge := preload("res://addons/horus_sdk/save/merge.gd")
const SEAL := "_seal"
class FileStorage extends RefCounted:
	var dir: String
	func _init(folder := "user://") -> void:
		dir = folder
	func path_of(k: String) -> String:
		var safe := ""
		for ch in k:
			safe += ch if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch in "._-" else "_"
		return dir.path_join(safe + ".json")
	func get_item(k: String):
		var p := path_of(k)
		if not FileAccess.file_exists(p):
			return null
		var f := FileAccess.open(p, FileAccess.READ)
		return f.get_as_text() if f else null
	func set_item(k: String, v: String) -> bool:
		var p := path_of(k)
		if not DirAccess.dir_exists_absolute(dir) and DirAccess.make_dir_recursive_absolute(dir) != OK:
			return false
		var tmp := p + ".tmp"
		var f := FileAccess.open(tmp, FileAccess.WRITE)
		if f == null:
			return false
		f.store_string(v)
		f.close()
		return DirAccess.rename_absolute(tmp, p) == OK
	func remove_item(k: String) -> void:
		var p := path_of(k)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
class MemoryStorage extends RefCounted:
	var items := {}
	func _init(init := {}) -> void:
		items = init.duplicate()
	func get_item(k: String):
		return items.get(k)
	func set_item(k: String, v: String) -> bool:
		items[k] = v
		return true
	func remove_item(k: String) -> void:
		items.erase(k)
var key := ""
var persist_on := true
var mirror := Callable()
var storage
var _defaults := Callable()
var _version = 1
var _economy = null
var _parts := {}
var _before := Callable()
var _after := Callable()
var _skip := {}
var _delay := 400
var _seal = null
var _marker := ""
var _seal_broken := false
var _mem = null
var _gen := 0
var _waiting := false
var _ok := false
var current:
	get:
		return _mem
var seal_broken: bool:
	get:
		return _seal_broken
func _init(o: Dictionary = {}) -> void:
	key = str(o.get("key", ""))
	_defaults = o.get("defaults") if o.get("defaults") is Callable else Callable()
	_ok = key != "" and _defaults.is_valid()
	if not _ok:
		push_error("HorusSaveStore: key and defaults (a Callable) are required")
		_defaults = func(): return {}
	_version = o.get("version", 1)
	_economy = o.get("economy") if o.get("economy") is Dictionary else null
	_parts = o.get("parts", {}) if o.get("parts") is Dictionary else {}
	_before = o.get("before") if o.get("before") is Callable else Callable()
	_after = o.get("after") if o.get("after") is Callable else Callable()
	for k in o.get("omit", []):
		_skip[str(k)] = true
	_delay = int(o.get("delay", 400))
	storage = o.get("storage") if o.has("storage") else FileStorage.new(str(o.get("dir", "user://")))
	mirror = o.get("mirror") if o.get("mirror") is Callable else Callable()
	var seal = o.get("seal")
	if seal is Dictionary and Json.truthy(seal.get("key")):
		_seal = seal
		_skip[SEAL] = true
	_marker = key + ".sealed"
func is_valid() -> bool:
	return _ok
func _get_raw(k: String):
	if storage == null:
		return null
	var v = storage.get_item(k)
	return v if v is String else null
func _set_raw(k: String, json: String) -> bool:
	return storage != null and storage.set_item(k, json) == true
func stringify(s: Variant) -> String:
	var plain := Json.stringify(s, _skip)
	return Seal.add_seal(plain, str(_seal.key)) if _seal else plain
func parse(raw: Variant):
	var s = Json.parse(raw) if raw is String else null
	return s if s is Dictionary and Json.same(s.get("v"), _version) else null
func _fresh() -> Dictionary:
	var d = _defaults.call()
	if not (d is Dictionary):
		d = {}
	d["v"] = _version
	if _economy:
		d[str(_economy.get("field", "econ"))] = _economy.get("version")
	for f in _parts:
		d[f] = (_parts[f].get("versions", []) as Array).duplicate()
	return d
func load() -> Dictionary:
	var d := _fresh()
	_seal_broken = false
	var raw = _get_raw(key)
	var s = parse(raw)
	if s != null and _seal:
		var state := Seal.check_seal(raw, str(_seal.key))
		if state == "none":
			state = "missing" if Json.truthy(_get_raw(_marker)) else "none"
		if state == "broken" or state == "missing":
			_seal_broken = true
			var cb = _seal.get("on_broken")
			if cb is Callable and cb.is_valid():
				cb.call_deferred({"state": state, "save": d})
	if s != null:
		if _before.is_valid():
			_before.call(s)
		fill(d, s)
		d.erase(SEAL)
		if _after.is_valid():
			_after.call(d, s)
		if _economy:
			var f := str(_economy.get("field", "econ"))
			if not Json.same(s.get(f), _economy.get("version")):
				(_economy.reset as Callable).call(d, _fresh())
				d[f] = _economy.get("version")
				d["econReset"] = 1
		for f in _parts:
			var p: Dictionary = _parts[f]
			var versions: Array = p.get("versions", [])
			var was: Array = s.get(f) if s.get(f) is Array else []
			for i in versions.size():
				var w = was[i] if i < was.size() else null
				if not Json.same(w if Json.truthy(w) else 1, versions[i]):
					(p.reset as Callable).call(d, i)
			d[f] = versions.duplicate()
	_mem = d
	return d
func save(s: Variant = null) -> bool:
	if s == null:
		s = _mem
	if s == null or not persist_on:
		return false
	var json := stringify(s)
	var ok := _set_raw(key, json)
	if ok and _seal:
		_set_raw(_marker, "1")
	if mirror.is_valid():
		mirror.call(json)
	return ok
func queue(s: Variant) -> void:
	_mem = s
	_gen += 1
	_waiting = true
	var gen := _gen
	(Engine.get_main_loop() as SceneTree).create_timer(_delay / 1000.0, true, false, true).timeout.connect(func():
		if gen == _gen and _waiting:
			_waiting = false
			save(s))
func flush() -> bool:
	if not _waiting:
		return false
	_gen += 1
	_waiting = false
	save(_mem)
	return true
func wipe() -> Dictionary:
	_gen += 1
	_waiting = false
	if storage != null:
		storage.remove_item(key)
	_mem = _fresh()
	return _mem
func restore_backup(raw: Variant) -> bool:
	if not Json.truthy(raw) or Json.truthy(_get_raw(key)) or parse(raw) == null:
		return false
	return _set_raw(key, raw)
func read_raw():
	return _get_raw(key)
func write_raw(json: String) -> bool:
	return _set_raw(key, json)
static func fill(defaults: Dictionary, saved: Variant) -> Dictionary:
	if not (saved is Dictionary):
		return defaults
	for k in saved:
		var v = saved[k]
		if not defaults.has(k):
			defaults[k] = v
			continue
		var d = defaults[k]
		match typeof(d):
			TYPE_DICTIONARY:
				if v is Dictionary:
					fill(d, v)
			TYPE_ARRAY:
				if v is Array:
					defaults[k] = v
			TYPE_INT, TYPE_FLOAT:
				if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v)):
					defaults[k] = v
			TYPE_BOOL:
				if v is bool:
					defaults[k] = v
			TYPE_STRING, TYPE_STRING_NAME:
				if v is String:
					defaults[k] = v
			_:
				defaults[k] = v
	return defaults
static func fit_array(a: Variant, n: int, pad: Variant) -> Array:
	var out: Array = a.slice(0, n) if a is Array else []
	while out.size() < n:
		out.append(pad.call(out.size()) if pad is Callable else pad)
	return out
static func further(...fields: Array) -> Callable:
	return Merge.further.callv(fields)
static func merge_purchases(into: Variant, from: Variant, o: Dictionary):
	return Merge.merge_purchases(into, from, o)
static func conflict_rules(store: Variant, o: Dictionary):
	return Merge.conflict_rules(store, o)
static func seal_of(json: String, seal_key: String) -> String:
	return Seal.seal_of(json, seal_key)
static func add_seal(json: String, seal_key: String) -> String:
	return Seal.add_seal(json, seal_key)
static func check_seal(raw: Variant, seal_key: String) -> String:
	return Seal.check_seal(raw, seal_key)
