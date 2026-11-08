# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
const Rules := preload("res://addons/horus_sdk/cloud/rules.gd")
const BOOT_WAIT := 3000
var _p
var _on := false
var _recalled := false
var enabled := false
var boot := {"state": "off", "syncedAt": 0}
func _init(platform) -> void:
	_p = platform
static func _off() -> Dictionary:
	return {"state": "off", "syncedAt": 0}
func status() -> Dictionary:
	if not enabled:
		return _off()
	return Rules.cloud_state(await _p._call("cloud.status", {}, {"state": "offline"}, 4000))
func use_cloud():
	_p.save._drop()
	var r = await _p._call("cloud.resolve", {"use": "cloud"}, {"data": null}, 8000)
	var data = r.get("data") if r is Dictionary else null
	return data if data is String and data != "" else null
func keep_local() -> void:
	_p.save.flush()
	await _p._call("cloud.resolve", {"use": "local"}, {}, 8000)
func sync() -> void:
	if not enabled:
		return
	_p.save.flush()
	_p._post("cloud.sync", {})
func _start(info: Dictionary, wait_ms):
	enabled = _on and Json.truthy(info.get("cloud"))
	if not enabled:
		return null
	var w := clampi(int(Json.num0(wait_ms)), 0, 10000)
	_recall.call_deferred()
	return _p._request("cloud.boot", {"wait": w}, {"state": "offline"}, w + 3000)
func _booted(r):
	boot = Rules.cloud_state(r)
	return boot.data if boot.state == "restore" and Json.truthy(boot.get("data")) else null
func _map_event(ev: String, d):
	return Rules.cloud_state(d) if _on and ev == "cloud" else d
func _after(ev: String, d, from: String) -> void:
	if not _on:
		return
	if ev == "pause" and d is Dictionary and d.get("reason") == "bg":
		sync()
	elif ev == "resume" and from == "bg" and enabled:
		_p._post("cloud.check", {})
	elif ev == "games" and d is Dictionary and Json.truthy(d.get("signedIn")):
		_recall()
func _recall() -> void:
	var g = _p.games
	if _recalled or not enabled or not g.recall or not g.signed_in:
		return
	_recalled = true
	var session: String = await g.recall_session()
	if session != "":
		_p._post("cloud.recall", {"session": session})
static func _report_line(c: Dictionary, h: Dictionary) -> String:
	if not Json.truthy(c.get("on")):
		return "Cloud save: off (no server url)"
	var state := Json.str_or_empty(c.get("state"))
	var gen = c.get("gen")
	return "Cloud save: %s, gen %s, last synced %s (%s)" % [state if state != "" else "?", Json.js_string(gen if gen != null else -1), h.utc.call(c.get("syncedAt")), Json.str_or_empty(c.get("server")) if Json.truthy(c.get("server")) else "?"]
func settle_at_boot(rules: Variant):
	return await Rules.settle_at_boot(self, rules)
func take_cloud(rules: Variant, current: Variant, fallback: Variant = null) -> bool:
	return await Rules.take_cloud(self, rules, current, fallback)
func status_text(s: Variant, words: Dictionary = {}) -> String:
	return Rules.status_text(s, words)
func ago(t: Variant, now_ms: float = -1.0) -> String:
	return Rules.ago(t, now_ms)
func status_words() -> Dictionary:
	return Rules.STATUS_WORDS.duplicate()
