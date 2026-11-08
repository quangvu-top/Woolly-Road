# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
class_name HorusFakeNative
extends RefCounted
signal done(id: int, ok: bool, result: String)
signal event(name: String, data: String)
const Json := preload("res://addons/horus_sdk/core/json.gd")
const MODULES := ["adjust", "applovin", "billing", "facebook", "firebase-analytics", "firebase-crashlytics", "firebase-messaging", "firebase-remoteconfig", "review"]
var cfg := {}
var ios := false
var calls: Array = []
var saved = null
var scheduled = null
var finished: Array = []
var seq := 0
var mails: Array = []
var shares: Array = []
var shortcuts = null
var reviews := 0
var games := {}
var notif := {}
var user := {}
var crash_keys := {}
var crashes: Array = []
var game_states: Array = []
var fps: Array = []
var test_loop_reports: Array = []
var updates: Array = []
var hot_checks := 0
var ad_units = null
var ad_segments = null
var exits := 0
var readies := 0
var shortcut_opened = null
var cloud := {}
var _host = null
func _init(config: Dictionary = {}) -> void:
	cfg = {
		"insets": {"top": 24, "bottom": 16, "left": 0, "right": 0}, "ads": {"rv": true, "inter": true}, "ad_value": 0.02, "ad_tags": [],
		"prices": {}, "pending": [], "backup": null, "rc": {}, "buy_as": {}, "test_purchases": false, "rewarded_ok": true, "review_shown": true,
		"games_signed_in": true, "games_social": false, "games_stats": false, "games_recall": "", "update": null, "game_mode": "", "thermal": null,
		"exits": [], "display": null, "test_loop": null, "robot": false, "games_play": null, "font_scale": 1, "notif_granted": true,
		"notif_enabled": false, "notif_channels": {"rewards": true, "comeback": true, "news": true}, "notif_opened": null, "shortcuts": true,
		"shortcut_opened": null, "notif_asks": 0, "privacy_options": true, "ua": null, "tampered": false, "native": {},
		"support_id": "A1B2-C3D4-E5F6", "mail_app": true, "share": true, "share_result": null, "modules": MODULES.duplicate(), "delay": 120,
		"density": 2.75, "ios": false,
	}
	cfg.merge(config, true)
	ios = Json.truthy(cfg.ios)
	games = {"scores": [], "unlocks": [], "shows": [], "access": null, "challenges": [], "activities": [], "stats": [], "recalls": 0, "play": cfg.games_play}
	notif = {"granted": Json.truthy(cfg.notif_enabled), "channels": (cfg.notif_channels as Dictionary).duplicate(), "asks": int(cfg.notif_asks), "settings": 0, "opened": cfg.notif_opened}
	shortcut_opened = cfg.shortcut_opened
	if config.has("cloud") or config.has("cloud_boot"):
		var c: Dictionary = {"url": true, "boot": {"state": "none", "syncedAt": 0}, "status": {"state": "synced", "syncedAt": 0}}
		if config.get("cloud") is Dictionary:
			c.merge(config.cloud, true)
		cfg.cloud = c
		if not config.has("modules") and not "cloudsave" in cfg.modules:
			cfg.modules.append("cloudsave")
			cfg.modules.sort()
	var boot = cfg.cloud.boot if cfg.get("cloud") is Dictionary else null
	cloud = {"conflict": boot.duplicate() if boot is Dictionary and boot.get("state") == "conflict" else null, "resolved": [], "syncs": 0, "checks": 0, "on_check": null, "recalls": []}
func _attached(host) -> void:
	_host = host
func answer(id: int, ok: bool, r: Variant = null) -> void:
	var text := Json.stringify(r)
	var d := int(cfg.delay)
	if d <= 0:
		done.emit.call_deferred(id, ok, text)
	else:
		(Engine.get_main_loop() as SceneTree).create_timer(d / 1000.0, true, false, true).timeout.connect(func(): done.emit(id, ok, text))
func emit(ev: String, d: Variant = {}) -> void:
	event.emit(ev, Json.stringify(d))
func back() -> bool:
	return _host._back_request(false) if _host != null else false
func notif_tap(o: Dictionary) -> void:
	var now := _now()
	var d := {"at": 0, "shownAt": now - 60000, "openedAt": now}
	d.merge(o, true)
	emit("notif", d)
func shortcut_tap(id: String) -> void:
	emit("shortcut", {"id": id, "openedAt": _now()})
func game_mode(mode: String) -> void:
	emit("gamemode", {"mode": mode})
func thermal(status: String, headroom: float = -1) -> void:
	emit("thermal", {"status": status, "headroom": headroom})
func update_state(state: String, pct: Variant = null) -> void:
	emit("update", {"state": state} if pct == null else {"state": state, "pct": pct})
func games_play(activity: String, properties: Dictionary = {}) -> void:
	games.play = {"activity": activity, "properties": properties}
	emit("gamesPlay", games.play)
func cloud_conflict(c: Dictionary) -> void:
	var o := {"gen": 2, "savedAt": _now()}
	o.merge(c, true)
	cloud.conflict = o
	var e := {"state": "conflict", "syncedAt": 0}
	e.merge(o, true)
	emit("cloud", e)
func posted(m: String) -> Array:
	return calls.filter(func(c): return c.m == m)
func _hot_state() -> Dictionary:
	return {"on": false}
static func _now() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
func _has(mod: String) -> bool:
	return mod in cfg.modules
func post(json: String) -> void:
	var c = Json.parse(json)
	if not (c is Dictionary):
		return
	var id := int(Json.num0(c.get("id")))
	var m := str(c.get("m", ""))
	var a: Dictionary = c.get("a") if c.get("a") is Dictionary else {}
	var rec = a
	if m == "save.write":
		rec = {"bytes": str(a.get("data", "")).length()}
	elif m == "an.log":
		rec = {"n": a.get("n"), "pl": a.p.get("pl") if a.get("p") is Dictionary else null}
	calls.append({"m": m, "id": id, "a": rec})
	var off = {"ads": "applovin", "iap": "billing", "rc": "firebase-remoteconfig", "cloud": "cloudsave", "review": "review", "games": "games", "update": "update"}.get(m.split(".")[0])
	if off != null and not _has(off):
		var none := {"ads.rewarded": {"ok": false, "reason": "not_ready"}, "ads.inter": {"shown": false}, "ads.privacy": {}, "ads.debugger": {"shown": false},
			"review.ask": {"shown": false}, "games.show": {"shown": false}, "games.signin": {"signedIn": false},
			"update.check": {"available": false, "state": "none"}, "update.start": {"started": false},
			"iap.products": [], "iap.pending": [], "iap.buy": {"status": "error", "sku": a.get("sku"), "token": "", "orderId": ""}, "rc.values": {},
			"cloud.boot": {"state": "off"}, "cloud.status": {"state": "off"}, "cloud.resolve": {}}
		if id:
			answer(id, none.has(m), none.get(m))
		return
	if m.begins_with("cloud.") and cfg.get("cloud") is Dictionary:
		_cloud(id, m, a)
		return
	match m:
		"app.info":
			answer(id, true, _info())
			notif.opened = null
			shortcut_opened = null
		"app.diag":
			answer(id, true, _diag())
		"app.shortcuts":
			if cfg.shortcuts:
				shortcuts = a.get("list")
		"app.mail":
			mails.append(a.duplicate())
			answer(id, true, {"ok": true} if cfg.mail_app else {"ok": false, "reason": "no_app"})
		"app.share":
			shares.append(a.duplicate())
			answer(id, true, cfg.share_result if cfg.share_result != null else {"ok": true, "via": "sheet", "app": ""})
		"app.ready":
			readies += 1
		"app.exit":
			exits += 1
		"save.read":
			answer(id, true, {"data": cfg.backup})
		"save.write":
			saved = a.get("data")
		"rc.values":
			answer(id, true, cfg.rc)
		"iap.products":
			var list := []
			for sku in a.get("skus", []):
				if cfg.prices.has(sku):
					list.append({"sku": sku, "price": cfg.prices[sku]})
			answer(id, true, list)
		"iap.pending":
			answer(id, true, cfg.pending)
		"iap.buy":
			seq += 1
			var sku = a.get("sku")
			var as_ = cfg.buy_as.get(sku)
			if as_ == "invalid":
				answer(id, true, {"status": "invalid", "sku": sku, "token": "", "orderId": "", "reason": "signature"})
			elif as_ == "verifying":
				answer(id, true, {"status": "pending", "reason": "verifying", "sku": sku, "token": "tok-%s-%d" % [sku, seq], "orderId": "GPA.%d" % seq})
			else:
				answer(id, true, {"status": "ok", "sku": sku, "token": "tok-%s-%d" % [sku, seq], "orderId": "GPA.%d" % seq, "test": Json.truthy(cfg.test_purchases)})
		"iap.finish":
			finished.append(a)
		"iap.restore":
			answer(id, true, {"ok": true})
		"ads.rewarded":
			if cfg.ads.rv:
				_paid("REWARDED", a.get("pl"))
			var ok := Json.truthy(cfg.rewarded_ok)
			answer(id, true, ({"ok": ok, "reason": "" if ok else "closed"}) if cfg.ads.rv else {"ok": false, "reason": "not_ready"})
		"ads.inter":
			if cfg.ads.inter:
				_paid("INTER", a.get("pl"))
			answer(id, true, {"shown": Json.truthy(cfg.ads.inter)})
		"ads.privacy":
			answer(id, true, {})
		"ads.debugger":
			answer(id, true, {"shown": true})
		"ads.load", "ads.lostDone":
			pass
		"ads.units":
			ad_units = a.get("tags")
		"ads.segments":
			ad_segments = a.get("segments")
		"update.check":
			var u = cfg.update
			answer(id, true, {"available": true, "versionCode": u.get("versionCode", 2), "priority": u.get("priority", 0), "staleDays": u.get("staleDays", 0), "flexible": true, "immediate": true, "state": "none"} if u is Dictionary else {"available": false, "state": "none"})
		"update.start":
			updates.append("immediate" if Json.truthy(a.get("immediate")) else "flexible")
			answer(id, true, {"started": cfg.update != null})
		"update.complete":
			updates.append("complete")
		"review.ask":
			reviews += 1
			answer(id, true, {"shown": Json.truthy(cfg.review_shown)})
		"games.score":
			games.scores.append([a.get("board"), a.get("score")])
		"games.unlock":
			games.unlocks.append(a.get("id"))
		"games.access":
			games.access = Json.truthy(a.get("on"))
		"games.show":
			games.shows.append(str(a.get("what")) + (":" + str(a.board) if Json.truthy(a.get("board")) else ""))
			answer(id, true, {"shown": Json.truthy(cfg.games_signed_in)})
		"games.signin":
			answer(id, true, {"signedIn": Json.truthy(cfg.games_signed_in)})
		"games.challenge":
			games.challenges.append(a.get("id", ""))
			answer(id, true, {"shown": Json.truthy(cfg.games_signed_in)})
		"games.activity":
			games.activities.append([a.get("id"), Json.truthy(a.get("on"))])
		"games.takeplay":
			games.play = null
		"games.stat":
			games.stats.append([a.get("name"), a.get("props")])
		"games.recall":
			games.recalls += 1
			answer(id, true, {"sessionId": str(cfg.games_recall) if Json.truthy(cfg.games_signed_in) else ""})
		"app.gamestate":
			game_states.append([a.get("mode"), Json.truthy(a.get("loading"))])
		"app.fps":
			fps.append(a.get("hz"))
			var modes: Array = cfg.display.get("modes", []) if cfg.display is Dictionary else []
			var hz_ := Json.to_number(a.get("hz"))
			var up := modes.filter(func(x): return x >= hz_ - 0.5)
			var hz = 0
			if not modes.is_empty():
				hz = (up.min() if not up.is_empty() else modes.max()) if hz_ > 0.0 else cfg.display.hz
			answer(id, true, {"hz": hz})
		"app.hot.status", "app.hot.check":
			hot_checks += 1 if m == "app.hot.check" else 0
			answer(id, true, _hot_state())
		"app.testloop.done":
			test_loop_reports.append(a.get("report"))
			answer(id, true, {"written": cfg.test_loop != null})
		"notif.ask":
			if not notif.granted and notif.asks < 2:
				notif.asks += 1
				notif.granted = Json.truthy(cfg.notif_granted)
			answer(id, true, {"granted": notif.granted})
		"notif.schedule":
			scheduled = a.get("list")
		"notif.cancel":
			scheduled = []
		"notif.state":
			answer(id, true, {"supported": true, "enabled": notif.granted, "channels": (notif.channels as Dictionary).duplicate(), "canAsk": not notif.granted and notif.asks < 2})
		"notif.settings":
			notif.settings += 1
		"an.user":
			if a.get("props") is Dictionary:
				user.merge(a.props, true)
		"crash.keys":
			if _has("firebase-crashlytics") and a.get("keys") is Dictionary:
				crash_keys.merge(a.keys, true)
		"crash":
			crashes.append(a)
		_:
			if id and cfg.native.has(m):
				answer(id, true, cfg.native[m])
			elif id:
				answer(id, false, null)
func _paid(format: String, pl) -> void:
	if float(cfg.ad_value) > 0.0:
		var d := {"value": cfg.ad_value, "network": "AppLovin", "format": format, "placement": pl if pl != null else "", "precision": "exact", "tag": ""}
		emit.call_deferred("adpaid", d)
func _info() -> Dictionary:
	var with_ads := _has("applovin")
	var now := _now()
	var o := {"name": "Fake Game", "version": "1.0.0", "build": 1, "lang": "en-US", "debug": true, "insets": cfg.insets,
		"ads": (cfg.ads as Dictionary).duplicate() if with_ads else {"rv": false, "inter": false}, "adTags": (cfg.ad_tags as Array).duplicate() if with_ads else [],
		"privacyOptions": with_ads and Json.truthy(cfg.privacy_options), "shell": "0.8.0", "modules": (cfg.modules as Array).duplicate(), "supportId": cfg.support_id}
	if notif.opened is Dictionary:
		var n := {"at": 0, "shownAt": now - 60000, "openedAt": now}
		n.merge(notif.opened, true)
		o.notif = n
	o.shortcuts = Json.truthy(cfg.shortcuts)
	o.share = cfg.share != false
	if Json.truthy(shortcut_opened):
		o.shortcut = {"id": shortcut_opened, "openedAt": now}
	if cfg.ua is Dictionary and _has("adjust"):
		o.ua = (cfg.ua as Dictionary).duplicate()
	if _has("integrity"):
		o.tampered = Json.truthy(cfg.tampered)
	o.fontScale = cfg.font_scale
	if cfg.display != null:
		o.display = cfg.display
	if cfg.test_loop != null:
		o.testLoop = cfg.test_loop
	if Json.truthy(cfg.robot):
		o.robot = true
	o.hot = _hot_state()
	if Json.truthy(cfg.game_mode):
		o.gameMode = cfg.game_mode
		o.thermal = cfg.thermal if cfg.thermal != null else {"status": "none", "headroom": -1}
		o.exits = cfg.exits
	if _has("games"):
		var g := {"signedIn": Json.truthy(cfg.games_signed_in)}
		if Json.truthy(cfg.games_social):
			g.social = true
		if Json.truthy(cfg.games_stats):
			g.stats = true
		if Json.truthy(cfg.games_recall):
			g.recall = true
		if games.play != null:
			g.play = games.play
		o.games = g
	if _has("cloudsave") and cfg.get("cloud") is Dictionary:
		o.cloud = Json.truthy(cfg.cloud.url)
		o.jsPlugins = ["cloudsave"]
	o.density = cfg.density
	o.engine = "godot"
	return o
func _diag() -> Dictionary:
	var mods := {}
	if _has("applovin"):
		mods.applovin = {"sdk": "13.0.0", "initialized": true, "sdkKey": true, "rewarded": "rv-unit", "interstitial": "inter-unit", "rvReady": Json.truthy(cfg.ads.rv), "interReady": Json.truthy(cfg.ads.inter), "region": "OTHER", "privacyOptions": Json.truthy(cfg.privacy_options)}
	if _has("adjust"):
		mods.adjust = {"initialized": true, "environment": "sandbox", "appToken": "adjust-token", "purchaseEvent": "iap-token", "purchaseTestEvent": ""}
	if _has("facebook"):
		mods.facebook = {"sdk": "18.0.0", "initialized": true, "appId": "fb-app-id", "logging": true}
	for k in cfg.modules:
		if str(k).begins_with("firebase-"):
			mods[k] = {"initialized": true}
	if _has("billing"):
		mods.billing = {"ready": true, "checks": "server"}
	if _has("cloudsave") and cfg.get("cloud") is Dictionary:
		mods.cloudsave = {"on": Json.truthy(cfg.cloud.url), "server": "cloud-save.example.workers.dev" if Json.truthy(cfg.cloud.url) else "", "state": "synced", "gen": 3, "syncedAt": 1760000000000}
	return {"shell": "0.8.0", "app": {"name": "Fake Game", "package": "com.example.fake", "version": "1.0.0", "build": 1, "debug": true, "installer": ""},
		"device": {"android": "14", "sdk": 34, "maker": "Google", "model": "Pixel 8", "webview": "129.0.0.0", "lang": "en-US"}, "modules": mods}
func _cloud(id: int, m: String, a: Dictionary) -> void:
	var c: Dictionary = cfg.cloud
	match m:
		"cloud.boot":
			answer(id, true, c.boot if Json.truthy(c.url) else {"state": "off"})
		"cloud.status":
			if not Json.truthy(c.url):
				answer(id, true, {"state": "off"})
			elif cloud.conflict != null:
				var s := {"state": "conflict", "syncedAt": 0}
				s.merge(cloud.conflict, true)
				answer(id, true, s)
			else:
				answer(id, true, c.status)
		"cloud.resolve":
			var k = cloud.conflict
			cloud.conflict = null
			cloud.resolved.append(a.get("use"))
			answer(id, true, {"data": k.get("data") if k is Dictionary else null} if a.get("use") == "cloud" else {"ok": k != null})
		"cloud.sync":
			cloud.syncs += 1
		"cloud.check":
			cloud.checks += 1
			if cloud.on_check != null and cloud.conflict == null:
				var o: Dictionary = (cloud.on_check as Dictionary).duplicate()
				cloud.on_check = null
				o.force = true
				cloud_conflict.call_deferred(o)
		"cloud.recall":
			cloud.recalls.append(a.get("session"))
		_:
			if id:
				answer(id, false, null)
