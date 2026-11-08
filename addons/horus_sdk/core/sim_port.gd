# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
const SimAd := preload("res://addons/horus_sdk/core/sim_ad.gd")
var kind := "web"
var handles_back := false
var cfg := {
	"modules": [],
	"insets": {"top": 0, "bottom": 0, "left": 0, "right": 0},
	"prices": {},
	"connection": "wifi",
	"pending": [],
	"buy_ms": 700,
	"buy_as": {},
	"rc": {},
	"ad_pause": true,
	"ad_value": 0.0,
	"native": {},
	"backup_path": "user://horus/backup.json",
	"overlay": true,
	"verbose": false,
}
var calls: Array = []
var _host
var _present := Callable()
var _load_ms := 0
var _ready := {"rv": true, "inter": true}
var _loading := {"rv": false, "inter": false}
var _review_noted := false
func _init(host) -> void:
	_host = host
func post(json: String) -> bool:
	var c = Json.parse(json)
	if not (c is Dictionary):
		return false
	var id := int(Json.num0(c.get("id")))
	var m := str(c.get("m", ""))
	var a: Dictionary = c.get("a") if c.get("a") is Dictionary else {}
	calls.append({"m": m, "id": id, "a": a})
	if cfg.verbose:
		print("[horus sim] %s %s" % [m, Json.stringify(a)])
	_handle(id, m, a)
	return true
func emit(ev: String, d = {}) -> void:
	_host._native_event(ev, Json.stringify(d))
func _answer(id: int, ok: bool, r = null) -> void:
	if id != 0:
		_host._native_done.call_deferred(id, ok, Json.stringify(r))
func _later(ms: int) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(ms / 1000.0, true, false, true).timeout
func _handle(id: int, m: String, a: Dictionary) -> void:
	match m:
		"app.info":
			_answer(id, true, _info())
		"app.diag":
			_answer(id, true, {"app": {"name": _name(), "version": _version()},
				"device": {"ua": "Godot %s (%s)" % [Engine.get_version_info().string, OS.get_name()], "lang": _lang()}, "modules": {}})
		"app.mail":
			if DisplayServer.get_name() != "headless":
				OS.shell_open("mailto:%s?subject=%s&body=%s" % [a.get("to", ""), str(a.get("subject", "")).uri_encode(), str(a.get("body", "")).uri_encode()])
			_answer(id, true, {"ok": true})
		"save.read":
			_answer(id, true, {"data": _read_backup()})
		"save.write":
			_write_backup(str(a.get("data", "")))
		"rc.values":
			_answer(id, true, cfg.rc)
		"iap.products":
			var list := []
			for sku in a.get("skus", []):
				if cfg.prices.has(sku):
					var p = cfg.prices[sku]
					list.append(({"sku": sku} as Dictionary).merged(p) if p is Dictionary else {"sku": sku, "price": p})
			_answer(id, true, list)
		"iap.buy":
			_buy(id, str(a.get("sku", "")))
		"iap.pending":
			_answer(id, true, cfg.pending)
		"iap.restore":
			_answer(id, true, {"ok": true})
		"ads.rewarded":
			_show(id, "rv", "rewarded", str(a.get("pl", "")))
		"ads.inter":
			_show(id, "inter", "inter", str(a.get("pl", "")))
		"ads.load":
			var k = a.get("kind")
			if k != "inter":
				_load("rv")
			if k != "rv":
				_load("inter")
		"ads.privacy":
			_answer(id, true, {})
		"ads.debugger":
			_answer(id, true, {"shown": false})
		"review.ask":
			if not _review_noted:
				_review_noted = true
				print("[horus sim] review: no store review in the simulator")
			_answer(id, true, {"shown": false})
		"notif.ask":
			_answer(id, true, {"granted": true})
		"notif.state":
			_answer(id, false)
		"notif.schedule":
			if cfg.verbose:
				for n in a.get("list", []):
					print("[horus sim] reminder ", Json.stringify(n))
		"games.show", "games.challenge":
			_answer(id, true, {"shown": false})
		"games.signin":
			_answer(id, true, {"signedIn": false})
		"games.recall":
			_answer(id, true, {"sessionId": ""})
		"update.check":
			_answer(id, true, {"available": false, "state": "none"})
		"update.start":
			_answer(id, true, {"started": false})
		"app.fps":
			_answer(id, true, {"hz": 0})
		"app.share":
			_answer(id, true, {"ok": false, "reason": "unsupported"})
		"app.testloop.done":
			_answer(id, true, {"written": false})
		"cloud.boot", "cloud.status":
			_answer(id, true, {"state": "off"})
		"cloud.resolve":
			_answer(id, true, {})
		"haptic":
			var p = a.get("p")
			if p is int or p is float:
				Input.vibrate_handheld(int(p))
		_:
			if id != 0:
				if cfg.native.has(m):
					_answer(id, true, cfg.native[m])
				else:
					_answer(id, false)
func _name() -> String:
	return str(ProjectSettings.get_setting("application/config/name", ""))
func _version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	return v if v != "" else "sim"
static func _lang() -> String:
	return OS.get_locale().replace("_", "-")
func _info() -> Dictionary:
	return {"name": _name(), "version": _version(), "build": 0, "lang": _lang(), "debug": OS.is_debug_build(), "insets": cfg.insets,
		"ads": _ready.duplicate(), "privacyOptions": false, "supportId": "", "modules": (cfg.modules as Array).duplicate(), "shortcuts": false,
		"share": false, "fontScale": 1, "density": DisplayServer.screen_get_scale() if DisplayServer.get_name() != "headless" else 1.0,
		"engine": "godot", "hot": {"on": false}, "connection": cfg.connection}
func _read_backup():
	var p: String = cfg.backup_path
	if not FileAccess.file_exists(p):
		return null
	var f := FileAccess.open(p, FileAccess.READ)
	var t := f.get_as_text() if f else ""
	return t if t != "" else null
func _write_backup(data: String) -> void:
	var p: String = cfg.backup_path
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f:
		f.store_string(data)
func _buy(id: int, sku: String) -> void:
	await _later(int(cfg.buy_ms))
	var as_ = cfg.buy_as.get(sku, "ok")
	var token := "sim.%s.%d" % [sku, int(Time.get_unix_time_from_system() * 1000.0)]
	match as_:
		"ok":
			_answer(id, true, {"status": "ok", "sku": sku, "token": token, "orderId": "", "test": true})
		"pending":
			_answer(id, true, {"status": "pending", "reason": "verifying", "sku": sku, "token": token, "orderId": "", "test": true})
		"invalid":
			_answer(id, true, {"status": "invalid", "sku": sku, "token": "", "orderId": "", "reason": "signature"})
		_:
			_answer(id, true, {"status": str(as_), "sku": sku, "token": "", "orderId": ""})
func simulate(fn: Callable, opts: Dictionary = {}) -> void:
	_present = fn
	_load_ms = maxi(0, int(Json.num0(opts.get("load_ms", 0))))
	if _load_ms == 0:
		_ready.rv = true
		_ready.inter = true
		return
	_ready.rv = false
	_ready.inter = false
	_load("rv")
	_load("inter")
	emit("ads", _ready.duplicate())
func _load(k: String) -> void:
	if _load_ms == 0 or _ready[k] or _loading[k]:
		return
	_loading[k] = true
	await _later(_load_ms)
	_loading[k] = false
	_ready[k] = true
	emit("ads", _ready.duplicate())
func _show(id: int, k: String, kind_: String, pl: String) -> void:
	if not _ready[k]:
		_answer(id, true, {"ok": false, "reason": "not_ready"} if k == "rv" else {"shown": false})
		return
	if cfg.ad_pause:
		emit("pause", {"reason": "ad"})
	if _load_ms:
		_ready[k] = false
		emit("ads", _ready.duplicate())
	var ok := true
	if _present.is_valid():
		ok = Json.truthy(await _present.call(kind_, pl))
	elif cfg.overlay and DisplayServer.get_name() != "headless" and Engine.get_main_loop() is SceneTree:
		var o := SimAd.new()
		o.setup(kind_, pl)
		(Engine.get_main_loop() as SceneTree).root.add_child(o)
		ok = await o.finished
	if float(cfg.ad_value) > 0.0:
		emit("adpaid", {"value": cfg.ad_value, "network": "Simulator", "format": "REWARDED" if k == "rv" else "INTER", "placement": pl, "precision": "exact", "tag": ""})
	if cfg.ad_pause:
		emit("resume", {})
	_load(k)
	_answer(id, true, ({"ok": ok, "reason": "" if ok else "closed"}) if k == "rv" else {"shown": true})
func notify(what: int) -> void:
	match what:
		Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_WM_CLOSE_REQUEST:
			emit("pause", {"reason": "bg"})
		Node.NOTIFICATION_APPLICATION_RESUMED:
			emit("resume", {})
