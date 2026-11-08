extends Node
## Boot + Horus SDK wiring (rules from horus-sdk/godot/AGENTS.md) + the meta flow (docs/UX_FLOW.md):
##   1. a versioned save via Horus.save_store (the app keeps a copy), restore_backup before load
##   2. await Horus.start once, settle cloud save, grant purchases still pending
##   3. pause/resume from Horus (save, stop the game, mute), Android back closes popups
##   4. Horus.ready() once the first screen is drawn
##   5. lives (play needs a heart), Daily Gift, profile, language, shop, free coins, rate us
## The game itself is WoollyGame (3D, rules) + Hud (all UI).

const SKUS := ["starter_pack", "remove_ads"]
const PRODUCTS := {
	"starter_pack": {usd = 1.99, consumable = true},
	"remove_ads": {usd = 2.99, consumable = false},
}
const RC := {inter_every = 2, booster_price = 60, life_minutes = 20, refill_price = 100, free_coins = 25}

var store: HorusSaveStore
var S := {}
var game: WoollyGame
var hud: Hud
var _pending_level := -1   # PLAY / RETRY waiting for a heart (Refill Lives is open)
var _tick := 0.0


static func defaults() -> Dictionary:
	return {coins = 120, unlocked = 0, undo = 2, slot = 2, hint = 2, runs = 0, no_ads = false, buys = [],
		ads = Horus.monetize.pacing_state(),
		lives = Meta.MAX_LIVES, lives_t = 0.0, name = "", avatar = "W", frame = 0, frames = [0, 1, 2],
		daily = Horus.liveops.create_calendar(), seen_unlock = [], rated = false}


func _ready() -> void:
	I18n.setup()
	var lang := I18n.saved_lang()
	TranslationServer.set_locale(lang)
	game = WoollyGame.new()
	add_child(game)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.set_lang(lang)
	hud.show_splash()
	var shown_at := Time.get_ticks_msec()

	store = Horus.save_store({key = "woolly_road", defaults = func(): return defaults()})
	await Horus.start({skus = SKUS, rc_defaults = RC})
	store.restore_backup(Horus.save.backup)   # empty storage gets the app's copy back (new phone, reinstall)
	await Horus.cloud.settle_at_boot(HorusSaveStore.conflict_rules(store, {
		further = HorusSaveStore.further("unlocked", "coins"),
		merge = func(into, from): return HorusSaveStore.merge_purchases(into, from, {credit = _credit}),
		mirror = Horus.save.mirror,
		flush = Horus.save.flush,
	}))
	S = store.load()
	if str(S.get("name", "")) == "":
		S.name = Meta.default_name()

	game.setup(hud, store, S)
	_wire_hud()
	for p in await Horus.iap.pending():   # paid but not granted yet (the app closed mid-purchase)
		_grant(p)
	Horus.purchase.connect(func(p): if p.get("status", "ok") == "ok": _grant(p))   # restored / late purchases

	Horus.pause.connect(_on_pause)
	Horus.resume.connect(func(_d): game.paused_by_app = false)
	Horus.on_back(func(): return hud.handle_back())
	Horus.insets.connect(func(_d): _apply_insets())
	get_viewport().size_changed.connect(_apply_insets)
	_apply_insets()
	Horus.device.set_frame_rate(60)

	hud.set_no_ads(bool(S.get("no_ads", false)))
	for sku in SKUS:
		var p = Horus.iap.price(sku)
		hud.set_price(sku, str(p) if p else "")
	hud.set_booster_price(game.booster_price())
	hud.set_free_coins(_rc("free_coins"))
	_refresh_meta()
	game.go_home()
	Horus.ready()   # the first screen is on display (splash, then Home under it)
	var wait := 0.9 - (Time.get_ticks_msec() - shown_at) / 1000.0
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	hud.hide_splash()
	_offer_daily()


func _rc(k: String) -> int:
	return maxi(1, int(Horus.rc.number(k, float(RC[k]))))


func _now() -> float:
	return Time.get_unix_time_from_system()


func _wire_hud() -> void:
	hud.play_pressed.connect(func(): request_level(int(S.unlocked)))
	hud.level_picked.connect(request_level)
	hud.retry_pressed.connect(func(): request_level(game.level_index))
	hud.home_pressed.connect(func(): hud.transition(game.go_home))
	hud.next_pressed.connect(game.next_level)
	hud.booster_pressed.connect(game.use_booster)
	hud.booster_coins.connect(game.buy_booster_coins)
	hud.booster_ad.connect(game.buy_booster_ad)
	hud.continue_coins.connect(game.continue_with_slot)
	hud.continue_ad.connect(game.continue_with_ad)
	hud.give_up.connect(game.give_up)
	hud.double_reward.connect(func():
		await game.double_reward())
	hud.buy_starter.connect(func(): _buy("starter_pack"))
	hud.buy_remove_ads.connect(func(): _buy("remove_ads"))
	hud.restore_purchases.connect(func():
		var ok := await Horus.iap.restore()
		hud.toast(tr("Purchases restored") if ok else tr("Nothing to restore")))
	# lives
	hud.quit_level.connect(func():
		game.lose_life()
		hud.transition(game.go_home))
	hud.restart_level.connect(func():
		game.lose_life()
		_refresh_meta()
		if int(S.lives) > 0:
			var i := game.level_index
			hud.transition(func(): game.load_level(i, false))
		else:
			_pending_level = game.level_index
			game.go_home()
			hud.show_refill(_rc("refill_price")))
	hud.refill_ad.connect(_refill_with_ad)
	hud.refill_coins.connect(_refill_with_coins)
	hud.refill_closed.connect(func(): _pending_level = -1)
	# meta
	hud.daily_claim.connect(_claim_daily)
	hud.profile_save.connect(func(n, a, f):
		S.name = n
		S.avatar = a
		S.frame = f
		store.save(S)
		_refresh_meta()
		hud.toast(tr("Profile saved")))
	hud.frame_buy.connect(_buy_frame)
	hud.lang_pick.connect(func(code):
		I18n.apply(code)
		hud.set_lang(code)
		_refresh_meta()
		game._refresh_hud())
	hud.free_coins.connect(_free_coins)
	hud.cheat_win.connect(_cheat_win)
	hud.cheat_coins.connect(func(n: int):   # testers' cheat: no analytics, not a real earning
		S.coins = int(S.coins) + n
		store.save(S)
		game._refresh_hud()
		hud.set_coins(int(S.coins)))
	hud.shop_booster.connect(func(kind): game.buy_booster_coins(kind))
	hud.rate_done.connect(func(stars):
		S.rated = true
		store.save(S)
		if stars >= 4:
			await Horus.review()
		elif stars > 0:
			hud.toast(tr("Thanks for your feedback!")))


# ------------------------------------------------------------ lives
## Start a level if there is a heart, else open Refill Lives and start it once refilled.
func request_level(i: int) -> void:
	Meta.regen(S, _now(), _rc("life_minutes"))
	if int(S.lives) <= 0:
		_pending_level = i
		hud.toast(tr("No hearts left"))
		hud.show_refill(_rc("refill_price"))
		return
	_pending_level = -1
	hud.hide_panels()
	hud.transition(func(): game.load_level(i))


func _refill_with_ad() -> void:
	if Horus.ads.busy():
		return
	var r := await Horus.ads.rewarded("refill_life")
	if not r.ok:
		if r.reason != "busy":
			hud.toast(tr("No ad right now, try again soon"))
		return
	Horus.monetize.note_rewarded(S.ads, _now() * 1000.0)
	Meta.add_lives(S, 1, _now())
	Horus.an.log("lives_refill", {source = "ad", lives = int(S.lives)})
	_after_refill(tr("+1 heart!"))


func _refill_with_coins() -> void:
	var price := _rc("refill_price")
	if int(S.coins) < price:
		hud.toast(tr("Not enough coins"))
		hud.show_shop(false)
		return
	S.coins = int(S.coins) - price
	Horus.an.spend("coin", price, "lives")
	Meta.add_lives(S, Meta.MAX_LIVES, _now())
	Horus.an.log("lives_refill", {source = "coins", lives = int(S.lives)})
	_after_refill(tr("Hearts refilled!"))


func _after_refill(msg: String) -> void:
	store.save(S)
	game._refresh_hud()
	_refresh_meta()
	hud.close_refill()
	hud.toast(msg)
	if _pending_level >= 0:
		request_level(_pending_level)


func _process(delta: float) -> void:
	if S.is_empty():
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	var before := int(S.get("lives", Meta.MAX_LIVES))
	Meta.regen(S, _now(), _rc("life_minutes"))
	if int(S.lives) != before:
		store.save(S)
	hud.set_lives(int(S.lives), Meta.next_life_in(S, _now(), _rc("life_minutes")))


# ------------------------------------------------------------ daily gift, profile, coins
func _daily_info() -> Dictionary:
	return Horus.liveops.calendar_info(S.daily, Meta.DAILY)


func _offer_daily() -> void:
	if _daily_info().claimable:
		hud.show_daily(int(S.daily.day) % Meta.DAILY.size(), true)


func _claim_daily() -> void:
	var r = Horus.liveops.claim_calendar(S.daily, Meta.DAILY)
	if r == null:
		return
	var reward: Dictionary = r.reward
	var coins := Meta.give_daily(S, reward)
	if coins > 0:
		Horus.an.earn("coin", coins, "daily_gift")
	Horus.an.log("daily_gift", {day = int(r.day)})
	store.save(S)
	game._refresh_hud()
	_refresh_meta()
	hud.toast(tr("+%d coins!") % coins if coins > 0 else tr("+1 booster!"))
	await get_tree().create_timer(0.7).timeout
	hud.close_daily()


func _buy_frame(i: int) -> void:
	if int(S.coins) < Meta.FRAME_PRICE:
		hud.toast(tr("Not enough coins"))
		hud.show_shop(false)
		return
	S.coins = int(S.coins) - Meta.FRAME_PRICE
	Horus.an.spend("coin", Meta.FRAME_PRICE, "frame")
	S.frames = S.frames + [i]
	store.save(S)
	game._refresh_hud()
	_refresh_meta()
	hud._prof_pick(i)
	hud.toast(tr("Frame unlocked!"))


## Cheat "WIN LEVEL": in a level it wins it on the spot; on Home it marks the next level as beaten.
func _cheat_win() -> void:
	if game.mode == WoollyGame.Mode.MENU:
		S.unlocked = mini(Levels.count() - 1, int(S.unlocked) + 1)
		store.save(S)
		hud.toast(tr("Level won (cheat)"))
		game.go_home()
	elif game.mode != WoollyGame.Mode.WON:
		game.force_win()


func _free_coins() -> void:
	if Horus.ads.busy():
		return
	var r := await Horus.ads.rewarded("free_coins")
	if not r.ok:
		if r.reason != "busy":
			hud.toast(tr("No ad right now, try again soon"))
		return
	Horus.monetize.note_rewarded(S.ads, _now() * 1000.0)
	var n := _rc("free_coins")
	S.coins = int(S.coins) + n
	Horus.an.earn("coin", n, "free_coins")
	store.save(S)
	game._refresh_hud()
	hud.set_coins(int(S.coins))
	hud.toast(tr("+%d coins!") % n)


func _refresh_meta() -> void:
	hud.set_profile(str(S.name), str(S.avatar), int(S.frame), S.frames, int(S.unlocked) + 1)
	hud.set_coins(int(S.coins))
	Meta.regen(S, _now(), _rc("life_minutes"))
	hud.set_lives(int(S.lives), Meta.next_life_in(S, _now(), _rc("life_minutes")))
	var info := _daily_info()
	hud.set_daily(int(S.daily.day) % Meta.DAILY.size(), bool(info.claimable))


# ------------------------------------------------------------ purchases
func _buy(sku: String) -> void:
	if sku == "remove_ads" and S.get("no_ads", false):
		hud.toast(tr("Ads are already removed"))
		return
	var r := await Horus.iap.buy(sku)
	match r.get("status", ""):
		"ok": _grant(r)
		"pending": hud.toast(tr("Payment pending..."))
		"cancel": pass
		"invalid": hud.toast(tr("This purchase could not be verified"))
		_: hud.toast(tr("Purchase failed, try again later"))


## Give the goods once per token, save, then finish (goods first, finish after).
func _grant(p: Dictionary) -> void:
	var sku: String = p.get("sku", "")
	if not PRODUCTS.has(sku):
		return
	var token: String = str(p.get("token", ""))
	if not S.buys.any(func(b): return str(b.get("token", "")) == token):
		_credit(S, p)
		S.buys.append({sku = sku, token = token, t = Time.get_unix_time_from_system() * 1000.0})
		store.save(S)
		hud.set_no_ads(bool(S.no_ads))
		game.S = S
		game._refresh_hud()
		hud.toast(tr("Starter Pack added!") if sku == "starter_pack" else tr("Ads removed. Thank you!"))
	Horus.iap.finish({sku = sku, token = token, orderId = p.get("orderId", ""), consumable = PRODUCTS[sku].consumable, usd = PRODUCTS[sku].usd})


## What a purchase gives (also used when merging a cloud save's purchases). Returns the coins credited.
func _credit(s: Dictionary, b: Dictionary):
	match b.get("sku"):
		"starter_pack":
			s.coins = int(s.get("coins", 0)) + 500
			for k in ["undo", "slot", "hint"]:
				s[k] = int(s.get(k, 0)) + 3
			Horus.an.earn("coin", 500, "iap")
			return 500
		"remove_ads":
			s.no_ads = true
			return 0
	return false


# ------------------------------------------------------------ app lifecycle
func _on_pause(_d: Dictionary) -> void:
	store.flush()
	game.paused_by_app = true   # "bg": left the game; "ad": an ad covers it (nothing to mute yet: no audio)


func _apply_insets() -> void:
	var px := Horus.device.insets_px()
	var win := DisplayServer.window_get_size()
	var k := get_viewport().get_visible_rect().size.y / maxf(1.0, float(win.y))
	hud.apply_insets(px.top * k, px.bottom * k)
