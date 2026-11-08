# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
class Update extends RefCounted:
	const STATES := ["none", "downloading", "downloaded", "installing"]
	var _p
	var state := "none"
	func _init(platform) -> void:
		_p = platform
	func _has() -> bool:
		return "update" in _p.info.modules
	func check() -> Dictionary:
		if not _has():
			return {"available": false, "versionCode": 0, "priority": 0, "staleDays": -1, "flexible": false, "immediate": false}
		var r = await _p._call("update.check", {}, {"available": false}, _p.LONG)
		if not (r is Dictionary):
			r = {}
		var stale := Json.to_number(r.get("staleDays")) if r.has("staleDays") else NAN
		return {"available": Json.truthy(r.get("available")), "versionCode": Json.to_int32(r.get("versionCode")), "priority": Json.to_int32(r.get("priority")),
			"staleDays": Json.ints(stale) if is_finite(stale) else -1, "flexible": Json.truthy(r.get("flexible")), "immediate": Json.truthy(r.get("immediate"))}
	func start(immediate: bool = false) -> Dictionary:
		if not _has():
			return {"started": false}
		var r = await _p._call("update.start", {"immediate": immediate}, {"started": false}, _p.LONG)
		return {"started": Json.truthy(r.get("started")) if r is Dictionary else false}
	func complete() -> void:
		if state == "downloaded":
			_p._post("update.complete", {})
class Hot extends RefCounted:
	var on := false
	var active = null
	var pending = null
	var off := false
	var checking := false
	func _state() -> Dictionary:
		return {"on": false, "active": null, "pending": null, "off": false, "checking": false}
	func status() -> Dictionary:
		return _state()
	func check() -> Dictionary:
		return _state()
	func apply() -> Dictionary:
		return {"applied": false}
class Rc extends RefCounted:
	var values := {}
	func string(k: String, fallback: String = "") -> String:
		return Json.js_string(values[k]) if values.has(k) and values[k] != null else fallback
	func number(k: String, fallback: float = 0.0) -> float:
		var n := Json.to_number(values.get(k)) if values.has(k) and values[k] != null and Json.js_trim(Json.js_string(values[k])) != "" else NAN
		return n if is_finite(n) else fallback
	func boolean(k: String, fallback: bool = false) -> bool:
		if not values.has(k) or values[k] == null:
			return fallback
		var s := Json.js_string(values[k]).strip_edges().to_lower()
		if s in ["true", "1", "yes", "on"]:
			return true
		if s in ["false", "0", "no", "off", ""]:
			return false
		return fallback
class SaveMirror extends RefCounted:
	const SAVE_EVERY := 1500
	var _p
	var backup = null
	var _pending = null
	var _gen := 0
	var _waiting := false
	func _init(platform) -> void:
		_p = platform
	func mirror(json: String) -> void:
		_pending = json
		if _waiting:
			return
		_waiting = true
		var gen := _gen
		(Engine.get_main_loop() as SceneTree).create_timer(SAVE_EVERY / 1000.0, true, false, true).timeout.connect(func():
			if gen == _gen:
				flush())
	func flush() -> void:
		_gen += 1
		_waiting = false
		if _pending != null:
			var d = _pending
			_pending = null
			_p._post("save.write", {"data": d})
	func _drop() -> void:
		_gen += 1
		_waiting = false
		_pending = null
class Native extends RefCounted:
	var _p
	func _init(platform) -> void:
		_p = platform
	func request(m: String, a: Dictionary = {}, fallback = null, timeout_ms: int = 600000):
		return await _p._call(m, a, fallback, timeout_ms)
	func post(m: String, a: Dictionary = {}) -> void:
		_p._post(m, a)
class TestLoop extends RefCounted:
	var _p
	var scenario := 0
	func _init(platform, n: int) -> void:
		_p = platform
		scenario = n
	func done(report) -> Dictionary:
		var r = await _p._call("app.testloop.done", {"report": "" if report == null else Json.js_string(report)}, {"written": false}, 15000)
		return {"written": Json.truthy(r.get("written")) if r is Dictionary else false}
