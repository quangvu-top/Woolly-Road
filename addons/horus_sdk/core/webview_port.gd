# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
const SHIM := """(function () {
  var g = window.__wgGd;
  window.__wg = {
    done: function (id, ok, r) { g.done(id, !!ok, JSON.stringify(r === undefined ? null : r)); },
    emit: function (ev, d) { g.emit(String(ev), JSON.stringify(d === undefined ? null : d)); },
    back: function () { g.used = false; g.back(); return !!g.used; }
  };
})();"""
var kind := "android"
var handles_back := false
var _host
var _wg = null
var _gd = null
var _callbacks := []
func _init(host, js := true) -> void:
	_host = host
	if not js:
		return
	var window = JavaScriptBridge.get_interface("window")
	_wg = window.WGNative
	if Json.truthy(_wg.ios):
		kind = "ios"
	_gd = JavaScriptBridge.create_object("Object")
	_callbacks = [JavaScriptBridge.create_callback(_on_done), JavaScriptBridge.create_callback(_on_emit), JavaScriptBridge.create_callback(_on_back)]
	_gd.done = _callbacks[0]
	_gd.emit = _callbacks[1]
	_gd.back = _callbacks[2]
	window.__wgGd = _gd
	JavaScriptBridge.eval(SHIM, true)
static func present() -> bool:
	return OS.has_feature("web") and Json.truthy(JavaScriptBridge.eval("!!window.WGNative", true))
static func app_origin() -> bool:
	return OS.has_feature("web") and Json.truthy(JavaScriptBridge.eval("location.hostname === 'appassets.androidplatform.net' || location.protocol === 'webgame:'", true))
func post(json: String) -> bool:
	if _wg == null:
		return false
	_wg.post(json)
	return true
func _on_done(args: Array) -> void:
	if args.size() >= 3:
		_host._native_done(int(Json.to_number(args[0])), Json.truthy(args[1]), str(args[2]))
func _on_emit(args: Array) -> void:
	if args.size() >= 2:
		_host._native_event(str(args[0]), str(args[1]))
func _on_back(_args: Array) -> bool:
	var used: bool = _host._back_request(true)
	if _gd != null:
		_gd.used = used
	return used
