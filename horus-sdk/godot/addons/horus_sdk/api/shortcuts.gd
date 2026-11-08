# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
var _p
var _sent = null
var supported := false
var opened = null
func _init(platform) -> void:
	_p = platform
func set_list(list: Variant) -> void:
	var l := clean(list)
	var json := Json.stringify(l)
	if json == _sent:
		return
	_sent = json
	_p._post("app.shortcuts", {"list": l})
static func clean(list: Variant) -> Array:
	var out := []
	for s in (list if list is Array else []):
		if out.size() >= 4:
			break
		if not (s is Dictionary):
			continue
		var id := Json.js_trim(Json.str_or_empty(s.get("id")))
		var title := Json.js_trim(Json.str_or_empty(s.get("title")))
		if id == "" or title == "":
			continue
		out.append({"id": id, "title": title, "subtitle": Json.js_trim(Json.str_or_empty(s.get("subtitle"))), "icon": Json.js_trim(Json.str_or_empty(s.get("icon")))})
	return out
static func _open_of(o):
	if not (o is Dictionary) or not Json.truthy(o.get("id")):
		return null
	return {"id": Json.js_string(o.id), "openedAt": Json.ints(Json.num0(o.get("openedAt")))}
