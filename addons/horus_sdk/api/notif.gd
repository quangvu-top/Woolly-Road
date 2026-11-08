# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
var _p
var opened = null
func _init(platform) -> void:
	_p = platform
func ask() -> bool:
	var r = await _p._call("notif.ask", {}, {"granted": false}, _p.LONG)
	return Json.truthy(r.get("granted")) if r is Dictionary else false
func schedule(list: Array) -> void:
	_p._post("notif.schedule", {"list": list})
func cancel_all() -> void:
	_p._post("notif.cancel", {})
func state() -> Dictionary:
	var r = await _p._call("notif.state", {}, null, 4000)
	if not (r is Dictionary) or (r.get("supported") is bool and r.supported == false):
		return {"supported": false, "enabled": false, "channels": {}, "canAsk": false}
	var channels := {}
	if r.get("channels") is Dictionary:
		for k in r.channels:
			channels[k] = Json.truthy(r.channels[k])
	return {"supported": true, "enabled": Json.truthy(r.get("enabled")), "channels": channels, "canAsk": Json.truthy(r.get("canAsk"))}
func settings() -> void:
	_p._post("notif.settings", {})
static func _open_of(o):
	if not (o is Dictionary) or not Json.truthy(o.get("kind")):
		return null
	return {"kind": Json.js_string(o.kind), "screen": Json.str_or_empty(o.get("screen")), "at": Json.ints(Json.num0(o.get("at"))),
		"shownAt": Json.ints(Json.num0(o.get("shownAt"))), "openedAt": Json.ints(Json.num0(o.get("openedAt")))}
