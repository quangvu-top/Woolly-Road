extends Control
## Horus SDK for Godot: the sample game, the same as the web SDK's example/index.html. Coins, a rewarded ad (+10), a
## purchase (100 coins, granted once per token, finished after the save), the save with the app's copy and cloud save,
## a reminder when the player leaves. In the editor the SDK simulates the app (fake ads, test purchases); in the Horus
## app the same code shows MAX ads and Google Play's purchase sheet.

const SKU := "coins_100"

var store: HorusSaveStore
var game := {}
var coins_label: Label
var cloud_label: Label
var buy_button: Button
var log_label: Label
var _box: VBoxContainer


func _ready() -> void:
	_build_ui()
	# 1. A versioned local save; every write is also handed to the app as its backup copy (Horus.save.mirror).
	store = Horus.save_store({key = "demo", defaults = func(): return {coins = 0, buys = []}})

	# 2. Start once, before the first frame: cloud save, app info, Remote Config, store prices.
	await Horus.start({skus = [SKU]})
	store.restore_backup(Horus.save.backup)   # an empty storage gets the app's copy back (new phone, reinstall)
	# a save on the cloud that differs from this phone's: keep the one that went further, add the other's purchases
	await Horus.cloud.settle_at_boot(HorusSaveStore.conflict_rules(store, {
		further = HorusSaveStore.further("coins"),
		merge = func(into, from): return HorusSaveStore.merge_purchases(into, from, {credit = _credit}),
		mirror = Horus.save.mirror,
		flush = Horus.save.flush,
	}))
	game = store.load()
	_show()
	_log("Horus SDK %s trên %s%s" % [Horus.support.about.get_slice(": ", 1), Horus.target, " (giả lập)" if Horus.simulated else ""])

	# 3. Purchases paid but not granted yet (the app closed mid-purchase): grant them now.
	for p in await Horus.iap.pending():
		_grant(p)
	var price = Horus.iap.price(SKU)
	buy_button.text = "Mua 100 xu (%s)" % (price if price else "$0.99")

	# 4. The app pauses the game in the background ("bg": save now, plan the reminder) and under an ad ("ad": mute).
	Horus.pause.connect(_on_pause)
	Horus.resume.connect(func(_d): Horus.notif.cancel_all())
	Horus.cloud_event.connect(func(_c): _show_cloud())
	Horus.on_back(func(): return false)   # nothing to close: back leaves the game (the app goes to the background)
	Horus.insets.connect(func(_d): _apply_insets())
	_apply_insets()
	_show_cloud()
	Horus.ready()   # the game is on screen


func _credit(s: Dictionary, b: Dictionary):
	if b.get("sku") != SKU:
		return false
	s.coins += 100
	return 100


func _grant(p: Dictionary) -> void:
	if not game.buys.any(func(b): return b.token == p.token):   # not granted yet
		game.coins += 100
		game.buys.append({sku = p.sku, token = p.token, t = Time.get_unix_time_from_system() * 1000})
		store.save(game)                                         # goods in the save first...
		Horus.an.earn("coin", 100, "iap")
		_show()
	Horus.iap.finish({sku = p.sku, token = p.token, orderId = p.get("orderId", ""), consumable = true, usd = 0.99})   # ...then finish


func _rewarded() -> void:
	var r := await Horus.ads.rewarded("demo_coins")
	_log("rewarded: %s" % JSON.stringify(r))
	if not r.get("ok", false):
		return
	game.coins += 10
	store.queue(game)
	Horus.an.earn("coin", 10, "ad")
	_show()


func _buy() -> void:
	var r := await Horus.iap.buy(SKU)
	_log("buy: %s" % r.get("status", ""))
	if r.get("status") == "ok":
		_grant(r)


func _reset() -> void:
	game = store.wipe()
	Horus.an.log("reset")
	_show()


func _on_pause(d: Dictionary) -> void:
	store.flush()
	if d.get("reason") == "bg":
		# a reminder in 8 hours (the app shows it only when the player allowed notifications)
		Horus.notif.schedule([{id = "comeback", at = Time.get_unix_time_from_system() * 1000 + 8 * 3600 * 1000,
			title = "Xu đang chờ", body = "Vào xem quảng cáo nhận thêm 10 xu", channel = "comeback"}])


func _ask_notif() -> void:
	var ok := await Horus.notif.ask()
	_log("thông báo: %s" % ("được phép" if ok else "không"))


func _show() -> void:
	coins_label.text = "Xu: %d" % int(game.get("coins", 0))


func _show_cloud() -> void:
	cloud_label.text = "Cloud: " + Horus.cloud.status_text(await Horus.cloud.status())


## Keep clear of the camera cut-out and the gesture bar: the app gives them in dp, insets_px() in pixels.
func _apply_insets() -> void:
	var pad := Horus.device.insets_px()
	_box.offset_top = 32 + pad.top
	_box.offset_bottom = -(32 + pad.bottom)


func _log(s: String) -> void:
	log_label.text += s + "\n"
	print(s)


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 32)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	_box = box
	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 56)
	box.add_child(coins_label)
	for b in [["Xem quảng cáo: +10 xu", _rewarded], ["Mua 100 xu", _buy], ["Cho phép nhắc", _ask_notif], ["Chơi lại từ đầu", _reset]]:
		var button := Button.new()
		button.text = b[0]
		button.custom_minimum_size = Vector2(0, 96)
		button.add_theme_font_size_override("font_size", 32)
		button.pressed.connect(b[1])
		box.add_child(button)
		if b[1] == _buy:
			buy_button = button
	cloud_label = Label.new()
	cloud_label.add_theme_font_size_override("font_size", 26)
	box.add_child(cloud_label)
	log_label = Label.new()
	log_label.add_theme_font_size_override("font_size", 22)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(log_label)
	_show()
