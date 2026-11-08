# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
var kind := "android"
var handles_back := true
var _s: Object
static func is_bridge(o) -> bool:
	if not (o is Object) or not is_instance_valid(o):
		return false
	if not (o.has_signal("done") and o.has_signal("event")):
		return false
	return o.get_class() == "JNISingleton" or o.has_method("post")
func _init(singleton: Object, host) -> void:
	_s = singleton
	_s.connect("done", host._native_done)
	_s.connect("event", host._native_event)
	if OS.get_name() == "iOS" or ("ios" in singleton and Json.truthy(singleton.get("ios"))):
		kind = "ios"
	if singleton.has_method("_attached"):
		singleton._attached(host)
func post(json: String) -> bool:
	if _s == null:
		return false
	_s.call("post", json)
	return true
