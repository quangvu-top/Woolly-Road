# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
var _p
var has_privacy := false
var tags: Array = []
var lost: Array = []
var _up := false
func _init(platform) -> void:
	_p = platform
func ready() -> Dictionary:
	return _p._ads.duplicate()
func simulate(fn: Callable = Callable(), opts: Dictionary = {}) -> void:
	if _p._port != null and _p._port.has_method("simulate"):
		_p._port.simulate(fn, opts)
func busy() -> bool:
	return _up
func rewarded(pl: String = "") -> Dictionary:
	if _up:
		_dup("rewarded", pl)
		return {"ok": false, "reason": "busy"}
	_up = true
	var r = await _p._call("ads.rewarded", {"pl": pl}, {"ok": false, "reason": "error"}, _p.LONG)
	_up = false
	var ok := Json.truthy(r.get("ok")) if r is Dictionary else false
	var reason = r.get("reason") if r is Dictionary else null
	return {"ok": ok, "reason": "" if ok else (Json.js_string(reason) if Json.truthy(reason) else "closed")}
func inter(pl: String = "") -> Dictionary:
	if _up:
		_dup("inter", pl)
		return {"shown": false, "busy": true}
	_up = true
	var r = await _p._call("ads.inter", {"pl": pl}, {"shown": false}, _p.LONG)
	_up = false
	return {"shown": Json.truthy(r.get("shown")) if r is Dictionary else false}
func _dup(kind: String, pl: String) -> void:
	_p.an.log("ad_dup", {"pl": pl, "kind": kind})
func load(kind: String = "") -> void:
	_p._post("ads.load", {"kind": kind} if kind == "rv" or kind == "inter" else {})
func units(which: Variant = []) -> void:
	var t: Array = []
	if which is String and which == "*":
		t = ["*"]
	elif which is Array:
		t = which.map(func(x): return Json.js_string(x))
	_p._post("ads.units", {"tags": t})
func set_segments(segs: Variant) -> void:
	var out := {}
	if segs is Dictionary:
		for k in segs:
			var ks := Json.js_trim(Json.js_string(k))
			if not ks.is_valid_int() or ks.begins_with("-") or ks.begins_with("+"):
				continue
			var v = segs[k]
			var vals := []
			for x in (v if v is Array else [v]):
				var n := Json.to_number(x)
				if is_finite(n) and n == floorf(n) and n >= 0.0:
					vals.append(int(n))
			if not vals.is_empty():
				out[str(int(ks))] = vals
	_p._post("ads.segments", {"segments": out})
func privacy():
	return await _p._call("ads.privacy", {}, null, _p.LONG)
func mediation_debugger() -> Dictionary:
	var r = await _p._call("ads.debugger", {}, {"shown": false}, 4000)
	return {"shown": Json.truthy(r.get("shown")) if r is Dictionary else false}
func lost_done() -> void:
	if lost.is_empty():
		return
	lost = []
	_p._post("ads.lostDone", {})
