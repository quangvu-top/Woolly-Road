# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
var _p
var available := false
var signed_in := false
var social := false
var play = null
var stats := false
var recall := false
func _init(platform) -> void:
	_p = platform
func submit(board: String, score: Variant) -> void:
	var n := floorf(Json.to_number(score))
	if signed_in and is_finite(n) and n >= 0.0:
		_p._post("games.score", {"board": board, "score": int(n)})
func unlock(id: String) -> void:
	if signed_in:
		_p._post("games.unlock", {"id": id})
func show(what: String = "leaderboards", board: String = "") -> Dictionary:
	var on := signed_in
	if not on:
		on = await sign_in()
	if not on:
		return {"shown": false}
	var r = await _p._call("games.show", {"what": "achievements" if what == "achievements" else "leaderboards", "board": board}, {"shown": false}, _p.LONG)
	return {"shown": Json.truthy(r.get("shown")) if r is Dictionary else false}
func sign_in() -> bool:
	if not available:
		return false
	var r = await _p._call("games.signin", {}, {"signedIn": false}, _p.LONG)
	signed_in = Json.truthy(r.get("signedIn")) if r is Dictionary else false
	return signed_in
func access(on: bool) -> void:
	if signed_in:
		_p._post("games.access", {"on": on})
func challenge(id: String = "") -> Dictionary:
	if not (social and signed_in):
		return {"shown": false}
	var r = await _p._call("games.challenge", {"id": id}, {"shown": false}, _p.LONG)
	return {"shown": Json.truthy(r.get("shown")) if r is Dictionary else false}
func activity(id: String, on: bool) -> void:
	if social and signed_in:
		_p._post("games.activity", {"id": id, "on": on})
func take_play():
	var p = play
	play = null
	if p != null:
		_p._post("games.takeplay", {})
	return p
func stat(name: String, props: Dictionary = {}) -> void:
	if not stats or not signed_in or name == "":
		return
	var o := {}
	for k in props:
		var v = props[k]
		if v is bool or v is String or v is int or (v is float and is_finite(v)):
			o[k] = v
	_p._post("games.stat", {"name": name, "props": o})
func recall_session() -> String:
	if not (recall and signed_in):
		return ""
	var r = await _p._call("games.recall", {}, {"sessionId": ""}, 20000)
	return r.sessionId if r is Dictionary and r.get("sessionId") is String else ""
static func _play_of(o):
	if not (o is Dictionary) or not Json.truthy(o.get("activity")):
		return null
	var props := {}
	if o.get("properties") is Dictionary:
		for k in o.properties:
			props[k] = Json.js_string(o.properties[k])
	return {"activity": Json.js_string(o.activity), "properties": props}
