class_name HudMeta
extends HudKit
## Meta screens from the Figma "Bus Dash" UI section (frame ids in docs/UX_FLOW.md):
##   S01 Loading, S16 Loading between scenes, S03 Daily Gift, S04 Profile, S05 Change name, S06 name changed,
##   S08 Language, S09 Privacy Policy, S10 Refill Lives, S11 Full of Heart, S12 Starter Pack, S13 No Ads,
##   S14 Shop, S18 New booster unlocked, S22/S23 lose-a-heart confirms, S28 Ads break, S29 Rate us.
## Screens only emit signals; main.gd / game.gd decide what happens (lives, coins, purchases, ads).

signal daily_claim
signal profile_save(name: String, avatar: String, frame: int)
signal frame_buy(i: int)
signal lang_pick(code: String)
signal refill_ad
signal refill_coins
signal refill_closed
signal free_coins
signal shop_booster(kind: String)
signal quit_level
signal restart_level
signal unlock_done
signal rate_done(stars: int)
signal buy_starter
signal buy_remove_ads
signal restore_purchases

const BOOSTER_ICON := {"undo": "ic_booster_uturn", "slot": "ic_plus", "hint": "ic_hand"}
const BOOSTER_NAME := {"undo": "Undo", "slot": "+1 Road", "hint": "Hint"}
const BOOSTER_DESC := {
	"undo": "Take back your last sheep.",
	"slot": "One more space on the road.",
	"hint": "Shows the best sheep to send.",
}
const PRIVACY_URL := ""   # TODO: same https:// link as privacyUrl in horus-game.json / the store listing

var _splash: Control
var _splash_bar: Control
var _curtain: Control
var _curtain_busy := false
var _daily: Control
var _daily_rows: Array = []
var _profile: Control
var _prof := {name = "", avatar = "W", frame = 0, owned = [0, 1, 2], best = 1, tab = 0}
var _prof_ui := {}
var _rename: Control
var _rename_edit: LineEdit
var _rename_err: Label
var _renamed: Control
var _language: Control
var _lang := "en"
var _lang_btns := {}
var _privacy: Control
var _refill: Control
var _refill_count: Label
var _refill_timer: Label
var _refill_price: Label
var _full_heart: Control
var _starter: Control
var _no_ads: Control
var _shop: Control
var _shop_nav: Control
var _shop_close: Control
var _shop_scroll: ScrollContainer
var _shop_noads_btn: Control
var _unlock: Control
var _unlock_ui := {}
var _quit_confirm: Control
var _restart_confirm: Control
var _ads_break: Control
var _rate: Control
var _rate_stars: Array[Control] = []
var _rating := 5
var _price_labels := {"starter_pack": [], "remove_ads": []}
var _coin_texts: Array[Label] = []
var _booster_price := 60
var _booster_price_labels: Array[Label] = []
var _free_coins_label: Label
var _lives := Meta.MAX_LIVES
var _life_secs := 0.0


func _build_meta() -> void:
	_build_daily()
	_build_profile()
	_build_rename()
	_build_renamed()
	_build_language()
	_build_privacy()
	_build_refill()
	_build_full_heart()
	_build_starter()
	_build_no_ads()
	_build_shop()
	_build_unlock()
	_quit_confirm = _build_confirm("QuitConfirm", "Are you sure?", "QUIT", "btn_red", RED_INK, func(): quit_level.emit())
	_restart_confirm = _build_confirm("RestartConfirm", "Are you sure?", "RETRY", "btn_green", GREEN_INK, func(): restart_level.emit())
	_build_ads_break()
	_build_rate()


## Splash and the scene curtain live in _top so they cover every popup.
func _build_top_layers() -> void:
	_build_splash()
	_build_curtain()


# ============================================================ S01 Loading
func _build_splash() -> void:
	# Figma loading 2072:2246: "UI loading" background | logo 141,81 600x600 | art in the middle |
	# "Loading..." 337,1558 228x64 | bar track 155,1638 582x70 with the green fill 7px inside
	_splash = _full(_top, "Splash")
	_splash.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover(_splash, "bg_loading", Color("#4a86ec"))
	var glow := _img(_splash, "unlock_glow", Color(1, 1, 1, 0.2))
	_frame(glow, Vector2(93, 680), Vector2(700, 700))
	var flock := _flock(_splash, Vector2.ZERO, 560)
	_frame(flock, Vector2(163, 760), Vector2(560, 560))
	var title := _label(_splash, "Woolly\nRoad", 150, Color.WHITE, BLUE, 6)
	_frame(title, Vector2(43, 170), Vector2(800, 420))
	(title.label_settings as LabelSettings).line_spacing = -30
	var lt := _label(_splash, "Loading...", 56, Color.WHITE, BLUE, 3)
	_frame(lt, Vector2(243, 1550), Vector2(400, 80))
	var track := _img(_splash, "bar_track", Color("#2f3f9a"))
	_frame(track, Vector2(155, 1638), Vector2(582, 70))
	_splash_bar = _img(track, "bar_fill", Color("#7be33a"))
	_xy(_splash_bar, Vector2(7, 8), Vector2(60, 54))
	_splash.visible = false


func show_splash() -> void:
	_splash.visible = true
	_splash.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_splash_bar, "size:x", 400.0, 1.2).set_trans(Tween.TRANS_SINE)


func hide_splash() -> void:
	if not _splash.visible:
		return
	var tw := create_tween()
	tw.tween_property(_splash_bar, "size:x", 568.0, 0.25)
	tw.tween_property(_splash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _splash.visible = false)


func splash_open() -> bool:
	return _splash.visible


# ============================================================ S16 Loading between scenes
func _build_curtain() -> void:
	# Figma loading between scene 1550:6505: the blue "UI loading" pattern, one picture in the middle
	# (bus_loading 104,553 694x694; here a sheep), no text
	_curtain = _full(_top, "Curtain")
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover(_curtain, "bg_loading", Color("#4a86ec"))
	var sheep := Control.new()
	sheep.name = "Sheep"
	sheep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.add_child(sheep)
	_frame(sheep, Vector2(231, 688), Vector2(424, 424))
	_sheep_face(sheep, Vector2(424, 424), Art.wool("W"), false)
	_curtain.visible = false


## Cover the screen, run `cb` (build the level) under the cover, then reveal.
func transition(cb: Callable) -> void:
	if _curtain_busy:
		cb.call()
		return
	_curtain_busy = true
	_curtain.visible = true
	_curtain.modulate.a = 0.0
	var sheep: Control = _curtain.get_node("Sheep")
	sheep.pivot_offset = sheep.size / 2.0
	var tw := create_tween()
	tw.tween_property(_curtain, "modulate:a", 1.0, 0.18)
	tw.tween_callback(cb)
	tw.tween_property(sheep, "position:y", sheep.position.y - 60, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sheep, "position:y", sheep.position.y, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_curtain, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		_curtain.visible = false
		_curtain_busy = false)


# ============================================================ S03 Daily Gift
func _build_daily() -> void:
	# Figma popup 4902:2802: art 121,207 644x500 | board 64,522 759x977 | title 205,438 476x171 | close 733,560
	_daily = _overlay("DailyGift")
	var root := _full(_daily, "Content")
	var glow := _img(root, "unlock_glow", Color(1, 1, 1, 0.2))
	_frame(glow, Vector2(171, 150), Vector2(544, 544))
	var pile := _img(root, "coin_pile", Color("#ffc93c"))
	_frame(pile, Vector2(298, 380), Vector2(290, 195))
	var fl := _flock(root, Vector2.ZERO, 360)
	_frame(fl, Vector2(263, 150), Vector2(360, 360))
	var board := _img(root, "dg_board", Color("#3cbdf8"))
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame(board, Vector2(64, 522), Vector2(759, 977))
	# inner board 101,795 686x643 | day 1 on top: cell 128,624 629x140 | days 2-5: cells 269,824 488x128 every 148 |
	# star track 145,850 (gold star, bar 180..197, dark star slots on the later days) | CLAIM 193x85 in the right half
	var inner := _img(board, "dg_inner", Color("#1e7fe0"))
	_xy(inner, Vector2(37, 273), Vector2(686, 643))
	var title := _img(root, "dg_title", Color("#ffc93c"))
	_frame(title, Vector2(205, 438), Vector2(476, 171))
	var tl := _label(title, "DAILY GIFT", 64, Color.WHITE, YELLOW_INK, 3)
	tl.offset_top = 40
	var close := _btn(root, "ic_close", BLUE, _close_of(_daily))
	_frame(close, Vector2(725, 552), Vector2(64, 64))
	var bar := _panel(board, Color("#1449a6"), 8)
	_xy(bar, Vector2(116, 371), Vector2(17, 472))
	for i in Meta.DAILY.size():
		var big := i == 0
		var size := Vector2(629, 140) if big else Vector2(488, 128)
		var row := _panel(board, Color("#fff8e8"), 30, Color("#ff9a2e") if big else Color("#ffcc33"), 8)
		_xy(row, Vector2(64, 102) if big else Vector2(205, 302 + (i - 1) * 148), size)
		var half := 397.0 if big else 256.0   # dashed divider between the reward and the button
		for k in int(size.y / 16.0) - 1:
			var dash := ColorRect.new()
			dash.color = Color("#e6c48f")
			dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(dash)
			_xy(dash, Vector2(half - 1.5, 12 + k * 16), Vector2(3, 8))
		var reward: Dictionary = Meta.DAILY[i]
		var kind: String = reward.keys()[0]
		var ic := _img(row, "coin_pile" if kind == "coins" else BOOSTER_ICON[kind], Color("#ffc93c"))
		_xy(ic, Vector2(56, 26) if big else Vector2(34, 22), Vector2(86, 86))
		var amt := _label(row, str(int(reward[kind])), 54, Color.WHITE, BLUE, 3)
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		amt.autowrap_mode = TextServer.AUTOWRAP_OFF
		_xy(amt, Vector2(166 if big else 128, 0), Vector2(200, size.y))
		var right := Vector2(half + (size.x - half) / 2.0, size.y / 2.0)   # centre of the button half
		var check := _img(row, "ic_check", Color("#5cc24a"))
		_xy(check, right - Vector2(50, 46), Vector2(100, 92))
		var claim := _text_btn(row, "btn_green", "CLAIM", GREEN_INK, right - Vector2(96, 43), Vector2(193, 85), func(): daily_claim.emit(), 40)
		var locked := _text_btn(row, "btn_grey", "CLAIM", BLUE, right - Vector2(96, 43), Vector2(193, 85), func(): pass, 40)
		locked.set_meta("disabled", true)
		var lock := _img(locked, "ic_lock", Color("#ffc93c"))
		_xy(lock, Vector2(160, -16), Vector2(44, 44))
		var later := _label(row, "Tomorrow", 34, Color("#7d8bb0"))
		_xy(later, Vector2(half, 0), Vector2(size.x - half, size.y))
		var star: Control = null
		if not big:   # progress star on the track, level with its row
			star = _img(board, "ic_star", Color("#ffc93c"))
			_xy(star, Vector2(81, 302 + (i - 1) * 148 + 22), Vector2(85, 84))
		_daily_rows.append({row = row, check = check, claim = claim, locked = locked, later = later, star = star})


## `next_i`: the cycle day that can be claimed next (0-based); claimable = not taken today.
func show_daily(next_i: int, claimable: bool) -> void:
	for i in _daily_rows.size():
		var r: Dictionary = _daily_rows[i]
		var done := i < next_i
		var today := i == next_i
		r.check.visible = done
		r.claim.visible = today and claimable
		r.later.visible = today and not claimable
		r.locked.visible = i > next_i
		if r.star:
			(r.star as CanvasItem).modulate = Color.WHITE if i <= next_i else Color(0.08, 0.27, 0.62)
	_show(_daily)


func daily_open() -> bool:
	return is_open(_daily)


func close_daily() -> void:
	_hide(_daily)


# ============================================================ S04 Profile / S05 Change name / S06 notify
func _build_profile() -> void:
	# Figma Profile 1785:2033: popup 66,406 752x1084 | avatar 117,186 152 | name pill 295,198 350x72 |
	# tabs y=372 (279x94 at 105 / 384) | grid 57,458 643x444 | SAVE 213,888
	_profile = _std_popup("Profile", "Profile", 1084, 406)
	var panel: Control = _profile.get_meta("panel")
	var av := Control.new()
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(av)
	_xy(av, Vector2(117, 186), Vector2(152, 152))
	_prof_ui.avatar = av
	var pill := _panel(panel, Color("#c8d4ee"), 30)
	_xy(pill, Vector2(295, 198), Vector2(350, 72))
	var nm := _label(pill, "", 38, BLUE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_xy(nm, Vector2(30, 0), Vector2(250, 72))
	_prof_ui.name = nm
	var edit := _btn(pill, "ic_edit", BLUE, func(): _open_rename())
	_xy(edit, Vector2(282, 12), Vector2(48, 48))
	var best := _label(panel, "", 36, BLUE)   # where Figma has "UID: 66666666" (299,279 273x48)
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	best.autowrap_mode = TextServer.AUTOWRAP_OFF
	_xy(best, Vector2(299, 279), Vector2(420, 48))
	_prof_ui.best = best
	var area := _inset(panel, Vector2(29, 458), Vector2(700, 410))
	area.mouse_filter = Control.MOUSE_FILTER_PASS
	_prof_ui.tabs = []
	for t in 2:
		var ti := t
		var tab := _btn(panel, "", Color(0, 0, 0, 0), func(): _prof_tab(ti))
		_xy(tab, Vector2(105 + t * 279, 372), Vector2(279, 94))
		var bg := _panel(tab, Color("#d3dcef"), 30)
		var sbt: StyleBoxFlat = bg.get_theme_stylebox("panel")
		sbt.corner_radius_bottom_left = 0   # folder tab: the picked one runs into the box under it
		sbt.corner_radius_bottom_right = 0
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_label(tab, "Avatar" if t == 0 else "Frame", 52, Color.WHITE, BLUE, 3)
		_prof_ui.tabs.append(bg)
	_prof_ui.cells = []
	for i in 6:   # Figma cells 152x152 at x 119/304/487, y 494/679 (popup coordinates), orange rim
		var ii := i
		var cell := _btn(panel, "", Color(0, 0, 0, 0), func(): _prof_pick(ii))
		_xy(cell, Vector2([119, 304, 487][i % 3], 494 + (i / 3) * 185), Vector2(152, 152))
		var bg := _panel(cell, Color("#ffa53a"), 32, Color("#ffc46b"), 5)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var face := Control.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(face)
		_xy(face, Vector2(12, 12), Vector2(128, 128))
		var lock := _img(cell, "ic_lock", Color("#ffc93c"))
		_xy(lock, Vector2(40, 22), Vector2(72, 72))
		var price := _label(cell, str(Meta.FRAME_PRICE), 34, Color.WHITE, BLUE, 2)
		_xy(price, Vector2(0, 92), Vector2(152, 50))
		var tick := _img(cell, "ic_check", Color("#5cc24a"))
		_xy(tick, Vector2(100, 104), Vector2(62, 52))
		_prof_ui.cells.append({bg = bg, face = face, lock = lock, price = price, tick = tick})
	_text_btn(panel, "btn_green", "SAVE", GREEN_INK, Vector2(213, 888), Vector2(332, 162), func():
		_hide(_profile)
		profile_save.emit(_prof.name, _prof.avatar, int(_prof.frame)))


## Draw an avatar (sheep face in a tinted frame) into `holder` (any size).
func _avatar_into(holder: Control, wool: String, frame: int) -> void:
	for c in holder.get_children():
		c.queue_free()
	var s := holder.size
	var fr := _img(holder, "avatar_frame", Meta.FRAMES[frame])
	fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if frame != 0:
		fr.modulate = Meta.FRAMES[frame].lightened(0.25) * Color(1.6, 1.6, 1.6)
	var face := Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)
	_xy(face, s * 0.06, s * 0.88)
	_sheep_face(face, s * 0.78, Art.wool(wool))


func show_profile() -> void:
	_prof.tab = 0
	_prof_refresh()
	_show(_profile)


func set_profile(name: String, avatar: String, frame: int, owned: Array, best_level: int) -> void:
	if not is_open(_profile):   # keep unsaved picks while the popup is open
		_prof.name = name
		_prof.avatar = avatar
		_prof.frame = frame
	_prof.owned = owned.duplicate()
	_prof.best = best_level
	_prof_refresh()


func _prof_tab(t: int) -> void:
	_prof.tab = t
	_prof_refresh()


func _prof_pick(i: int) -> void:
	if _prof.tab == 0:
		_prof.avatar = Meta.AVATARS[i]
	elif i in _prof.owned:
		_prof.frame = i
	else:
		frame_buy.emit(i)
		return
	_prof_refresh()


func _prof_refresh() -> void:
	if _prof_ui.is_empty():
		return
	_prof_ui.name.text = _prof.name
	_prof_ui.best.text = tr("Best: Level %d") % int(_prof.best)
	_avatar_into(_prof_ui.avatar, _prof.avatar, int(_prof.frame))
	for t in 2:   # Figma: picked tab = the box colour, the other a darker blue-grey
		(_prof_ui.tabs[t] as Panel).get_theme_stylebox("panel").bg_color = Color("#d3dcef") if _prof.tab == t else Color("#a6b6dc")
	for i in 6:
		var c: Dictionary = _prof_ui.cells[i]
		var on: bool = (_prof.avatar == Meta.AVATARS[i]) if _prof.tab == 0 else (int(_prof.frame) == i)
		var locked: bool = _prof.tab == 1 and not (i in _prof.owned)
		c.tick.visible = on
		c.lock.visible = locked
		c.price.visible = locked
		c.face.size = Vector2(128, 128)
		if _prof.tab == 0:
			_avatar_into(c.face, Meta.AVATARS[i], int(_prof.frame))
		else:
			_avatar_into(c.face, _prof.avatar, i)
		c.face.modulate = Color(1, 1, 1, 0.45) if locked else Color.WHITE


func _build_rename() -> void:
	# Figma change name 1792:2436: inset 26,166 700x279 | hint 67,212 617x84 | field 65,320 621x76 | OK 210,459
	_rename = _std_popup("Rename", "Change name", 652, 574)
	var panel: Control = _rename.get_meta("panel")
	_inset(panel, Vector2(26, 166), Vector2(700, 279))
	var hint := _label(panel, "Enter a nickname (3-14 characters), containing only English letters, numbers, underscores, periods, hyphens, and no other special characters.", 25, BLUE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	(hint.label_settings as LabelSettings).line_spacing = -3
	_xy(hint, Vector2(66, 212), Vector2(620, 96))
	var field := LineEdit.new()
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.max_length = 14
	field.add_theme_font_override("font", _font)
	field.add_theme_font_size_override("font_size", 42)
	field.add_theme_color_override("font_color", Color.WHITE)
	field.add_theme_color_override("caret_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#7f97cf")
	sb.set_corner_radius_all(38)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	field.add_theme_stylebox_override("normal", sb)
	field.add_theme_stylebox_override("focus", sb)
	panel.add_child(field)
	_xy(field, Vector2(65, 320), Vector2(621, 76))
	field.text_submitted.connect(func(_t): _rename_ok())
	_rename_edit = field
	_rename_err = _label(panel, "", 26, Color("#e8463f"))
	_xy(_rename_err, Vector2(40, 398), Vector2(672, 44))
	_text_btn(panel, "btn_green", "OK", GREEN_INK, Vector2(210, 459), Vector2(332, 162), _rename_ok)


func _open_rename() -> void:
	_rename_edit.text = _prof.name
	_rename_err.text = ""
	_show(_rename)


func _rename_ok() -> void:
	var n := _rename_edit.text.strip_edges()
	if not Meta.valid_name(n):
		_rename_err.text = tr("3-14 letters, numbers, _ . - only")
		return
	_prof.name = n
	_rename_edit.release_focus()
	_hide(_rename)
	_prof_refresh()
	_show(_renamed)


func _build_renamed() -> void:
	# Figma notify 1792:2479
	_renamed = _std_popup("Renamed", "Change name", 652, 574)
	var panel: Control = _renamed.get_meta("panel")
	var inset := _inset(panel, Vector2(26, 179), Vector2(700, 266))
	_label(inset, "Changed name successfully!", 42, BLUE)
	_text_btn(panel, "btn_green", "OK", GREEN_INK, Vector2(210, 466), Vector2(332, 162), _close_of(_renamed))


# ============================================================ S08 Language / S09 Privacy Policy
func _build_language() -> void:
	# Figma Language 1550:4384: popup top 452, a 2-column list of language buttons (first row 124..420 / 450..756,
	# y 652..776), SAVE under it. Woolly Road has two languages, so the popup keeps that one row and ends after it.
	_language = _std_popup("Language", "Language", 572, 452)
	var panel: Control = _language.get_meta("panel")
	_inset(panel, Vector2(26, 185), Vector2(700, 180))
	var opts := [["en", "English"], ["vi", "Tiếng Việt"]]
	for i in opts.size():
		var code: String = opts[i][0]
		var b := _text_btn(panel, "btn_blue", opts[i][1], BLUE, Vector2(57 + i * 326, 200), Vector2(306, 134), func():
			_lang_mark(code), 48)
		var l: Label = b.get_meta("label")
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		if code == "vi":   # always draw the Vietnamese name with a font that has its letters
			var ls: LabelSettings = l.label_settings.duplicate()
			ls.font = _system_bold
			ls.font_size = 44
			l.label_settings = ls
		_lang_btns[code] = b
	_language.set_meta("on_show", func(): _lang_mark(_lang))
	_text_btn(panel, "btn_green", "SAVE", GREEN_INK, Vector2(210, 386), Vector2(332, 162), func():
		_hide(_language)
		lang_pick.emit(_language.get_meta("pick", _lang)))


func _lang_mark(code: String) -> void:
	_language.set_meta("pick", code)
	for k in _lang_btns:
		var b: Control = _lang_btns[k]
		var tex := _tex("btn_blue" if k == code else "btn_grey")   # Figma: the picked language is blue
		var bg = b.get_meta("bg")
		if bg is _NinePatchHolder and tex:
			(bg as _NinePatchHolder)._np.texture = tex


func set_lang(code: String) -> void:
	_lang = code
	set_ui_font(code)


func _build_privacy() -> void:
	# Figma privacy policy 1785:1631: question in the inset, NO (red) | YES (green)
	_privacy = _std_popup("Privacy", "Privacy Policy", 652, 574)
	var panel: Control = _privacy.get_meta("panel")
	var inset := _inset(panel, Vector2(26, 179), Vector2(700, 266))
	_label(inset, "Do you want to read\nthe Privacy Policy?", 44, BLUE)
	_text_btn(panel, "btn_red", "NO", RED_INK, Vector2(44, 466), Vector2(332, 162), _close_of(_privacy))
	_text_btn(panel, "btn_green", "YES", GREEN_INK, Vector2(376, 466), Vector2(332, 162), func():
		_hide(_privacy)
		if PRIVACY_URL == "":
			toast("Privacy policy link is not set yet")
		else:
			OS.shell_open(PRIVACY_URL))


func show_privacy() -> void:
	_show(_privacy)


# ============================================================ S10 Refill Lives / S11 Full of Heart
func _build_refill() -> void:
	# Figma refill lives 1550:4752: heart 100,205 220 | "Next lives in" 344,247 | timer 344,308 167x76 |
	# Watch Ads 44,466 | Refill [coin] 100 at 376,466
	_refill = _std_popup("RefillLives", "Refill Lives", 652, 574, func():
		_hide(_refill)
		refill_closed.emit())
	var panel: Control = _refill.get_meta("panel")
	_inset(panel, Vector2(26, 179), Vector2(700, 266))
	_refill_count = _heart(panel, Vector2(100, 205), 220, "0")
	var nl := _label(panel, "Next lives in", 44, BLUE)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_xy(nl, Vector2(344, 247), Vector2(360, 52))
	var tp := _panel(panel, Color("#8396cc"), 38)
	_xy(tp, Vector2(344, 308), Vector2(167, 76))
	_refill_timer = _label(tp, "20:00", 42, Color.WHITE, BLUE, 2)
	_refill_timer.autowrap_mode = TextServer.AUTOWRAP_OFF
	_ads_btn(panel, Vector2(44, 466), Vector2(332, 162), func(): refill_ad.emit())
	# "Refill [coin] 100" (Figma: the word, the coin, the price in one green button)
	var rb := _text_btn(panel, "btn_green", "", GREEN_INK, Vector2(376, 466), Vector2(332, 162), func(): refill_coins.emit())
	var rw := _label(rb, "Refill", 46, Color.WHITE, GREEN_INK, 3)
	rw.autowrap_mode = TextServer.AUTOWRAP_OFF
	rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_xy(rw, Vector2(0, 0), Vector2(142, 150))
	var coin := _img(rb, "ic_gold", Color("#ffc93c"))
	_xy(coin, Vector2(146, 46), Vector2(62, 62))
	_refill_price = _label(rb, "100", 54, Color.WHITE, GREEN_INK, 3)
	_refill_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_refill_price.autowrap_mode = TextServer.AUTOWRAP_OFF
	_xy(_refill_price, Vector2(212, 0), Vector2(120, 150))


func show_refill(price: int) -> void:
	_refill_price.text = str(price)
	_refresh_lives_ui()
	_show(_refill)


func close_refill() -> void:
	_hide(_refill)


func _build_full_heart() -> void:
	# Figma full heart 1792:2534
	_full_heart = _std_popup("FullHeart", "Full of Heart", 652, 574)
	var panel: Control = _full_heart.get_meta("panel")
	_inset(panel, Vector2(26, 179), Vector2(700, 266))
	_heart(panel, Vector2(100, 205), 220, str(Meta.MAX_LIVES))
	var t := _label(panel, "Full Heart", 46, BLUE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_xy(t, Vector2(344, 272), Vector2(360, 80))
	_text_btn(panel, "btn_green", "Continue", GREEN_INK, Vector2(210, 466), Vector2(332, 162), _close_of(_full_heart), 50)


## Lives pill on Home: tap -> Refill Lives (or Full of Heart when full).
func _lives_pressed() -> void:
	if _lives >= Meta.MAX_LIVES:
		_show(_full_heart)
	else:
		show_refill(int(_refill_price.text))


func set_lives(n: int, secs: float) -> void:
	_lives = n
	_life_secs = secs
	_refresh_lives_ui()


func _refresh_lives_ui() -> void:
	if _refill_count:
		_refill_count.text = str(_lives)
		_refill_timer.text = Meta.fmt_time(_life_secs) if _lives < Meta.MAX_LIVES else tr("Full")


# ============================================================ S12 Starter Pack / S13 No Ads
func _build_starter() -> void:
	# Figma popup_starterpack 2252:2149 (measured on the frame): gift art above the ribbon (y 210..350) |
	# ribbon 60..825, text centre y 405 | card 65..822 x 490..1470 (white rim) | close on the ribbon tail at 746,472 |
	# contents box 143,1241 601x179 (dark, see-through) | price button 278,1496 332x162 under the card
	_starter = _overlay("StarterPack")
	var root := _full(_starter, "Content")
	var top_glow := _img(root, "unlock_glow", Color(1, 1, 1, 0.2))
	_frame(top_glow, Vector2(243, 90), Vector2(400, 400))
	var gift := _img(root, "coin_pile", Color("#ffc93c"))
	_frame(gift, Vector2(318, 196), Vector2(250, 168))
	var card := _img(root, "dg_board", Color("#3cbdf8"))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame(card, Vector2(65, 490), Vector2(757, 980))
	var glow := _img(card, "unlock_glow", Color(1, 1, 1, 0.2))
	_xy(glow, Vector2(78, 90), Vector2(600, 600))
	var fl := _flock(card, Vector2(378, 360), 460, ["O", "L", "W"])
	fl.name = "Flock"
	var pile := _img(card, "coin_pile", Color("#ffc93c"))
	_xy(pile, Vector2(228, 500), Vector2(300, 202))
	var box := _panel(card, Color(0.05, 0.08, 0.2, 0.45), 40)
	_xy(box, Vector2(78, 751), Vector2(601, 179))
	var items := [["ic_gold", "500"], ["ic_booster_uturn", "x3"], ["ic_plus", "x3"], ["ic_hand", "x3"]]
	for i in items.size():
		_item(box, items[i][0], items[i][1], BLUE, Vector2(36 + i * 140, 14), 100.0, 46.0)
	var ribbon := _img(root, "ribbon_red", Color("#ff3a60"))
	_frame(ribbon, Vector2(57, 342), Vector2(772, 209))
	var rt := _label(ribbon, "STARTER PACK", 64, Color.WHITE, RED_INK, 3)
	_xy(rt, Vector2(66, 18), Vector2(640, 90))
	var close := _btn(root, "", Color(0, 0, 0, 0), _close_of(_starter))
	_frame(close, Vector2(706, 432), Vector2(80, 80))
	_label(close, "X", 60, Color("#9e1030"))
	var buy := _text_btn(root, "btn_green", "$1.99", GREEN_INK, Vector2.ZERO, Vector2(332, 162), func():
		_hide(_starter)
		buy_starter.emit(), 60)
	_frame(buy, Vector2(278, 1496), Vector2(332, 162))
	_price_labels.starter_pack.append(buy.get_meta("label"))


func show_starter() -> void:
	_show(_starter)


func _build_no_ads() -> void:
	# Figma popup_noads 1792:2505: ribbon 58,304 770x208 | ADS card 29,517 829x288 | bundle 29,860 | "No, thanks!" y=1340
	_no_ads = _overlay("NoAds")
	var root := _full(_no_ads, "Content")
	var ribbon := _img(root, "ribbon_noads", Color("#ff3a60"))
	_frame(ribbon, Vector2(58, 304), Vector2(770, 208))
	var holder := _full(root, "Cards")   # centred like the Figma frame
	_frame(holder, Vector2(0, 0), Vector2(FW, FH))
	var buy := _noads_card(holder, Vector2(30, 515), false)
	buy.set("on_press", func():
		_hide(_no_ads)
		buy_remove_ads.emit())
	# Figma "Remove Ads Bundle" card 30,850 828x440: yellow top with the art and two boxes, orange strip with the
	# name and the price. Woolly Road puts its Starter Pack there (the price button buys it).
	var pack := _card(holder, Vector2(30, 850), Vector2(828, 440), Color("#ffc61a"), Color("#ff8a1a"), 140)
	pack.mouse_filter = Control.MOUSE_FILTER_STOP
	_bundle_top(pack, Color("#f0a01a"), YELLOW_INK)
	var pb := _card_footer(pack, "STARTER PACK", Color("#b4470a"), 140, "$1.99", func():
		_hide(_no_ads)
		buy_starter.emit(), Vector2(258, 91))
	_price_labels.starter_pack.append(pb.get_meta("label"))
	var no := _btn(root, "", Color(0, 0, 0, 0), _close_of(_no_ads))
	_frame(no, Vector2(293, 1317), Vector2(300, 90))
	_label(no, "No, thanks!", 44, Color.WHITE)


## Figma "Remove Ads" card (popup_noads 1792:2505 and Shop): 828x290, ADS badge 220 at 58,23,
## "Remove Ads include:" at x 305, price button 258x90 at 520,168. Returns the price button.
func _noads_card(parent: Control, pos: Vector2, in_scroll: bool) -> Control:
	var card := _card(parent, pos, Vector2(828, 290), Color("#45bdff"), Color(), 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE if in_scroll else Control.MOUSE_FILTER_STOP
	var ic := _img(card, "ic_noads", Color("#e8463f"))
	_xy(ic, Vector2(58, 23), Vector2(220, 220))
	var tx := _label(card, "Remove Ads include:\n• Break ads\n• Banner ads", 40, Color.WHITE, BLUE, 3)
	tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tx.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tx.autowrap_mode = TextServer.AUTOWRAP_OFF
	(tx.label_settings as LabelSettings).line_spacing = 12
	_xy(tx, Vector2(305, 40), Vector2(500, 190))
	var buy := _text_btn(card, "btn_green", "$2.99", GREEN_INK, Vector2(520, 168), Vector2(258, 90), func(): pass, 44)
	_price_labels.remove_ads.append(buy.get_meta("label"))
	return buy


## Top half of the bundle card: the art on the left, a coin box and a booster box (Figma 325,50 132x190 and
## 473,50 302x190, darker rounded boxes).
func _bundle_top(card: Panel, box_color: Color, ink: Color) -> void:
	var glow := _img(card, "unlock_glow", Color(1, 1, 1, 0.2))
	_xy(glow, Vector2(10, -10), Vector2(300, 300))
	var fl := _flock(card, Vector2(160, 120), 250, ["O", "L", "W"])
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pile := _img(card, "coin_pile", Color("#ffc93c"))
	_xy(pile, Vector2(60, 170), Vector2(180, 100))
	var cb := _tile(card, Vector2(325, 50), Vector2(132, 190), box_color)
	_item(cb, "ic_gold", "500", ink, Vector2(22, 26), 88.0, 44.0)
	var bb := _tile(card, Vector2(473, 50), Vector2(302, 190), box_color)
	var icons := ["ic_booster_uturn", "ic_plus", "ic_hand"]
	for i in 3:
		_item(bb, icons[i], "x3", ink, Vector2(14 + i * 94, 30), 84.0, 40.0)


func show_no_ads() -> void:
	_show(_no_ads)


## Store prices (Horus.iap.price) for the offer buttons, when the store returned one.
func set_price(sku: String, price: String) -> void:
	if price == "" or not _price_labels.has(sku):
		return
	for l in _price_labels[sku]:
		(l as Label).text = price


# ============================================================ S14 Shop
func _build_shop() -> void:
	# Figma Shop 1550:5879 (886x5714, one scrolling page): awning header, "NO ADS", bundles, coins, Restore Purchase,
	# bottom nav with the Shop tab raised. Woolly Road sells only its two products; coins come from ads and play.
	_shop = _overlay("Shop", Callable(), true, Color("#3d70f3"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_shop.add_child(scroll)
	_place_edges(scroll, Vector2(0, 0), Vector2(1, 1), Vector2(0, 0), Vector2(0, 0))
	_shop_scroll = scroll
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	page.custom_minimum_size = Vector2(FW, 2330)
	scroll.add_child(page)
	# awning (Figma 0..185): red / cream stripes 148 wide with a scalloped edge
	for i in 6:
		var st := ColorRect.new()
		st.color = Color("#ef3f4a") if i % 2 == 0 else Color("#fff1e2")
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(st)
		_xy(st, Vector2(i * 148 - 2, 0), Vector2(148, 120))
		var sc := _panel(page, st.color, 64)
		_xy(sc, Vector2(i * 148 - 2, 50), Vector2(148, 135))
	# Figma Shop: tag 236,218 454x104 | Remove Ads card 30,365 | (bundle) | tag | Starter Pack card 430 tall |
	# COIN tag | coin cards | Restore Purchase 264,y 360x95. Woolly Road sells its two products, coins come from ads.
	var y := _shop_section(page, "NO ADS", 218.0)
	_shop_noads_btn = _noads_card(page, Vector2(30, y), true)
	_shop_noads_btn.set("on_press", func(): buy_remove_ads.emit())
	_shop_noads_btn.set("pass_drag", true)
	y = _shop_section(page, "BUNDLE", y + 290 + 100)
	var sp := _card(page, Vector2(30, y), Vector2(826, 430), Color("#3dd2de"), Color("#17a2c3"), 140)
	var gl := _img(sp, "unlock_glow", Color(1, 1, 1, 0.2))
	_xy(gl, Vector2(0, -20), Vector2(320, 320))
	var pile := _img(sp, "coin_pile", Color("#ffc93c"))
	_xy(pile, Vector2(30, 40), Vector2(260, 175))
	var c5 := _label(sp, "500", 64, Color.WHITE, Color("#0d6f8a"), 3)
	_xy(c5, Vector2(30, 190), Vector2(260, 80))
	var tile := _tile(sp, Vector2(330, 45), Vector2(450, 195), Color("#21b0cb"))
	var icons := ["ic_booster_uturn", "ic_plus", "ic_hand"]
	for i in 3:
		_item(tile, icons[i], "x3", Color("#0d6f8a"), Vector2(36 + i * 136, 28), 100.0, 46.0)
	var sb := _card_footer(sp, "STARTER PACK", Color("#0d6f8a"), 140, "$1.99", func(): buy_starter.emit(), Vector2(258, 91))
	sb.set("pass_drag", true)
	_price_labels.starter_pack.append(sb.get_meta("label"))
	y = _shop_section(page, "FREE COINS", y + 430 + 100)
	var fc := _card(page, Vector2(30, y), Vector2(826, 430), Color("#a24bf4"), Color("#7b2fd2"), 140)
	var fl := _label(fc, "+25", 96, Color.WHITE, Color("#4a1a8c"), 4)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_xy(fl, Vector2(50, 40), Vector2(300, 120))
	_free_coins_label = fl
	var fcoin := _img(fc, "ic_gold", Color("#ffc93c"))
	_xy(fcoin, Vector2(250, 62), Vector2(84, 84))
	var fp := _img(fc, "coin_pile", Color("#ffc93c"))
	_xy(fp, Vector2(380, 40), Vector2(400, 240))
	var fname := _label(fc, "FREE COINS", 52, Color.WHITE, Color("#4a1a8c"), 3)
	fname.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_xy(fname, Vector2(50, 280), Vector2(420, 140))
	var ab := _ads_btn(fc, Vector2(518, 304), Vector2(258, 91), func(): free_coins.emit())
	ab.set("pass_drag", true)
	y = _shop_section(page, "BOOSTERS", y + 430 + 100)
	var kinds := ["undo", "slot", "hint"]
	for i in 3:   # Figma coin tiles: 254x335 at x 34/314/594, cream top, purple strip with a green price
		var k: String = kinds[i]
		var t := _card(page, Vector2(34 + i * 280, y), Vector2(254, 335), Color("#fdf0dc"), Color("#9a4ee6"), 112)
		var ii := _img(t, BOOSTER_ICON[k], Color.WHITE)
		_xy(ii, Vector2(67, 22), Vector2(120, 120))
		var bn := _label(t, BOOSTER_NAME[k], 44, Color.WHITE, Color("#6b3fb5"), 3)
		bn.autowrap_mode = TextServer.AUTOWRAP_OFF
		_xy(bn, Vector2(0, 142), Vector2(254, 64))
		var cb := _text_btn(t, "btn_green", str(_booster_price), GREEN_INK, Vector2(24, 233), Vector2(206, 78), func(): shop_booster.emit(k), 42)
		var coin := _img(cb, "ic_gold", Color("#ffc93c"))
		_xy(coin, Vector2(30, 13), Vector2(52, 52))
		(cb.get_meta("label") as Label).position.x = 26
		cb.set("pass_drag", true)
		_booster_price_labels.append(cb.get_meta("label"))
	y += 335 + 100
	var rp := _text_btn(page, "btn_blue", "Restore Purchase", BLUE, Vector2(264, y), Vector2(360, 95), func(): restore_purchases.emit(), 38)
	rp.set("pass_drag", true)
	page.custom_minimum_size.y = y + 95 + 260
	# coins + close stay put over the page
	_coin_texts.append(_shop_coin_pill())
	_shop_close = _btn(_shop, "ic_close", BLUE, _close_of(_shop))
	_place(_shop_close, Vector2(1, 0), Vector2(-70, 70), Vector2(76, 76))
	_shop_nav = _nav_bar(_shop, 0)


## Section tag (Figma: peach pill 454x104 centred, light rim, white text with a brown outline). Returns the y of
## the card under it.
func _shop_section(page: Control, title: String, y: float) -> float:
	var tag := _panel(page, Color("#e9a36a"), 44, Color("#ffd9ae"), 6)
	var sb: StyleBoxFlat = tag.get_theme_stylebox("panel")
	sb.shadow_color = Color(0.35, 0.15, 0.05, 0.35)
	sb.shadow_offset = Vector2(0, 6)
	sb.shadow_size = 2
	_xy(tag, Vector2(216, y), Vector2(454, 104))
	var l := _label(tag, title, 50, Color("#fff4e6"), Color("#8a4b1c"), 3)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return y + 104 + 43


func _shop_coin_pill() -> Label:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop.add_child(root)
	_place(root, Vector2(0, 0), Vector2(140, 70), Vector2(206, 86))
	var bg := _img(root, "pill_dark", Color.WHITE)
	_xy(bg, Vector2(26, 3), Vector2(180, 80))
	var ic := _img(root, "ic_gold", Color("#ffc93c"))
	_xy(ic, Vector2(0, 0), Vector2(86, 86))
	var t := _label(root, "0", 34, BLUE)
	_xy(t, Vector2(80, 15), Vector2(120, 56))
	return t


## Opened from Home it is a tab (bottom nav, no close); from a level or a popup it closes back there.
func show_shop(as_tab := false) -> void:
	_shop_nav.visible = as_tab
	_shop_close.visible = not as_tab
	_shop_scroll.offset_bottom = -182 if as_tab else 0
	_shop_scroll.scroll_vertical = 0
	_show(_shop)


func shop_open() -> bool:
	return is_open(_shop)


func set_free_coins(n: int) -> void:
	_free_coins_label.text = "+%d" % n


## Bottom navigation (Figma Shop/Main: bar #3d70f3 182 tall, white line, raised tab 338x216, icons 132).
## tab: 0 = Shop, 1 = Home. Levels opens its popup.
func _nav_bar(parent: Control, tab: int) -> Control:
	var nav := _full(parent, "Nav")
	var bar := ColorRect.new()
	bar.color = NAV_BLUE
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	nav.add_child(bar)
	_place_edges(bar, Vector2(0, 1), Vector2(1, 1), Vector2(0, -182), Vector2(0, 80))   # bleeds below the safe area
	var line := ColorRect.new()
	line.color = Color.WHITE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_child(line)
	_place_edges(line, Vector2(0, 1), Vector2(1, 1), Vector2(0, -192), Vector2(0, -182))
	var xs := [128.0 - FW / 2, 0.0, 750.0 - FW / 2]
	var raised_x: float = xs[0] if tab == 0 else xs[1]
	var tab_img := _img(nav, "tab_home", Color("#6fb7ff"))
	_place(tab_img, Vector2(0.5, 1), Vector2(raised_x, -108), Vector2(338, 216))
	var names := ["ic_shop", "ic_home", "ic_nav_right"]
	var labels := ["SHOP", "HOME", ""]
	var cbs := [func(): _nav_go(0), func(): _nav_go(1), func(): _nav_go(2)]
	for i in 3:
		var raised: bool = (i == 0 and tab == 0) or (i == 1 and tab == 1)
		var b := _btn(nav, names[i], Color("#ff7a5c"), cbs[i])
		if raised:
			_place(b, Vector2(0.5, 1), Vector2(xs[i], -150), Vector2(220 if i == 1 else 170, 220 if i == 1 else 170))
			var l := _label(nav, labels[i], 50, Color.WHITE, BLUE, 3)
			_place(l, Vector2(0.5, 1), Vector2(xs[i], -45), Vector2(338, 70))
		else:
			_place(b, Vector2(0.5, 1), Vector2(xs[i], -91), Vector2(132, 132))
	return nav


func _nav_go(i: int) -> void:
	match i:
		0:
			if not shop_open():
				show_shop(true)
		1:
			if shop_open():
				_hide(_shop)
		2:
			_nav_levels()


func _nav_levels() -> void:
	pass   # Hud opens the Levels popup


# ============================================================ S18 New booster unlocked
func _build_unlock() -> void:
	# Figma unlock booster 1550:4576: gradient bg | glow 134,351 619 | title 227,293 433x154 | icon 267,475 352 |
	# name y=827 | description 252,985 | Continue 243,1225 400x195
	# the game shows faintly through: the usual 80% dim (Rectangle 958051) + the 80% blue gradient (958052)
	_unlock = _overlay("Unlock", func():
		_hide(_unlock)
		unlock_done.emit(), true)
	var bg := _img(_unlock, "unlock_bg", Color(0.25, 0.7, 0.95, 0.8))
	if bg is TextureRect:
		(bg as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := _full(_unlock, "Content")
	var glow := _img(root, "unlock_glow", Color(1, 1, 1, 0.3))
	_frame(glow, Vector2(134, 351), Vector2(619, 618))
	var title := _label(root, "NEW BOOSTER\nUNLOCKED!", 64, Color.WHITE, BLUE, 3)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	(title.label_settings as LabelSettings).line_spacing = -6
	_frame(title, Vector2(143, 293), Vector2(600, 154))
	var icon := _img(root, "ic_hand", Color.WHITE)   # the booster picture itself, no button frame (Figma 267,475 352)
	_frame(icon, Vector2(287, 495), Vector2(312, 312))
	var name := _label(root, "", 84, Color("#ffd23a"), Color("#c25a00"), 4)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_frame(name, Vector2(143, 827), Vector2(600, 92))
	var desc := _label(root, "", 44, Color.WHITE, BLUE, 2)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	(desc.label_settings as LabelSettings).line_spacing = -6
	_frame(desc, Vector2(223, 985), Vector2(440, 100))
	var cont := _text_btn(root, "btn_green", "Continue", GREEN_INK, Vector2.ZERO, Vector2(400, 195), _close_of(_unlock), 60)
	_frame(cont, Vector2(243, 1225), Vector2(400, 195))
	_unlock_ui = {icon = icon, name = name, desc = desc}


func show_unlock(kind: String) -> void:
	(_unlock_ui.icon as TextureRect).texture = _tex(BOOSTER_ICON[kind])
	_unlock_ui.name.text = BOOSTER_NAME[kind]
	_unlock_ui.desc.text = BOOSTER_DESC[kind]
	_show(_unlock)


# ============================================================ S22 / S23 lose-a-heart confirms
func _build_confirm(name: String, title: String, btn: String, tex: String, ink: Color, cb: Callable) -> Control:
	# Figma refill lives 1792:2585 ("Are you sure?" / Retry) and 1582:7357 (Quit)
	var o := _std_popup(name, title, 652, 574)
	var panel: Control = o.get_meta("panel")
	_inset(panel, Vector2(26, 179), Vector2(700, 266))
	_heart(panel, Vector2(100, 205), 220, "-1")
	var t := _label(panel, "You will lose\n1 Heart!", 42, BLUE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_xy(t, Vector2(344, 260), Vector2(360, 110))   # Figma 344,260 260x104
	_text_btn(panel, tex, btn, ink, Vector2(210, 466), Vector2(332, 162), func():
		_hide(o)
		cb.call())
	return o


# ============================================================ S28 Ads break / S29 Rate us
func _build_ads_break() -> void:
	# Figma win 1582:6864: "Ads break" 304,652 | art 324,741 253x253
	_ads_break = _overlay("AdsBreak", func(): pass, false)
	var root := _full(_ads_break, "Content")
	var t := _label(root, "Ads break", 73, Color.WHITE)
	_frame(t, Vector2(243, 640), Vector2(400, 96))
	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	_frame(art, Vector2(324, 760), Vector2(253, 253))
	_sheep_face(art, Vector2(253, 253), Art.wool("Y"), false)


func show_ads_break() -> void:
	_show(_ads_break)


func hide_ads_break() -> void:
	_hide(_ads_break)


func _build_rate() -> void:
	# Figma rate us 1785:1681: text 126,212 | 5 stars 126px from x=61 | SURE 210,459
	_rate = _std_popup("RateUs", "Rate us", 652, 574, func():
		_hide(_rate)
		rate_done.emit(0))
	var panel: Control = _rate.get_meta("panel")
	_inset(panel, Vector2(26, 166), Vector2(700, 279))
	var t := _label(panel, "Enjoy the game?\nPlease tell us your thoughts.", 30, BLUE)
	(t.label_settings as LabelSettings).line_spacing = -4
	_xy(t, Vector2(126, 210), Vector2(500, 76))   # Figma 183,212 387x72
	for i in 5:
		var n := i + 1
		var st := _btn(panel, "ic_star", Color("#ffc93c"), func():
			_rating = n
			_rate_paint())
		_xy(st, Vector2(61 + i * 126, 290), Vector2(126, 126))
		_rate_stars.append(st)
	_text_btn(panel, "btn_green", "SURE", GREEN_INK, Vector2(210, 459), Vector2(332, 162), func():
		_hide(_rate)
		rate_done.emit(_rating))


func _rate_paint() -> void:
	for i in 5:
		_rate_stars[i].modulate = Color.WHITE if i < _rating else Color(0.35, 0.4, 0.55, 0.8)


func show_rate() -> void:
	_rating = 5
	_rate_paint()
	_show(_rate)


# ============================================================ shared
func toast(_msg: String, _seconds := 1.5) -> void:
	pass   # Hud shows it


func set_booster_price(p: int) -> void:
	_booster_price = p
	for l in _booster_price_labels:
		l.text = str(p)
