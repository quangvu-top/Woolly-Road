# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
const MODES := ["standard", "performance", "battery", "custom"]
const CONNECTIONS := ["wifi", "cellular", "ethernet", "none", "unknown"]
const THERMAL := ["none", "light", "moderate", "severe", "critical", "emergency", "shutdown"]
var _p
var game_mode := "unsupported"
var thermal := {"status": "unknown", "headroom": -1}
var exits: Array = []
var display := {"hz": 0, "modes": []}
var robot := false
var connection := "unknown"
var insets := {"top": 0, "bottom": 0, "left": 0, "right": 0}
func _init(platform) -> void:
	_p = platform
func insets_px() -> Dictionary:
	var k := float(_p.info.density)
	return {"top": insets.top * k, "bottom": insets.bottom * k, "left": insets.left * k, "right": insets.right * k}
func check_connection() -> String:
	var r = await _p._call("app.info", {}, {}, 4000)
	connection = _connection_of(r.get("connection") if r is Dictionary else null)
	return connection
func online() -> bool:
	return connection != "none"
static func _connection_of(c) -> String:
	return c if c in CONNECTIONS else "unknown"
func set_frame_rate(hz: float = 0.0) -> Dictionary:
	var r = await _p._call("app.fps", {"hz": Json.ints(hz) if hz > 0.0 else 0}, {"hz": 0}, 4000)
	var n := Json.to_number(r.get("hz") if r is Dictionary else null)
	var h = Json.ints(Json.js_round(n * 10.0) / 10.0) if n > 0.0 else 0
	if h:
		display.hz = h
	return {"hz": h}
static func _mode_of(m) -> String:
	return m if m in MODES else "unsupported"
static func _thermal_of(t) -> Dictionary:
	var status = t.get("status") if t is Dictionary else null
	var head := NAN
	if t is Dictionary and t.has("headroom"):
		head = Json.to_number(t.headroom)
	return {"status": status if status in THERMAL else "unknown", "headroom": Json.ints(head) if is_finite(head) else -1}
static func _display_of(d) -> Dictionary:
	var hz := Json.to_number(d.get("hz")) if d is Dictionary else 0.0
	var modes := []
	if d is Dictionary and d.get("modes") is Array:
		for x in d.modes:
			var n := Json.to_number(x)
			if n > 0.0:
				modes.append(Json.ints(n))
	return {"hz": Json.ints(Json.js_round(hz * 10.0) / 10.0) if hz > 0.0 else 0, "modes": modes}
func _set_insets(v) -> void:
	if not (v is Dictionary):
		return
	for k in ["top", "bottom", "left", "right"]:
		var x = v.get(k)
		if (x is int or x is float) and is_finite(float(x)):
			insets[k] = x
