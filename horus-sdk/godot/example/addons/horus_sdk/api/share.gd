# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
const MAX_IMAGE := 8 * 1024 * 1024
static var _image := RegEx.create_from_string("^data:image/(png|jpeg|webp);base64,")
var _p
var supported := false
func _init(platform) -> void:
	_p = platform
static func share_of(o: Variant) -> Dictionary:
	var s := func(k): return Json.js_trim(o.get(k)) if o is Dictionary and o.get(k) is String else ""
	var image: String = s.call("image")
	return {"title": s.call("title"), "text": s.call("text"), "url": s.call("url"),
		"image": image if _image.search(image) != null and image.length() <= MAX_IMAGE else ""}
static func share_line(m: Dictionary) -> String:
	return " ".join(PackedStringArray([m.text, m.url].filter(func(x): return x != "")))
static func share_result(r: Variant) -> Dictionary:
	if not (r is Dictionary):
		return {"ok": false, "reason": "error"}
	if Json.truthy(r.get("ok")):
		return {"ok": true, "via": "copy" if r.get("via") == "copy" else "sheet", "app": r.app if r.get("app") is String else ""}
	return {"ok": false, "reason": r.reason if r.get("reason") in ["cancel", "unsupported", "error"] else "error"}
static func image_url(img: Image) -> String:
	return "data:image/png;base64," + Marshalls.raw_to_base64(img.save_png_to_buffer())
func open(o: Dictionary) -> Dictionary:
	var m := share_of(o)
	if m.text == "" and m.url == "" and m.image == "":
		return {"ok": false, "reason": "error"}
	if not _p._app_share:
		return copy_line(m)
	return share_result(await _p._call("app.share", m, {"ok": false, "reason": "error"}, _p.LONG))
static func copy_line(m: Dictionary) -> Dictionary:
	var line := share_line(m)
	if line != "" and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(line)
		return {"ok": true, "via": "copy", "app": ""}
	return {"ok": false, "reason": "unsupported"}
