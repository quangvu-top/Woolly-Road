# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends Node
const VERSION := "0.2.1"
const LONG := 600000
const Self := preload("res://addons/horus_sdk/horus.gd")
const Json := preload("res://addons/horus_sdk/core/json.gd")
const NativePort := preload("res://addons/horus_sdk/core/native_port.gd")
const WebViewPort := preload("res://addons/horus_sdk/core/webview_port.gd")
const SimPort := preload("res://addons/horus_sdk/core/sim_port.gd")
const CrashLogger := preload("res://addons/horus_sdk/core/crash_logger.gd")
const Ads := preload("res://addons/horus_sdk/api/ads.gd")
const Iap := preload("res://addons/horus_sdk/api/iap.gd")
const Analytics := preload("res://addons/horus_sdk/api/analytics.gd")
const Support := preload("res://addons/horus_sdk/api/support.gd")
const Share := preload("res://addons/horus_sdk/api/share.gd")
const Notif := preload("res://addons/horus_sdk/api/notif.gd")
const Shortcuts := preload("res://addons/horus_sdk/api/shortcuts.gd")
const Games := preload("res://addons/horus_sdk/api/games.gd")
const Device := preload("res://addons/horus_sdk/api/device.gd")
const Misc := preload("res://addons/horus_sdk/api/misc.gd")
const Cloud := preload("res://addons/horus_sdk/cloud/cloud.gd")
const SaveStore := preload("res://addons/horus_sdk/save/save_store.gd")
signal pause(data: Dictionary)
signal resume(data: Dictionary)
signal audio(data: Dictionary)
signal ads_event(data: Dictionary)
signal adpaid(data: Dictionary)
signal purchase(data: Dictionary)
signal prices(data: Dictionary)
signal insets(data: Dictionary)
signal notif_event(data: Dictionary)
signal shortcut(data: Dictionary)
signal ua_event(data: Dictionary)
signal games_event(data: Dictionary)
signal games_play(data: Dictionary)
signal trim(data: Dictionary)
signal gamemode(data: Dictionary)
signal thermal(data: Dictionary)
signal update_event(data: Dictionary)
signal cloud_event(data: Dictionary)
const SIGNALS := {"ads": "ads_event", "notif": "notif_event", "ua": "ua_event", "games": "games_event", "gamesPlay": "games_play",
	"update": "update_event", "cloud": "cloud_event"}
const UPDATE_STATES := ["none", "downloading", "downloaded", "installing"]
var target := "web"
var simulated := false
var info := {"name": "", "version": "", "build": 0, "lang": "", "debug": false, "modules": [], "tampered": false, "fontScale": 1, "density": 1.0, "engine": "godot"}
var ua = null
var ads: Ads
var iap: Iap
var an: Analytics
var rc: Misc.Rc
var save: Misc.SaveMirror
var cloud: Cloud
var notif: Notif
var games: Games
var update: Misc.Update
var device: Device
var support: Support
var shortcuts: Shortcuts
var share: Share
var native: Misc.Native
var hot: Misc.Hot
var test_loop = null
var monetize = _logic("monetize")
var liveops = _logic("liveops")
var economy = _logic("economy")
var _port = null
var _attached := false
var _seq := 0
var _calls := {}
var _prices := {}
var _offers := {}
var _ads := {}
var _paused_for := ""
var _back_fn := Callable()
var _signals := false
var _app_share := false
var _start_job = null
var _started := false
var _logger = null
class Pending extends RefCounted:
	signal finished(value)
	var done := false
	var value = null
	var fallback = null
	func wait():
		if done:
			return value
		return await finished
func _init() -> void:
	_seq = randi() % 1000000000
	_ads = _ads_state({})
	ads = Ads.new(self)
	iap = Iap.new(self)
	an = Analytics.new(self)
	rc = Misc.Rc.new()
	save = Misc.SaveMirror.new(self)
	cloud = Cloud.new(self)
	notif = Notif.new(self)
	games = Games.new(self)
	update = Misc.Update.new(self)
	device = Device.new(self)
	support = Support.new(self)
	shortcuts = Shortcuts.new(self)
	share = Share.new(self)
	native = Misc.Native.new(self)
	hot = Misc.Hot.new()
	support.about = "Horus SDK for Godot: " + VERSION
	support.lines["cloudsave"] = Cloud._report_line
static func get_sdk() -> Self:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Horus") as Self
static func _logic(name: String):
	var p := "res://addons/horus_sdk/logic/%s.gd" % name
	return load(p) if ResourceLoader.exists(p) else null
func _ready() -> void:
	if not _attached:
		attach(_detect())
	if get_path() == ^"/root/Horus":
		if _port != null and _port.handles_back:
			get_tree().set_quit_on_go_back(false)
		if OS.has_method("add_logger") and not Engine.is_editor_hint():
			_logger = CrashLogger.new(crash)
			OS.add_logger(_logger)
func _exit_tree() -> void:
	if _logger != null and OS.has_method("remove_logger"):
		OS.remove_logger(_logger)
		_logger = null
func _detect():
	if Engine.has_singleton("HorusSDK"):
		return Engine.get_singleton("HorusSDK")
	if OS.has_feature("web"):
		if WebViewPort.present():
			return WebViewPort.new(self)
		if WebViewPort.app_origin():
			target = "ios" if JavaScriptBridge.eval("location.protocol === 'webgame:'", true) else "android"
			return null
		return SimPort.new(self)
	if (OS.has_feature("android") or OS.has_feature("ios")) and not OS.is_debug_build():
		target = "ios" if OS.has_feature("ios") else "android"
		return null
	return SimPort.new(self)
func attach(bridge: Variant) -> void:
	_attached = true
	if NativePort.is_bridge(bridge):
		_port = NativePort.new(bridge, self)
	else:
		_port = bridge
	if _port != null:
		target = _port.kind
	simulated = _port is SimPort
var sim:
	get:
		return _port if simulated else null
func _send(id: int, m: String, a) -> bool:
	if _port == null:
		return false
	return _port.post(Json.stringify({"id": id, "m": m, "a": a if a != null else {}}))
func _post(m: String, a = {}) -> void:
	_send(0, m, a)
func _request(m: String, a, fallback, timeout_ms: int = 0) -> Pending:
	_seq += 1
	var id := _seq
	var p := Pending.new()
	p.fallback = fallback
	_calls[id] = p
	if timeout_ms > 0:
		(Engine.get_main_loop() as SceneTree).create_timer(timeout_ms / 1000.0, true, false, true).timeout.connect(_end.bind(id, false, null))
	if not _send(id, m, a):
		_end(id, false, null)
	return p
func _call(m: String, a, fallback, timeout_ms: int = 0):
	return await _request(m, a, fallback, timeout_ms).wait()
func _end(id: int, ok: bool, r) -> void:
	var p: Pending = _calls.get(id)
	if p == null:
		return
	_calls.erase(id)
	p.done = true
	p.value = r if ok else p.fallback
	p.finished.emit(p.value)
func _native_done(id, ok, result) -> void:
	_end(int(id), Json.truthy(ok), Json.parse(str(result)) if result != null else null)
func _native_event(name, data) -> void:
	_dispatch(str(name), Json.parse(str(data)) if data != null else null)
func start(opts: Dictionary = {}) -> Node:
	if _start_job == null:
		_start_job = Pending.new()
		_started = true
		_init_platform(opts)
	await _start_job.wait()
	return self
func _init_platform(opts: Dictionary) -> void:
	if not _attached:
		attach(_detect())
	var skus: Array = opts.get("skus", [])
	cloud._on = opts.get("cloud", true) != false
	var wait_ms = opts.get("cloud_wait")
	var i = await _call("app.info", {}, {}, 4000)
	if not (i is Dictionary):
		i = {}
	info.name = Json.str_or_empty(i.get("name"))
	info.version = Json.str_or_empty(i.get("version"))
	info.build = Json.to_int32(i.get("build"))
	info.lang = Json.str_or_empty(i.get("lang"))
	info.debug = Json.truthy(i.get("debug"))
	info.tampered = Json.truthy(i.get("tampered"))
	var fs := Json.to_number(i.get("fontScale"))
	info.fontScale = Json.ints(fs) if fs > 0.0 else 1
	var dens := Json.to_number(i.get("density"))
	info.density = dens if dens > 0.0 else 1.0
	info.engine = "godot"
	support.id = Json.str_or_empty(i.get("supportId"))
	var mods = null
	if i.get("modules") is Array:
		mods = (i.modules as Array).map(func(x): return Json.js_string(x))
	info.modules = mods if mods != null else []
	if mods != null:
		iap.restorable = "billing" in mods
	games.available = mods != null and "games" in mods
	var g: Dictionary = i.games if i.get("games") is Dictionary else {}
	games.signed_in = Json.truthy(g.get("signedIn"))
	games.social = Json.truthy(g.get("social"))
	games.play = Games._play_of(g.get("play"))
	games.stats = Json.truthy(g.get("stats"))
	games.recall = Json.truthy(g.get("recall"))
	var up = i.get("update")
	update.state = up.get("state") if up is Dictionary and up.get("state") in UPDATE_STATES else "none"
	_signals = i.has("gameMode")
	device.game_mode = Device._mode_of(i.get("gameMode"))
	device.thermal = Device._thermal_of(i.get("thermal"))
	device.display = Device._display_of(i.get("display"))
	device.robot = Json.truthy(i.get("robot"))
	device.connection = Device._connection_of(i.get("connection"))
	var tl = i.get("testLoop")
	test_loop = Misc.TestLoop.new(self, Json.to_int32(tl.get("scenario"))) if tl is Dictionary else null
	device.exits = []
	for e in (i.exits if i.get("exits") is Array else []):
		if e is Dictionary:
			device.exits.append({"reason": Json.str_or_empty(e.get("reason")), "at": Json.ints(Json.num0(e.get("at"))), "foreground": Json.truthy(e.get("foreground")),
				"pssKb": Json.ints(Json.num0(e.get("pssKb"))), "rssKb": Json.ints(Json.num0(e.get("rssKb")))})
	device._set_insets(i.get("insets"))
	if Json.truthy(i.get("ads")):
		_ads = _ads_state(i.ads)
	ads.tags = (i.adTags as Array).map(func(x): return Json.js_string(x)) if i.get("adTags") is Array else []
	ads.has_privacy = Json.truthy(i.get("privacyOptions"))
	ads.lost = []
	for r in (i.lostRewards if i.get("lostRewards") is Array else []):
		if r is Dictionary:
			ads.lost.append({"pl": Json.str_or_empty(r.get("pl")), "at": Json.ints(Json.num0(r.get("at")))})
	notif.opened = Notif._open_of(i.get("notif"))
	shortcuts.supported = Json.truthy(i.get("shortcuts"))
	shortcuts.opened = Shortcuts._open_of(i.get("shortcut"))
	_app_share = Json.truthy(i.get("share"))
	share.supported = _app_share or (simulated and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD))
	var u = _ua_of(i.get("ua"))
	if u != null:
		ua = u
	for n in (i.jsPlugins if i.get("jsPlugins") is Array else []):
		if str(n) == "cloudsave" and cloud._on:
			continue
		var msg := "the build has the %s module but the game has no %s plugin: call Horus.start() with it on (README of the Godot addon)" % [n, n]
		push_warning("[horus] " + msg)
		crash(msg, "")
	var backup_job := _request("save.read", {}, null, 3000)
	var rc_job := _request("rc.values", {}, {}, 3000)
	var cloud_job = cloud._start(i, Cloud.BOOT_WAIT if wait_ms == null else wait_ms)
	var backup = await backup_job.wait()
	var values = await rc_job.wait()
	var data = backup.get("data") if backup is Dictionary else null
	save.backup = data if data is String and data != "" else null
	var merged := {}
	for k in opts.get("rc_defaults", {}):
		merged[k] = Json.js_string(opts.rc_defaults[k])
	if values is Dictionary:
		merged.merge(values, true)
	rc.values = merged
	an._start(rc.values, i.get("connection"))
	if cloud_job != null:
		var from_cloud = cloud._booted(await cloud_job.wait())
		if from_cloud != null:
			save.backup = from_cloud
	_load_prices(skus)
	_start_job.done = true
	_start_job.finished.emit(self)
func _load_prices(skus: Array) -> void:
	var list = await _call("iap.products", {"skus": skus}, [], 15000)
	for p in (list if list is Array else []):
		if p is Dictionary and Json.truthy(p.get("sku")) and Json.truthy(p.get("price")):
			_prices[p.sku] = Json.js_string(p.price)
			var m = p.get("micros")
			var cur := Json.str_or_empty(p.get("currency"))
			if (m is int or m is float) and is_finite(float(m)) and float(m) >= 0.0 and cur != "":
				_offers[p.sku] = {"price": _prices[p.sku], "micros": Json.ints(float(m)), "currency": cur}
	_emit_signal("prices", _prices.duplicate())
func ready() -> void:
	_post("app.ready", {})
func on_back(fn: Callable) -> void:
	_back_fn = fn
func exit() -> void:
	_post("app.exit", {})
func _back_request(app_exits := false) -> bool:
	var used := false
	if _back_fn.is_valid():
		used = Json.truthy(_back_fn.call())
	if not used and not app_exits:
		_post("app.exit", {})
	return used
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _port != null and _port.handles_back:
			_back_request(false)
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _port != null and _port.has_method("notify"):
			_port.notify(what)
func on(ev: String, fn: Callable) -> void:
	var s := _signal_of(ev)
	if not has_signal(s):
		add_user_signal(s, [{"name": "data", "type": TYPE_DICTIONARY}])
	if not is_connected(s, fn):
		connect(s, fn)
func off(ev: String, fn: Callable) -> void:
	var s := _signal_of(ev)
	if has_signal(s) and is_connected(s, fn):
		disconnect(s, fn)
func _signal_of(ev: String) -> String:
	return SIGNALS.get(ev, ev)
func _listening(ev: String) -> bool:
	var s := _signal_of(ev)
	return has_signal(s) and not get_signal_connection_list(s).is_empty()
func _emit_signal(ev: String, d) -> void:
	var s := _signal_of(ev)
	if has_signal(s):
		emit_signal(s, d)
func _dispatch(ev: String, d) -> void:
	if d == null:
		d = {}
	match ev:
		"ads":
			_ads = _ads_state(d)
			if d is Dictionary and d.get("privacy") != null:
				ads.has_privacy = Json.truthy(d.privacy)
		"adpaid":
			d = _ad_paid(d)
		"insets":
			device._set_insets(d)
		"update":
			var st = d.get("state") if d is Dictionary else null
			var o := {"state": st if st in UPDATE_STATES else "none"}
			var pct := Json.to_number(d.get("pct")) if d is Dictionary and d.has("pct") else NAN
			if is_finite(pct):
				o.pct = Json.ints(pct)
			d = o
			update.state = o.state
		"gamemode":
			d = {"mode": Device._mode_of(d.get("mode") if d is Dictionary else null)}
			device.game_mode = d.mode
		"thermal":
			d = Device._thermal_of(d)
			device.thermal = d
		"ua":
			ua = _ua_of(d)
		"games":
			d = {"signedIn": Json.truthy(d.get("signedIn") if d is Dictionary else null)}
			games.signed_in = d.signedIn
		"gamesPlay":
			d = Games._play_of(d)
			if d == null:
				return
			if not _listening("gamesPlay"):
				games.play = d
				return
			games.play = null
			_post("games.takeplay", {})
		"notif":
			d = Notif._open_of(d)
			if d == null:
				return
			if not _listening("notif"):
				notif.opened = d
				return
		"shortcut":
			d = Shortcuts._open_of(d)
			if d == null:
				return
			if not _listening("shortcut"):
				shortcuts.opened = d
				return
	d = cloud._map_event(ev, d)
	if d == null:
		return
	_emit_signal(ev, d)
	var from := _paused_for
	if ev == "pause":
		save.flush()
		an.flush()
		_paused_for = Json.str_or_empty(d.get("reason") if d is Dictionary else null)
	elif ev == "resume":
		_paused_for = ""
	cloud._after(ev, d, from)
static func _ads_state(d) -> Dictionary:
	var g := func(k): return d.get(k) if d is Dictionary else null
	var rv := Json.to_number(g.call("rvValue")) if d is Dictionary and d.has("rvValue") else NAN
	var iv := Json.to_number(g.call("interValue")) if d is Dictionary and d.has("interValue") else NAN
	return {"rv": Json.truthy(g.call("rv")), "inter": Json.truthy(g.call("inter")), "rvValue": Json.ints(rv) if is_finite(rv) else -1,
		"interValue": Json.ints(iv) if is_finite(iv) else -1, "rvNet": Json.str_or_empty(g.call("rvNet")), "interNet": Json.str_or_empty(g.call("interNet"))}
static func _ad_paid(d) -> Dictionary:
	var g := func(k): return d.get(k) if d is Dictionary else null
	return {"value": Json.ints(Json.num0(g.call("value"))), "network": Json.str_or_empty(g.call("network")),
		"kind": "rv" if Json.str_or_empty(g.call("format")).to_upper().contains("REWARD") else "inter",
		"placement": Json.str_or_empty(g.call("placement")), "precision": Json.str_or_empty(g.call("precision")), "tag": Json.str_or_empty(g.call("tag"))}
static func _ua_of(o):
	if not (o is Dictionary):
		return null
	return {"network": Json.str_or_empty(o.get("network")), "campaign": Json.str_or_empty(o.get("campaign")),
		"adgroup": Json.str_or_empty(o.get("adgroup")), "creative": Json.str_or_empty(o.get("creative"))}
func review() -> Dictionary:
	var r = await _call("review.ask", {}, {"shown": false}, LONG)
	return {"shown": Json.truthy(r.get("shown")) if r is Dictionary else false}
func haptic(p: Variant) -> void:
	_post("haptic", {"p": p})
func game_state(mode: String = "menu", loading: bool = false) -> void:
	if _signals:
		_post("app.gamestate", {"mode": mode if mode in ["menu", "play", "content"] else "unknown", "loading": loading})
func crash(msg: Variant, stack: Variant = "") -> void:
	_post("crash", {"msg": Json.str_or_empty(msg).left(500), "stack": Json.str_or_empty(stack).left(4000)})
func crash_keys(keys: Dictionary) -> void:
	var k := {}
	for n in keys:
		var v = keys[n]
		if v == null or v is String or v is int or v is float or v is bool:
			k[n] = v
	_post("crash.keys", {"keys": k})
func save_store(o: Dictionary) -> SaveStore:
	var opts := o.duplicate()
	if not opts.has("mirror"):
		opts.mirror = save.mirror
	return SaveStore.new(opts)
