# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
var _p
var restorable := true
func _init(platform) -> void:
	_p = platform
func price(sku: String):
	return _p._prices.get(sku)
func offer(sku: String) -> Dictionary:
	var o = _p._offers.get(sku)
	return (o as Dictionary).duplicate() if o is Dictionary else {}
func buy(sku: String) -> Dictionary:
	var r = await _p._call("iap.buy", {"sku": sku}, {"status": "error"}, _p.LONG)
	var out: Dictionary = r.duplicate(true) if r is Dictionary else {}
	out["sku"] = r.get("sku") if r is Dictionary and Json.truthy(r.get("sku")) else sku
	out["status"] = Json.js_string(r.get("status")) if r is Dictionary and Json.truthy(r.get("status")) else "error"
	return out
func pending() -> Array:
	var r = await _p._call("iap.pending", {}, [], 15000)
	return r if r is Array else []
func finish(p: Dictionary) -> void:
	var a := {}
	if p.has("sku"):
		a.sku = p.sku
	if p.has("token"):
		a.token = p.token
	a.orderId = p.get("orderId") if Json.truthy(p.get("orderId")) else ""
	a.consumable = Json.truthy(p.get("consumable"))
	if p.has("usd"):
		var usd := Json.to_number(p.usd)
		if usd >= 0.0:
			a.usd = Json.ints(usd)
	_p._post("iap.finish", a)
func restore() -> bool:
	var r = await _p._call("iap.restore", {}, {"ok": false}, _p.LONG)
	return Json.truthy(r.get("ok")) if r is Dictionary else false
