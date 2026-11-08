# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
const FIREBASE := ["firebase-analytics", "firebase-crashlytics", "firebase-messaging", "firebase-remoteconfig"]
const INSTALLERS := {"com.android.vending": "Google Play", "com.google.android.packageinstaller": "an APK file", "com.android.packageinstaller": "an APK file",
	"appstore": "the App Store", "testflight": "TestFlight"}
var _p
var id := ""
var lines := {}
var about := ""
func _init(platform) -> void:
	_p = platform
static func utc(ms: Variant) -> String:
	var n := Json.to_number(ms)
	if not Json.truthy(ms) or not is_finite(n) or absf(n) > 8.64e15:
		return "never"
	var d := Time.get_datetime_dict_from_unix_time(int(floorf(n / 1000.0)))
	return "%04d-%02d-%02d %02d:%02d UTC" % [d.year, d.month, d.day, d.hour, d.minute]
static func val(v: Variant) -> String:
	return "NOT CONFIGURED" if v == null or (v is String and v == "") else Json.js_string(v)
static func _b(v) -> String:
	return "true" if Json.truthy(v) else "false"
static func report_of(d: Dictionary, sid: String = "", more: Dictionary = {}, about_line: String = "") -> String:
	var app: Dictionary = d.get("app", {}) if d.get("app") is Dictionary else {}
	var dev: Dictionary = d.get("device", {}) if d.get("device") is Dictionary else {}
	var m: Dictionary = d.get("modules", {}) if d.get("modules") is Dictionary else {}
	var L := PackedStringArray(["--- SDK Status ---"])
	if sid != "":
		L.append("Support ID: " + sid)
	var from := ""
	if app.has("installer"):
		var ins = app.installer
		from = ", from " + (INSTALLERS[ins] if INSTALLERS.has(ins) else (Json.js_string(ins) if Json.truthy(ins) else "outside a store"))
	var head := PackedStringArray()
	for x in [app.get("name"), app.get("version")]:
		if Json.truthy(x):
			head.append(Json.js_string(x))
	L.append("App: %s%s%s%s" % [" ".join(head), (" (build %s)" % Json.js_string(app.build)) if Json.truthy(app.get("build")) else "", ", debug build" if Json.truthy(app.get("debug")) else "", from])
	if Json.truthy(d.get("shell")):
		L.append("Shell: @horus/webgame " + Json.js_string(d.shell))
	if about_line != "":
		L.append(about_line)
	if Json.truthy(dev.get("ua")):
		L.append("Browser: " + Json.js_string(dev.ua))
	else:
		var os := ""
		if Json.truthy(dev.get("android")):
			os = "Android %s%s" % [Json.js_string(dev.android), (" (SDK %s)" % Json.js_string(dev.sdk)) if Json.truthy(dev.get("sdk")) else ""]
		elif Json.truthy(dev.get("ios")):
			os = "iOS " + Json.js_string(dev.ios)
		var who := PackedStringArray()
		for x in [dev.get("maker"), dev.get("model")]:
			if Json.truthy(x):
				who.append(Json.js_string(x))
		var parts := PackedStringArray()
		for x in [" ".join(who), os, ("WebView " + Json.js_string(dev.webview)) if Json.truthy(dev.get("webview")) else "", Json.js_string(dev.lang) if Json.truthy(dev.get("lang")) else ""]:
			if x != "":
				parts.append(x)
		L.append("Device: " + (", ".join(parts) if not parts.is_empty() else "unknown"))
	if Json.truthy(m.get("applovin")):
		var a: Dictionary = m.applovin
		L.append("Max SDK: %s (Initialized: %s%s)" % [val(a.get("sdk")), _b(a.get("initialized")), ", no SDK key" if a.get("sdkKey") is bool and a.sdkKey == false else ""])
		L.append("Interstitial: " + val(a.get("interstitial")))
		L.append("Rewarded: " + val(a.get("rewarded")))
		L.append("Ads loaded: rewarded %s, interstitial %s%s" % [_b(a.get("rvReady")), _b(a.get("interReady")), (", consent region " + Json.js_string(a.region)) if Json.truthy(a.get("region")) else ""])
	var fb := FIREBASE.filter(func(k): return Json.truthy(m.get(k)))
	if not fb.is_empty():
		var on := fb.filter(func(k): return Json.truthy(m[k].get("initialized")))
		var names := PackedStringArray()
		for k in fb:
			names.append(k.substr(9) + ("" if Json.truthy(m[k].get("initialized")) else " OFF"))
		L.append("Firebase Initialized: %s (%s)" % [_b(on.size() == fb.size()), ", ".join(names)])
	if Json.truthy(m.get("facebook")):
		L.append("Facebook SDK: %s (Initialized: %s)" % [val(m.facebook.get("sdk")), _b(m.facebook.get("initialized"))])
		L.append("Facebook Id: " + val(m.facebook.get("appId")))
	if Json.truthy(m.get("adjust")):
		var a: Dictionary = m.adjust
		L.append("Adjust SDK Initialized: " + _b(a.get("initialized")))
		L.append("Adjust Environment: " + val(a.get("environment")))
		L.append("Adjust Token: " + val(a.get("appToken")))
		L.append("Adjust IAP Token: %s%s" % [val(a.get("purchaseEvent")), (" (test purchases: %s)" % Json.js_string(a.purchaseTestEvent)) if Json.truthy(a.get("purchaseTestEvent")) else ""])
	if Json.truthy(m.get("billing")):
		L.append("Billing: %s, purchases checked by %s" % ["connected" if Json.truthy(m.billing.get("ready")) else "not connected", val(m.billing.get("checks"))])
	var keys := more.keys()
	keys.sort()
	var helpers := {"utc": utc, "val": val}
	for k in keys:
		if not Json.truthy(m.get(k)) or not (more[k] is Callable):
			continue
		var got = (more[k] as Callable).call(m[k], helpers)
		for l in (got if got is Array else [got]):
			if l is String and l != "":
				L.append(l)
	for k in m:
		var v = m[k]
		if v is Dictionary and Json.truthy(v.get("error")):
			L.append("%s: status failed (%s)" % [k, Json.js_string(v.error)])
	return "\n".join(L)
func diag() -> Dictionary:
	var r = await _p._call("app.diag", {}, {}, 4000)
	return r if r is Dictionary else {}
func report(d: Dictionary) -> String:
	return report_of(d, id, lines, about)
func mail(m: Dictionary) -> Dictionary:
	var r = await _p._call("app.mail", {"to": m.get("to", ""), "subject": m.get("subject", ""), "body": m.get("body", "")}, {"ok": false, "reason": "no_app"}, 8000)
	var ok := Json.truthy(r.get("ok")) if r is Dictionary else false
	if ok:
		return {"ok": true}
	var reason = r.get("reason") if r is Dictionary else null
	return {"ok": false, "reason": Json.js_string(reason) if Json.truthy(reason) else "no_app"}
func contact(o: Dictionary = {}) -> Dictionary:
	var to = o.get("to")
	if not Json.truthy(to) or not Json.js_string(to).contains("@"):
		return {"ok": false, "reason": "address"}
	var d := (await diag()).duplicate(true)
	var app: Dictionary = d.get("app", {}) if d.get("app") is Dictionary else {}
	var name = o.get("app") if Json.truthy(o.get("app")) else (app.get("name") if Json.truthy(app.get("name")) else (_p.info.name if _p.info.name != "" else "Game"))
	app.name = name
	d.app = app
	var version = app.get("version") if Json.truthy(app.get("version")) else _p.info.version
	var build = app.get("build") if app.get("build") != null else _p.info.build
	var os := {"android": "Android", "ios": "iOS"}.get(_p.target, "Web")
	var subject := "%s - %s - %s - %s - USERID: %s" % [Json.js_string(name), Json.js_string(version), Json.js_string(build), os, id if id != "" else "none"]
	var hello = o.get("greeting") if o.get("greeting") != null else ("Hi there! My support ID is %s." % id if id != "" else "Hi there!")
	return await mail({"to": Json.js_trim(Json.js_string(to)), "subject": subject, "body": "%s\n\n\n\n%s\n" % [Json.js_string(hello), report(d)]})
