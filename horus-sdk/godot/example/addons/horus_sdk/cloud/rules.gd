# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
static var STATUS_WORDS := {
	"synced": func(at): return ("Saved " + ago(at)) if Json.truthy(at) else "Saved",
	"offline": "Saves when you are online",
	"none": "Saves after your next run",
	"error": "Could not save. It tries again after your next run",
	"conflict": "Waiting for your choice",
	"off": "Off",
}
static func rule(rules: Variant, name: String, args: Array = []):
	if rules is Dictionary:
		return (rules[name] as Callable).callv(args)
	return rules.callv(name, args)
static func settle_at_boot(cloud: Variant, rules: Variant):
	var b = cloud.boot if cloud != null and "boot" in cloud else null
	if not (b is Dictionary) or b.get("state") != "conflict":
		return null
	var local = rule(rules, "parse", [rule(rules, "read")])
	var copy = rule(rules, "parse", [b.get("data")])
	var forced := Json.truthy(b.get("force")) and copy != null
	if copy != null and (forced or local == null or Json.truthy(rule(rules, "further", [copy, local]))):
		var s = rule(rules, "parse", [await cloud.use_cloud()])
		if s == null:
			s = copy
		var added = rule(rules, "merge", [s, local])
		rule(rules, "adopt", [s])
		return {"took": "cloud", "forced": forced, "added": added, "local": local, "cloud": s}
	var added = rule(rules, "merge", [local, copy])
	if local != null:
		rule(rules, "adopt", [local])
	await cloud.keep_local()
	return {"took": "local", "forced": false, "added": added, "local": local, "cloud": copy}
static func take_cloud(cloud: Variant, rules: Variant, current: Variant, fallback: Variant) -> bool:
	var raw = null
	if cloud != null and cloud.has_method("use_cloud"):
		raw = await cloud.use_cloud()
	var s = rule(rules, "parse", [raw])
	if s == null:
		s = fallback
	if s == null:
		return false
	rule(rules, "merge", [s, current])
	rule(rules, "adopt", [s])
	return true
static func ago(t: Variant, now_ms: float = -1.0) -> String:
	if now_ms < 0.0:
		now_ms = Time.get_unix_time_from_system() * 1000.0
	var m := (now_ms - Json.to_number(t)) / 60000.0
	if not Json.truthy(t) or not is_finite(m):
		return ""
	if m < 1.0:
		return "just now"
	if m < 60.0:
		return "%d min ago" % int(Json.js_round(m))
	var h := int(Json.js_round(m / 60.0))
	if h < 24:
		return "%d hour%s ago" % [h, "s" if h > 1 else ""]
	var d := int(Json.js_round(m / 1440.0))
	return "%d day%s ago" % [d, "s" if d > 1 else ""]
static func status_text(s: Variant, words: Dictionary = {}) -> String:
	var w := STATUS_WORDS.duplicate()
	w.merge(words, true)
	var state = s.get("state") if s is Dictionary else null
	var k := "off"
	match state:
		"synced":
			k = "synced"
		"pending", "offline":
			k = "offline"
		"none", "error", "conflict":
			k = state
	var v = w.get(k)
	return str(v.call(s.get("syncedAt") if s is Dictionary else null)) if v is Callable else str(v)
static func cloud_state(r: Variant) -> Dictionary:
	var g := func(k): return r.get(k) if r is Dictionary else null
	var o := {"state": Json.str_or_empty(g.call("state")) if Json.truthy(g.call("state")) else "off", "syncedAt": Json.ints(Json.num0(g.call("syncedAt")))}
	var gen = g.call("gen")
	if (gen is int or gen is float) and is_finite(float(gen)):
		o.gen = gen
	var saved_at = g.call("savedAt")
	if (saved_at is int or saved_at is float) and is_finite(float(saved_at)):
		o.savedAt = saved_at
	if g.call("data") is String:
		o.data = g.call("data")
	if g.call("force") is bool and g.call("force") == true:
		o.force = true
	if g.call("recall") is bool and g.call("recall") == true:
		o.recall = true
	return o
