class_name Hud
extends HudMeta
## All UI, built in code from the Figma "Bus Dash" kit (flow and frame ids: docs/UX_FLOW.md).
##   Home     : avatar (Profile), lives (Refill / Full of Heart), coins (Shop), gear (Settings), Daily Gift,
##              Starter Pack + Remove Ads offers, "Level N", PLAY, bottom nav (Shop | HOME | Levels)
##   Gameplay : pause, "Level N", coins (Shop), road counter, 3 boosters (locked until their level), booster tip
##   Popups   : Pause, Settings, Levels, Keep playing?, More boosters, Win, Lose (+ the meta screens in HudMeta)

signal play_pressed
signal home_pressed
signal next_pressed
signal retry_pressed
signal continue_coins
signal continue_ad
signal give_up
signal double_reward
signal booster_pressed(kind: String)
signal booster_coins(kind: String)
signal booster_ad(kind: String)
signal level_picked(i: int)
signal cheat_win
signal cheat_coins(n: int)
signal coach_continue

const VERSION := "Version 0.1.0"

var _home: Control
var _hud: Control
var _tray: Panel
const TRAY_H := 200.0   # booster tray height from the bottom of the safe area (reference bar: top at ~90% of the screen)
var _safe: Control
var _road: Control
var _road_base := Vector2.ZERO
const ROAD_SIGN := Vector2(210, 96)
var _pause_btn: Control
var _levels_scroll: ScrollContainer
var _cheat_pass: Control
var _cheat: Control
var _coach: Control
var _coach_dim: ColorRect
var _coach_card: Control
var _coach_text: Label
var _coach_ok: Control
var _coach_done := Callable()
var _ver_taps := 0
var _ver_last := 0.0
const CHEAT_PASSWORD := "0312"
var _road_dots: HBoxContainer
var _road_bg: CanvasItem
var _home_level: Label
var _home_avatar: Control
var _home_lives_n: Label
var _home_lives_t: Label
var _daily_dot: Control
var _level: Label
var _road_text: Label
var _toast: Control
var _toast_text: Label
var _banner: Control
var _banner_text: Label
var _banner_red: Control
var _hard: Control
var _hard_text: Label
var _tutorial: Control
var _tutorial_text: Label
var _tip: Control
var _tip_icon: TextureRect
var _tip_text: Label
var _tip_t := 0.0
var _hand: TextureRect
var _badges := {}
var _toggles: Array = []
var _stars: Array[TextureRect] = []
var _level_buttons: Array = []
var _pause: Control
var _settings: Control
var _levels: Control
var _win: Control
var _lose: Control
var _pre_lose: Control
var _boost_offer: Control
var _boost_kind := "undo"
var _boost_ui := {}
var _win_coins: Label
var _next_label: Label
var _x2_btn: Control
var _lose_msg: Label
var _cont_btn: Control
var _cont_label: Label
var _cont_coin: Control
var _remove_ads_offer: Array[Control] = []
var _privacy_btn: Control
var _toast_t := 0.0
var _banner_t := 0.0
var _road_shake := 0.0
var _hand_t := 0.0
var _underlines: Array[Callable] = []


func _ready() -> void:
	_init_kit()
	_build_vignette()
	_safe = _full(self, "Safe")
	_build_home()
	_build_hud()
	_build_coach()
	_build_hand()
	_build_messages()
	_build_hard()
	_build_pause()
	_build_settings()
	_build_levels()
	_build_pre_lose()
	_build_booster_offer()
	_build_win()
	_build_lose()
	_build_cheat()
	_build_meta()
	_top = _full(self, "Top")
	_build_toast()
	_build_top_layers()
	hide_panels()


## Soft dark edges over the 3D view so the eye goes to the board (under every UI element).
func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.02, 0.06, 0.0, 0.32))
	g.add_point(0.6, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.48)
	tex.fill_to = Vector2(1.08, 1.0)
	tex.width = 256
	tex.height = 256
	var v := TextureRect.new()
	v.name = "Vignette"
	v.texture = tex
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## "HARD LEVEL" intro (Figma Gameplay 1550:1257): the game dimmed to 20% (Rectangle 958070), red glow down both
## edges (958071 150 wide / 958072 172 wide), and a full-width striped red band (group 1893566932, its art from
## y 774) with a skull either side (130 at 44,863 / 719,863) and "HARD LEVEL" (205,876 483x105).
func _build_hard() -> void:
	_hard = _full(self, "HardLevel")
	var dim := ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hard.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in 2:
		var e := _img(_hard, "hard_edge_l" if side == 0 else "hard_edge_r", Color(1, 0.2, 0.2, 0.3))
		if e is TextureRect:
			(e as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE
		if side == 0:
			_place_edges(e, Vector2(0, 0), Vector2(0, 1), Vector2(0, 0), Vector2(150, 0))
		else:
			_place_edges(e, Vector2(1, 0), Vector2(1, 1), Vector2(-172, 0), Vector2(0, 0))
	# the band PNG is the 886-wide frame at 1.5x: tile it three frames wide so wider phones get it edge to edge
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hard.add_child(holder)
	_place(holder, Vector2(0.5, 0.5), Vector2(0, 774 + 157 - FH / 2), Vector2(FW * 3, 315))
	var band := TextureRect.new()
	band.texture = _tex("hard_band")
	band.stretch_mode = TextureRect.STRETCH_TILE
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(band)
	band.size = Vector2(FW * 3, 315) * 1.5
	band.scale = Vector2.ONE / 1.5
	for x in [44.0, 719.0]:
		var sk := _img(_hard, "ic_hardlvl", Color.WHITE)
		_frame(sk, Vector2(x, 863), Vector2(130, 130))
	_hard_text = _label(_hard, "HARD LEVEL", 88, Color.WHITE, Color("#6e0b0b"), 3)
	_hard_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_frame(_hard_text, Vector2(183, 870), Vector2(520, 117))
	_hard.visible = false


# ============================================================ home
func _build_home() -> void:
	_home = _full(_safe, "Home")
	# top bar (Figma Main 2283:2188 / setting 1529:1535): avatar 48..172 x 50..168 | lives 288..494 | coins 518..724 |
	# gear 771..857
	_home_avatar = _btn(_home, "", Color(0, 0, 0, 0), func(): show_profile())
	_place(_home_avatar, Vector2(0, 0), Vector2(110, 109), Vector2(126, 126))
	var lives := _pill(_home, Vector2(0.5, 0), Vector2(391 - FW / 2, 111), "ic_live", "Full", "5", _lives_pressed)
	_home_lives_t = lives[0]
	_home_lives_n = lives[1]
	_coin_texts.append(_pill(_home, Vector2(0.5, 0), Vector2(621 - FW / 2, 111), "ic_gold", "0", "", func(): show_shop(true))[0])
	var gear := _btn(_home, "ic_settings", Color("#f2ebe4"), func(): _show(_settings))
	_place(gear, Vector2(1, 0), Vector2(814 - FW, 111), Vector2(86, 86))
	# Daily Gift under the avatar (Figma Main popup 4930:2982 has a calendar icon there)
	_build_daily_icon()
	# offers on the right (Starter Pack 721,320 / Remove Ads 712,486; labels 171x48)
	_offer("ic_starterpack", "Starter Pack", Vector2(787, 380), Vector2(132, 120), 434, func(): show_starter())
	_remove_ads_offer = _offer("ic_removeads", "Remove Ads", Vector2(785, 551), Vector2(146, 130), 609, func(): show_no_ads())
	# level sign + PLAY (Figma btn 196,1284 500x237)
	var sign := _img(_home, "pill_level", BLUE)
	_place(sign, Vector2(0.5, 0.5), Vector2(0, 1170 - FH / 2), Vector2(300, 140))
	_home_level = _label(sign, "Level 1", 64, Color.WHITE, BLUE, 3)
	var play := _btn(_home, "btn_play", Color("#5cc24a"), func(): play_pressed.emit())
	_place(play, Vector2(0.5, 0.5), Vector2(446 - FW / 2, 1402 - FH / 2), Vector2(500, 237))
	var pl := _label(play, "PLAY", 110, Color.WHITE, GREEN_INK, 4)
	pl.position.y = -12
	_nav_bar(_home, 1)


func _build_daily_icon() -> void:
	var b := _btn(_home, "", Color(0, 0, 0, 0), func(): _open_daily())
	_place(b, Vector2(0, 0), Vector2(100, 330), Vector2(132, 132))
	var box := _panel(b, Color("#ff4b5c"), 22, Color.WHITE, 6)
	_xy(box, Vector2(14, 44), Vector2(104, 80))
	var lid := _panel(b, Color("#ff6b78"), 18, Color.WHITE, 6)
	_xy(lid, Vector2(6, 26), Vector2(120, 36))
	var rib := _panel(b, Color("#ffd23a"), 6)
	_xy(rib, Vector2(56, 26), Vector2(20, 98))
	for sgn in [-1, 1]:
		var bow := _panel(b, Color("#ffd23a"), 20, Color("#e09a00"), 4)
		_xy(bow, Vector2(66 + sgn * 26 - 20, 2), Vector2(40, 30))
	var tag := _img(_home, "label_white", Color.WHITE)
	_place(tag, Vector2(0, 0), Vector2(100, 406), Vector2(171, 48))
	_label(tag, "Daily Gift", 24, BLUE)
	_daily_dot = _panel(b, Color("#ff3a3a"), 20, Color.WHITE, 4)
	_xy(_daily_dot, Vector2(102, 10), Vector2(36, 36))


var _daily_state := [0, false]


## Daily Gift state from the save: next cycle day (0-based) and whether today's gift is still waiting.
func set_daily(next_i: int, claimable: bool) -> void:
	_daily_state = [next_i, claimable]
	_daily_dot.visible = claimable
	if daily_open():
		show_daily(next_i, claimable)


func _open_daily() -> void:
	show_daily(_daily_state[0], _daily_state[1])


func _offer(icon: String, title: String, c: Vector2, size: Vector2, label_y: float, cb: Callable) -> Array[Control]:
	var b := _btn(_home, icon, Color("#ffc93c"), cb)
	_place(b, Vector2(1, 0), Vector2(c.x - FW, c.y), size)
	var tag := _img(_home, "label_white", Color.WHITE)
	_place(tag, Vector2(1, 0), Vector2(786 - FW, label_y), Vector2(171, 48))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(tag, title, 24, BLUE)
	return [b, tag]


## White pill with an icon on the left (Figma 206x86 top-bar pills); the green + makes it a button.
## Returns [value label, icon label].
func _pill(parent: Control, anchor: Vector2, centre: Vector2, icon: String, text: String, icon_text := "", cb := Callable()) -> Array[Label]:
	var root: Control = _btn(parent, "", Color(0, 0, 0, 0), cb) if cb.is_valid() else Control.new()
	if not cb.is_valid():
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(root)
	_place(root, anchor, centre, Vector2(206, 86))
	var bg := _img(root, "pill_dark", Color.WHITE)
	_xy(bg, Vector2(26, 3), Vector2(180, 80))
	var ic := _img(root, icon, Color("#ffc93c"))
	_xy(ic, Vector2(0, 0), Vector2(86, 86))
	var il: Label = null
	if icon_text != "":
		il = _label(ic, icon_text, 34, Color.WHITE, RED_INK, 2)
	var plus := _img(root, "ic_plus_small", Color("#5cc24a"))
	_xy(plus, Vector2(43, 52), Vector2(34, 36))
	var t := _label(root, text, 34, BLUE)
	_xy(t, Vector2(80, 15), Vector2(120, 56))
	return [t, il]


# ============================================================ gameplay HUD
func _build_hud() -> void:
	_hud = _full(_safe, "HUD")
	# Figma Gameplay (measured on the frame, the art not the node boxes): pause button centre 92,102 (~95 wide) |
	# "Level N" centre y 96 | coin 670..748 with its pill to 884, centre y 98. The pill/pause PNGs carry shadow
	# under the art, so their boxes sit a little lower than the visible centre.
	var pause := _btn(_hud, "btn_pause", BLUE, func(): _show(_pause))
	_place(pause, Vector2(0, 0), Vector2(93, 108), Vector2(114, 114))
	_pause_btn = pause
	_level = _label(_hud, "Level 1", 56, Color.WHITE, BLUE, 3)
	_place(_level, Vector2(0.5, 0), Vector2(0, 97), Vector2(400, 80))
	_coin_texts.append(_pill(_hud, Vector2(1, 0), Vector2(775 - FW, 100), "ic_gold", "0", "", func(): show_shop(false))[0])
	# free road slots: a sign beside the loop (like the reference's "0/5" sign); the game moves it with the board
	_road = Control.new()
	_road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_road)
	_road.size = ROAD_SIGN
	_road.pivot_offset = ROAD_SIGN / 2.0
	_road.rotation = deg_to_rad(-6.0)
	var bg := _img(_road, "pill_dark", Color.WHITE)
	bg.size = ROAD_SIGN
	_road_bg = bg
	_road_text = _label(_road, "FREE 5/5", 32, BLUE)
	_xy(_road_text, Vector2(0, 8), Vector2(ROAD_SIGN.x, 44))
	_road_dots = HBoxContainer.new()
	_road_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_road_dots.add_theme_constant_override("separation", 5)
	_road_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_road.add_child(_road_dots)
	_xy(_road_dots, Vector2(6, 54), Vector2(ROAD_SIGN.x - 12, 26))
	_build_tray()
	# boosters (Figma frame y=1667: 163x164 each, 217 apart)
	_booster("undo", -217)
	_booster("slot", 0)
	_booster("hint", 217)
	# booster description card above the boosters (Figma Gameplay 4029:2746: 75,1423 740x231)
	_tip = _panel(_hud, Color.WHITE, 40, Color("#3d70f3"), 8)
	_place(_tip, Vector2(0.5, 1), Vector2(0, -330), Vector2(740, 200))
	var tb := _img(_tip, "btn_booster", Color("#2fa8f0"))
	_xy(tb, Vector2(30, 18), Vector2(163, 164))
	_tip_icon = _img(tb, "ic_hand", Color.WHITE)
	_xy(_tip_icon, Vector2(24, 17), Vector2(113, 113))
	_tip_text = _label(_tip, "", 38, BLUE)
	_tip_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_xy(_tip_text, Vector2(220, 10), Vector2(450, 180))
	var tclose := _btn(_tip, "ic_close", BLUE, func(): _tip.visible = false)
	_xy(tclose, Vector2(670, 20), Vector2(48, 48))
	_tip.visible = false


## Wooden booster tray along the bottom. The gameplay camera ends the board at its top edge, so the queue
## shows its first rows and the rest of the line runs on under the tray (it also eats taps on those sheep).
func _build_tray() -> void:
	_tray = Panel.new()
	_tray.name = "Tray"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#c4844a")
	sb.border_color = Color("#7d4b22")
	sb.border_width_top = 10
	sb.corner_radius_top_left = 46
	sb.corner_radius_top_right = 46
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 16
	_tray.add_theme_stylebox_override("panel", sb)
	_hud.add_child(_tray)
	_tray.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_tray.offset_left = -12.0
	_tray.offset_right = 12.0
	_tray.offset_top = -TRAY_H
	_tray.offset_bottom = 400.0   # past the gesture-bar inset to the screen edge
	for y in [24.0, 112.0]:   # plank seams
		var seam := ColorRect.new()
		seam.color = Color("#a96b36")
		seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tray.add_child(seam)
		seam.position = Vector2(0, y)
		seam.size = Vector2(FW + 24.0, 5.0)


## Top edge of the booster tray in viewport pixels (where the gameplay camera ends the board).
func tray_top(vp_h: float) -> float:
	if _tray != null and _tray.is_inside_tree() and _tray.size.y > 0.0:
		return _tray.get_global_rect().position.y
	return vp_h - TRAY_H


## Bottom of the top bar (pause / "Level N" / coins) in viewport pixels: the board's space starts below it.
func top_bar_bottom() -> float:
	if _pause_btn != null and _pause_btn.is_inside_tree() and _pause_btn.size.y > 0.0:
		var r := _pause_btn.get_global_rect()
		return r.position.y + r.size.y
	return 170.0


## Put the free-slots sign with its centre at `centre` (viewport pixels), kept on screen.
func place_road(centre: Vector2) -> void:
	var vp := get_viewport_rect().size
	var half := ROAD_SIGN / 2.0
	centre.x = clampf(centre.x, half.x + 14.0, vp.x - half.x - 14.0)
	_road_base = centre - half - (_road.get_parent() as Control).global_position   # the HUD sits inside the safe area
	if _road_shake <= 0.0:
		_road.position = _road_base


func _booster(kind: String, x: float) -> void:
	var b := _btn(_hud, "btn_booster", Color("#2fa8f0"), func(): booster_pressed.emit(kind))
	_place(b, Vector2(0.5, 1), Vector2(x, -114), Vector2(163, 164))   # centred in the tray, like the reference bar
	var ic := _img(b, BOOSTER_ICON[kind], Color.WHITE)
	_xy(ic, Vector2(24, 17), Vector2(113, 113))
	var badge := _img(b, "badge_red", Color("#ff4d5e"))
	_xy(badge, Vector2(117, 106), Vector2(64, 68))
	var count := _label(badge, "2", 36, Color.WHITE, RED_INK, 2)
	var buy := _img(b, "ic_plus", Color("#5cc24a"))
	_xy(buy, Vector2(117, 106), Vector2(64, 68))
	var lock := _img(b, "ic_lock", Color("#ffc93c"))
	_xy(lock, Vector2(36, 30), Vector2(92, 92))
	_badges[kind] = {btn = b, icon = ic, badge = badge, count = count, plus = buy, lock = lock}


## Level 1 coach (reference tutorial): the game dims, a window shows what to look at, a card with a sheep
## avatar explains it. With a Continue button the game waits (it is a freezing overlay); without one the
## player taps through the window (the dim layer lets taps pass, the game only accepts the shown sheep).
func _build_coach() -> void:
	_coach = Control.new()
	_coach.name = "Coach"
	_coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_coach)
	_coach.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_coach.set_meta("freeze", true)
	_coach.set_meta("back", func(): _coach_next())
	_coach.visible = false
	_coach_dim = ColorRect.new()
	_coach_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/spotlight.gdshader")
	_coach_dim.material = m
	_coach.add_child(_coach_dim)
	_coach_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := _panel(_coach, Color.WHITE, 46, Color("#3d70f3"), 8)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = Vector2(700, 170)
	_coach_card = card
	var ring := _panel(card, Color("#ffd64d"), 90, Color("#f29a1f"), 8)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xy(ring, Vector2(-40, -10), Vector2(190, 190))
	var face := _sheep_face(ring, Vector2(150, 150))
	_xy(face, Vector2(20, 20), Vector2(150, 150))
	_coach_text = _label(card, "", 44, BLUE)
	_xy(_coach_text, Vector2(170, 10), Vector2(510, 150))
	_coach_ok = _text_btn(_coach, "btn_green", "Continue", GREEN_INK, Vector2.ZERO, Vector2(380, 150), func(): _coach_next(), 56)


## Show the coach: `text`, a window `hole` (viewport rect, size 0 = none), the card centred at `card_y`.
## `done` set: a Continue button, the game waits until it is pressed (then `done` runs).
func coach(text: String, hole: Rect2, card_y: float, done := Callable()) -> void:
	_coach_done = done
	_coach_text.text = text
	var vp := get_viewport_rect().size
	var m: ShaderMaterial = _coach_dim.material
	m.set_shader_parameter("rect_size", vp)
	m.set_shader_parameter("hole", Vector4(hole.position.x, hole.position.y, hole.size.x, hole.size.y))
	_coach_card.position = Vector2((vp.x - _coach_card.size.x) / 2.0 + 20.0, card_y - _coach_card.size.y / 2.0)
	_coach_ok.visible = done.is_valid()
	_coach.mouse_filter = Control.MOUSE_FILTER_STOP if done.is_valid() else Control.MOUSE_FILTER_IGNORE
	_coach_ok.position = Vector2((vp.x - _coach_ok.size.x) / 2.0, card_y + _coach_card.size.y / 2.0 + 40.0)
	if done.is_valid():
		_show(_coach)
	else:
		_coach.visible = true
	_pop(_coach_card)


func coach_hide() -> void:
	_coach_done = Callable()
	if is_open(_coach):
		_hide(_coach)
	_coach.visible = false


func coach_open() -> bool:
	return _coach.visible


func _coach_next() -> void:
	var cb := _coach_done
	coach_hide()
	if cb.is_valid():
		cb.call()


func _build_hand() -> void:
	_hand = _img(self, "ic_hand", Color("#ffd23a"))
	_hand.size = Vector2(120, 120)
	_hand.visible = false


func _build_messages() -> void:
	_tutorial = _img(_safe, "popup_inset", Color("#e6ecf8"))
	_place(_tutorial, Vector2(0.5, 0), Vector2(0, 340), Vector2(700, 120))
	_tutorial_text = _label(_tutorial, "", 38, BLUE)
	_xy(_tutorial_text, Vector2(30, 8), Vector2(640, 104))
	_tutorial.visible = false

	_banner = _img(_safe, "ribbon_blue", Color("#2f8cff"))
	_place(_banner, Vector2(0.5, 0.5), Vector2(0, 860 - FH / 2), Vector2(772, 209))
	_banner_red = _img(_banner, "ribbon_red", Color("#ff3a60"))
	_banner_red.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner_text = _label(_banner, "", 64, Color.WHITE, BLUE, 3)
	_xy(_banner_text, Vector2(86, 15), Vector2(600, 90))
	_banner.visible = false


func _build_toast() -> void:
	_toast = _img(_top, "pill_dark", Color.WHITE)
	_place(_toast, Vector2(0.5, 1), Vector2(0, -330), Vector2(680, 96))
	_toast_text = _label(_toast, "", 36, BLUE)
	_toast.visible = false


# ============================================================ popups
func _build_pause() -> void:
	# Figma pause 1785:1920: popup at 67,453 (752x819), toggles inset y=168, HOME/START y=463, Watch Ads y=625
	_pause = _std_popup("Pause", "Pause", 819, 453)
	var panel: Control = _pause.get_meta("panel")
	_toggles_row(panel, 168, 277, 229)
	_text_btn(panel, "btn_red", "HOME", RED_INK, Vector2(38, 463), Vector2(332, 162), func(): _show(_quit_confirm))
	_text_btn(panel, "btn_blue", "RESTART", BLUE, Vector2(382, 463), Vector2(332, 162), func(): _show(_restart_confirm))
	_ads_btn(panel, Vector2(210, 625), Vector2(332, 162), func(): free_coins.emit())
	_footer(_pause.get_child(0), 1308, true)


func _build_settings() -> void:
	# Figma setting 1529:1535: popup at 67,574 (752x652), toggles inset y=179, Language/Contact y=466, links y=1245
	_settings = _std_popup("Settings", "Settings", 652, 574)
	var panel: Control = _settings.get_meta("panel")
	var content: Control = _settings.get_child(0)
	_toggles_row(panel, 179, 266, 229)
	_text_btn(panel, "btn_blue", "Language", BLUE, Vector2(44, 466), Vector2(332, 162), func(): _show(_language), 48)
	_text_btn(panel, "btn_blue", "Contact", BLUE, Vector2(376, 466), Vector2(332, 162), func(): Horus.support.mail({}), 48)
	_footer(content, 1245, true)
	_privacy_btn = _text_btn(content, "btn_grey", "Privacy settings", BLUE, Vector2(0, 0), Vector2(420, 110), func(): Horus.ads.privacy(), 36)
	_place(_privacy_btn, Vector2(0.5, 0.5), Vector2(0, 1512 - FH / 2), Vector2(420, 110))   # below the version tap area
	var refresh := func():
		_refresh_toggles()
		_privacy_btn.visible = Horus.ads.has_privacy
	_settings.set_meta("on_show", refresh)
	_pause.set_meta("on_show", _refresh_toggles)


func _footer(root: Control, y: float, restore: bool) -> void:
	var cy := y
	if restore:
		_link(root, "Restore Purchase", cy + 27, func(): restore_purchases.emit())
		cy += 63
	_link(root, "Privacy Policy", cy + 27, func(): show_privacy())
	# the version line is also the hidden cheat door. Its tap area is wide and starts below the Privacy Policy
	# link (a finger a little high used to open Privacy and break the count); the text sits at its top.
	var vb := _btn(root, "", Color(0, 0, 0, 0), _version_tap)
	vb.set("silent", true)   # looks and feels like plain text: no press animation, no message
	_place(vb, Vector2(0.5, 0.5), Vector2(0, cy + 66 + 37 - FH / 2), Vector2(700, 74))
	var vl := _label(vb, VERSION, 26, Color.WHITE)
	vl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	vl.offset_bottom = 42


## Testers' cheats: tap "Version" 10 times (at most 3 s apart) in Settings or Pause, then type 0312 on the keypad.
## Nothing shows until the 10th tap, so players cannot tell the line does anything.
func _version_tap() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _ver_last > 3.0:
		_ver_taps = 0
	_ver_last = now
	_ver_taps += 1
	if _ver_taps >= 10:
		_ver_taps = 0
		_show(_cheat_pass)


## Number box (white, blue digits) for the keypad screens; returns its label.
func _digits_box(parent: Control, pos: Vector2, size: Vector2) -> Label:
	var box := _panel(parent, Color.WHITE, 28, Color("#3d70f3"), 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xy(box, pos, size)
	return _label(box, "", 64, BLUE)


## 3x4 keypad drawn by the game (no system keyboard): 1-9, C (clear), 0, < (delete). on_key(key: String).
func _keypad(parent: Control, top: float, key: Vector2, on_key: Callable) -> void:
	var keys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "<"]
	var gap := 16.0
	var x0 := (752.0 - (key.x * 3 + gap * 2)) / 2.0
	for i in keys.size():
		var k: String = keys[i]
		var tex := "btn_blue" if k.is_valid_int() else "btn_grey"
		_text_btn(parent, tex, k, BLUE, Vector2(x0 + (i % 3) * (key.x + gap), top + (i / 3) * (key.y + gap)), key,
			func(): on_key.call(k), 56)


func _build_cheat() -> void:
	# password: a keypad, checked as soon as 4 digits are in
	_cheat_pass = _std_popup("CheatPass", "Password", 800, 560)
	var pp: Control = _cheat_pass.get_meta("panel")
	var shown := _digits_box(pp, Vector2(146, 165), Vector2(460, 110))
	var pw: Array[String] = [""]
	var draw := func(): shown.text = "*".repeat(pw[0].length()) if pw[0] != "" else "_ _ _ _"
	_keypad(pp, 300, Vector2(196, 100), func(k: String):
		if k == "C":
			pw[0] = ""
		elif k == "<":
			pw[0] = pw[0].left(-1)
		elif pw[0].length() < 4:
			pw[0] += k
		draw.call()
		if pw[0].length() == 4:
			if pw[0] == CHEAT_PASSWORD:
				_hide(_cheat_pass)
				_show(_cheat)
			else:
				toast(tr("Wrong password"))
			pw[0] = ""
			draw.call())
	_cheat_pass.set_meta("on_show", func():
		pw[0] = ""
		draw.call())

	# cheats: win the level, add any amount of coins (keypad) or a preset
	_cheat = _std_popup("Cheat", "Cheat", 1280, 320)
	var cp: Control = _cheat.get_meta("panel")
	_text_btn(cp, "btn_green", "WIN LEVEL", GREEN_INK, Vector2(44, 165), Vector2(664, 140), func():
		_hide_all()
		cheat_win.emit(), 56)
	var coins_t := _label(cp, "Add coins", 44, BLUE)
	_xy(coins_t, Vector2(44, 322), Vector2(664, 60))
	var amount_l := _digits_box(cp, Vector2(44, 390), Vector2(664, 100))
	var amount: Array[String] = [""]
	var show_amount := func(): amount_l.text = amount[0] if amount[0] != "" else "0"
	_keypad(cp, 510, Vector2(196, 92), func(k: String):
		if k == "C":
			amount[0] = ""
		elif k == "<":
			amount[0] = amount[0].left(-1)
		elif amount[0].length() < 8 and not (amount[0] == "" and k == "0"):
			amount[0] += k
		show_amount.call())
	var add := func(n: int):
		if n <= 0:
			toast(tr("Type an amount"))
			return
		cheat_coins.emit(n)
		toast(tr("+%d coins!") % n)
	_text_btn(cp, "btn_yellow", "ADD", YELLOW_INK, Vector2(44, 940), Vector2(664, 130), func():
		add.call(int(amount[0]) if amount[0] != "" else 0)
		amount[0] = ""
		show_amount.call(), 56)
	for i in 3:
		var n: int = [100, 1000, 10000][i]
		_text_btn(cp, "btn_blue", "+%d" % n, BLUE, Vector2(44 + i * 224, 1090), Vector2(216, 130), func(): add.call(n), 44)
	_cheat.set_meta("on_show", func():
		amount[0] = ""
		show_amount.call())



func _link(root: Control, text: String, cy: float, cb: Callable) -> void:
	var b := _btn(root, "", Color(0, 0, 0, 0), cb)
	_place(b, Vector2(0.5, 0.5), Vector2(0, cy - FH / 2), Vector2(700, 60))
	var l := _label(b, text, 46, Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var u := ColorRect.new()
	u.color = Color.WHITE
	u.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(u)
	var underline := func():   # follows the translated text and the current font
		var w := _font.get_string_size(tr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
		_xy(u, Vector2((700 - w) / 2.0, 52), Vector2(w, 3))
	underline.call()
	_underlines.append(underline)


## Sound / music / haptic toggles in their inset (Figma: 164x164 at x 94/294/494, `icons_y` in the popup).
func _toggles_row(panel: Control, top: float, h: float, icons_y: float) -> void:
	var inset := _inset(panel, Vector2(26, top), Vector2(700, h))
	inset.mouse_filter = Control.MOUSE_FILTER_PASS
	var kinds := ["sound", "music", "haptic"]
	for i in 3:
		var kind: String = kinds[i]
		var b := _btn(inset, "tg_%s_on" % kind, Color("#2fa8f0"), func():
			_flip(kind)
			_refresh_toggles())
		_xy(b, Vector2(68 + i * 200, icons_y - top - 4), Vector2(164, 172))
		_toggles.append({btn = b, kind = kind})


static func _flip(kind: String) -> void:
	var key := "wr_" + kind
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("audio", key, not cfg.get_value("audio", key, true))
	cfg.save("user://settings.cfg")


static func setting(kind: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	return cfg.get_value("audio", "wr_" + kind, true)


func _refresh_toggles() -> void:
	for t in _toggles:
		var on := setting(t.kind)
		var tex := _tex("tg_%s_%s" % [t.kind, "on" if on else "off"])
		var img: TextureRect = t.btn.get_meta("bg")
		if tex:
			img.texture = tex


func _build_levels() -> void:
	# 50 levels: a scrolling grid, 4 per row (drag to scroll; a drag never presses a level)
	var n := Levels.count()
	const COLS := 4
	const STEP := 166.0
	var h := 1300.0
	_levels = _std_popup("Levels", "Levels", h, 960 - h / 2)
	var panel: Control = _levels.get_meta("panel")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	panel.add_child(scroll)
	_xy(scroll, Vector2(42, 160), Vector2(COLS * STEP + 4, h - 200))
	_levels_scroll = scroll
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	page.custom_minimum_size = Vector2(COLS * STEP, ceili(n / float(COLS)) * STEP + 10)
	scroll.add_child(page)
	for i in n:
		var idx := i
		var b := _btn(page, "btn_booster", Color("#2fa8f0"), func():
			_hide(_levels)
			level_picked.emit(idx))
		b.set("pass_drag", true)
		_xy(b, Vector2(8 + (i % COLS) * STEP, 8 + (i / COLS) * STEP), Vector2(146, 146))
		var lbl := _label(b, str(i + 1), 64, Color.WHITE, BLUE, 3)
		var lock := _img(b, "ic_lock", Color("#ffc93c"))
		_xy(lock, Vector2(33, 33), Vector2(80, 80))
		_level_buttons.append({btn = b, lock = lock, label = lbl})
	# open at the newest unlocked level
	_levels.set_meta("on_show", func():
		var row := 0
		for i in _level_buttons.size():
			var e: Dictionary = _level_buttons[i]
			var btn: Control = e.btn
			if not btn.get_meta("disabled", false):
				row = i / COLS
		_levels_scroll.scroll_vertical = maxi(0, int((row - 2) * STEP)))


func _nav_levels() -> void:
	if shop_open():
		_hide(_shop)
	_show(_levels)


func _build_pre_lose() -> void:
	# Figma "pre lose" 1578:6714: "Keep playing?" popup at 67,273 (753x871), buttons at 44,669
	_pre_lose = _std_popup("PreLose", "Keep playing?", 871, 273, func():
		_hide(_pre_lose)
		give_up.emit()
		_show(_lose))
	_pre_lose.set_meta("freeze", false)
	var panel: Control = _pre_lose.get_meta("panel")
	var inset := _inset(panel, Vector2(26, 185), Vector2(700, 464))
	var plus := _img(inset, "ic_plus", Color("#5cc24a"))
	_xy(plus, Vector2(115, 78), Vector2(170, 180))
	var road := _label(inset, "1 ROAD", 72, Color.WHITE, BLUE, 3)
	_xy(road, Vector2(270, 118), Vector2(320, 100))
	var desc := _label(inset, "The road is full!\nGet one more space and keep going", 40, BLUE)
	_xy(desc, Vector2(30, 319), Vector2(640, 110))   # Figma text 184,519 385x80 in the popup
	_cont_btn = _coin_btn(panel, Vector2(44, 669), Vector2(332, 162), 60, func(): continue_coins.emit())
	_cont_label = _cont_btn.get_meta("label")
	_cont_coin = _cont_btn.get_child(_cont_btn.get_child_count() - 1)
	_ads_btn(panel, Vector2(376, 669), Vector2(332, 162), func(): continue_ad.emit())
	# offer card under the popup (Figma "Brd_Helper pack" at 42,1165 -> the card itself 72,1186 738x390)
	_pack_card(_pre_lose.get_child(0), Vector2(72, 1186))


## Starter Pack card in the Bus Dash "Helper Pack" style (measured on pre lose 1578:6714): 738x390 with a white rim,
## light-blue top with the art left (heart 220,1305 there -> coin pile + 500) and a darker box of items
## (368..768 x 1225..1400), a strip from y 264 with the name (x 58) and the price button 231x83 on the right.
func _pack_card(parent: Control, pos: Vector2) -> void:
	var holder := _full(parent, "PackCard")   # Figma frame coordinates, centred on screen
	_frame(holder, Vector2.ZERO, Vector2(FW, FH))
	var card := _card(holder, pos, Vector2(738, 390), Color("#43c3fa"), Color("#1e8fe0"), 116)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var pile := _img(card, "coin_pile", Color("#ffc93c"))
	_xy(pile, Vector2(50, 46), Vector2(200, 135))
	var n := _label(card, "500", 60, Color.WHITE, BLUE, 3)
	_xy(n, Vector2(50, 168), Vector2(200, 70))
	var box := _tile(card, Vector2(296, 39), Vector2(400, 175), Color("#2aa0ea"))
	var icons := ["ic_booster_uturn", "ic_plus", "ic_hand"]
	for i in 3:
		_item(box, icons[i], "x3", BLUE, Vector2(22 + i * 125, 14), 100.0, 46.0)
	var buy := _card_footer(card, "STARTER PACK", BLUE, 116, "$1.99", func(): buy_starter.emit(), Vector2(231, 83), 44.0)
	_price_labels.starter_pack.append(buy.get_meta("label"))


func _build_booster_offer() -> void:
	# Figma buy more booster 1792:2863: popup 67,339 753x778 | title = booster | inset 26,185 700x374 with the
	# booster picture 280 at 236,211 and "Booster description" 184,468 | Watch Ads | [coin] price at y 583 |
	# Helper Pack card under it (Brd 42,1142 -> visible 72,1163)
	_boost_offer = _std_popup("BoosterOffer", "Undo", 778, 339)
	var panel: Control = _boost_offer.get_meta("panel")
	_inset(panel, Vector2(26, 185), Vector2(700, 374))
	var icon := _img(panel, "ic_hand", Color.WHITE)
	_xy(icon, Vector2(236, 205), Vector2(280, 250))
	var desc := _label(panel, "", 40, BLUE)
	desc.autowrap_mode = TextServer.AUTOWRAP_OFF
	_xy(desc, Vector2(40, 460), Vector2(672, 62))
	_ads_btn(panel, Vector2(44, 583), Vector2(332, 162), func(): booster_ad.emit(_boost_kind))
	var coins := _coin_btn(panel, Vector2(376, 583), Vector2(332, 162), 60, func(): booster_coins.emit(_boost_kind))
	_pack_card(_boost_offer.get_child(0), Vector2(72, 1163))
	_boost_ui = {title = panel.get_meta("title"), icon = icon, desc = desc, price = coins.get_meta("label")}


func _build_win() -> void:
	# Figma win 1550:5327: ribbon frame 57,116; reward 350,960; coins 380,1046; buttons 111,1414
	_win = _overlay("Win", func(): next_pressed.emit(), false)
	var root := _full(_win, "Content")
	# light rays behind the centrepiece (Figma fx 1: 148,116 567x315)
	var glow := _img(root, "win_glow", Color(1, 0.9, 0.3, 0.3))
	_place(glow, Vector2(0.5, 0.5), Vector2(431 - FW / 2, 273 - FH / 2), Vector2(567, 315))
	# centrepiece over the ribbon (Figma chic1: the bus full of people, 235,74 415x415): a happy flock
	var flock := _flock(root, Vector2.ZERO, 415)
	_place(flock, Vector2(0.5, 0.5), Vector2(0, 281 - FH / 2), Vector2(415, 415))
	_horn(root, "win_horn_small", 238, 329, 165, true)
	_horn(root, "win_horn_small", -238, 329, 165, false)
	_horn(root, "win_horn_big", 220, 311, 242, true)
	_horn(root, "win_horn_big", -220, 311, 242, false)
	var ribbon := _img(root, "ribbon_red", Color("#ff3a60"))
	_place(ribbon, Vector2(0.5, 0.5), Vector2(0, 452 - FH / 2), Vector2(772, 209))
	var title := _label(ribbon, "CONGRATULATIONS!", 56, Color.WHITE, RED_INK, 3)
	_xy(title, Vector2(66, 18), Vector2(640, 90))
	for i in 3:
		var st := _img(root, "ic_star", Color("#ffc93c"))
		var s := 230.0 if i == 1 else 180.0
		_place(st, Vector2(0.5, 0.5), Vector2((i - 1) * 215, 720 - (35 if i == 1 else 0) - FH / 2), Vector2(s, s))
		_stars.append(st)
	var reward := _label(root, "Reward", 57, Color.WHITE)
	_place(reward, Vector2(0.5, 0.5), Vector2(0, 993 - FH / 2), Vector2(400, 70))
	var pile := _img(root, "coin_pile", Color("#ffc93c"))
	_place(pile, Vector2(0.5, 0.5), Vector2(0, 1143 - FH / 2), Vector2(290, 195))
	_win_coins = _label(root, "80", 64, Color.WHITE)
	_place(_win_coins, Vector2(0.5, 0.5), Vector2(0, 1277 - FH / 2), Vector2(300, 72))   # Figma "200": 380,1241 125x72
	var next := _text_btn(root, "btn_green", "Continue", GREEN_INK, Vector2.ZERO, Vector2(332, 162), func(): next_pressed.emit(), 50)
	_place(next, Vector2(0.5, 0.5), Vector2(277 - FW / 2, 1495 - FH / 2), Vector2(332, 162))
	_next_label = next.get_meta("label")
	# Figma: [ad icon] 100 [coin] — watch an ad for the same reward again
	_x2_btn = _text_btn(root, "btn_yellow", "80", YELLOW_INK, Vector2.ZERO, Vector2(332, 162), func(): double_reward.emit(), 56)
	_place(_x2_btn, Vector2(0.5, 0.5), Vector2(609 - FW / 2, 1495 - FH / 2), Vector2(332, 162))
	var x2l: Label = _x2_btn.get_meta("label")
	_xy(x2l, Vector2(100, 0), Vector2(130, 150))
	_ad_icon(_x2_btn, Vector2(34, 42))
	var c2 := _img(_x2_btn, "ic_gold", Color("#ffc93c"))
	_xy(c2, Vector2(232, 42), Vector2(72, 72))


func _horn(parent: Control, tex: String, dx: float, cy: float, size: float, right: bool) -> void:
	var h := _img(parent, tex, Color("#ffc93c"))
	_place(h, Vector2(0.5, 0.5), Vector2(dx, cy - FH / 2), Vector2(size, size))
	if not right:
		h.flip_h = true


func _build_lose() -> void:
	# Figma lose 1550:5985: blue ribbon 57,314; illustration 133,450; RETRY at 277,1358
	# + Figma refill lives 1582:6824 ("Level failed!" with the -1 heart)
	_lose = _overlay("Lose", func(): home_pressed.emit(), false)
	var root := _full(_lose, "Content")
	var ribbon := _img(root, "ribbon_blue", Color("#2f8cff"))
	_place(ribbon, Vector2(0.5, 0.5), Vector2(0, 418 - FH / 2), Vector2(772, 209))
	var title := _label(ribbon, "LEVEL FAILED!", 60, Color.WHITE, BLUE, 3)
	_xy(title, Vector2(76, 15), Vector2(620, 90))
	# big sad sheep where Figma has its illustration (chic2: 133,450 621x621)
	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	_place(art, Vector2(0.5, 0.5), Vector2(0, 740 - FH / 2), Vector2(460, 460))
	_sheep_face(art, Vector2(460, 460), Art.wool("W"), false, true)
	var hrow := Control.new()
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hrow)
	_frame(hrow, Vector2(293, 1000), Vector2(300, 150))
	_heart(hrow, Vector2(0, 0), 150, "-1")
	var lh := _label(hrow, "Heart", 48, Color.WHITE, RED_INK, 3)
	_xy(lh, Vector2(150, 0), Vector2(160, 150))
	_lose_msg = _label(root, "", 40, Color.WHITE, BLUE, 2)
	_place(_lose_msg, Vector2(0.5, 0.5), Vector2(0, 1250 - FH / 2), Vector2(700, 130))
	# HOME next to RETRY: with no hearts left RETRY only opens Refill Lives, so the screen must have a way out
	var home := _text_btn(root, "btn_blue", "HOME", BLUE, Vector2.ZERO, Vector2(332, 162), func():
		_hide(_lose)
		home_pressed.emit(), 58)
	_place(home, Vector2(0.5, 0.5), Vector2(-176, 1439 - FH / 2), Vector2(332, 162))
	var retry := _text_btn(root, "btn_green", "RETRY", GREEN_INK, Vector2.ZERO, Vector2(332, 162), func(): retry_pressed.emit(), 58)
	_place(retry, Vector2(0.5, 0.5), Vector2(176, 1439 - FH / 2), Vector2(332, 162))


# ============================================================ API used by the game
func show_home(level_number: int, unlocked: int) -> void:
	hide_panels()
	_home_level.text = tr("Level %d") % level_number
	_home.visible = true
	_hud.visible = false
	_tip.visible = false
	_banner_t = 0.0
	_banner.visible = false
	_hard.visible = false
	_refresh_levels(unlocked)
	_pop(_home)


func show_gameplay() -> void:
	_home.visible = false
	_hud.visible = true
	_tip.visible = false


## Store price (Horus.iap.price) for the offers, if the store returned one.
func set_pack_price(price: String) -> void:
	set_price("starter_pack", price)


func set_no_ads(on: bool) -> void:
	for c in _remove_ads_offer:
		c.visible = not on
	if _shop_noads_btn:
		_shop_noads_btn.set_meta("disabled", on)
		_shop_noads_btn.modulate = Color(0.7, 0.7, 0.7) if on else Color.WHITE
		if on:
			(_shop_noads_btn.get_meta("label") as Label).text = tr("OWNED")


func set_profile(name: String, avatar: String, frame: int, owned: Array, best_level: int) -> void:
	super(name, avatar, frame, owned, best_level)
	_home_avatar.size = Vector2(126, 126)
	_avatar_into(_home_avatar, avatar, frame)


func set_lang(code: String) -> void:
	super(code)
	for cb in _underlines:
		cb.call()


func set_lives(n: int, secs: float) -> void:
	super(n, secs)
	_home_lives_n.text = str(n)
	_home_lives_t.text = tr("Full") if n >= Meta.MAX_LIVES else Meta.fmt_time(secs)


func set_level(n: int) -> void:
	_level.text = tr("Level %d") % n


func set_coins(n: int) -> void:
	for t in _coin_texts:
		t.text = str(n)


func set_road(colors: Array, cap: int) -> void:
	_road_text.text = tr("FREE %d/%d") % [maxi(0, cap - colors.size()), cap]
	while _road_dots.get_child_count() < cap:
		var d := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		d.add_theme_stylebox_override("panel", sb)
		d.custom_minimum_size = Vector2(24, 24)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_road_dots.add_child(d)
	for i in _road_dots.get_child_count():
		var d: Panel = _road_dots.get_child(i)
		d.visible = i < cap
		var sb: StyleBoxFlat = d.get_theme_stylebox("panel")
		sb.bg_color = Art.wool(colors[i]) if i < colors.size() else Color(0.15, 0.3, 0.72, 0.18)
	# full (reference: the counter turns red): red text on a pink sign; otherwise the usual blue on white
	var full := colors.size() >= cap
	_road_bg.modulate = Color("#ffd2d8") if full else Color.WHITE
	_road_text.label_settings.font_color = Color("#e0353f") if full else BLUE


func shake_road() -> void:
	_road_shake = 0.45


## Booster counts and which are unlocked on this level (locked ones show a padlock).
func set_boosters(undo: int, slot: int, hint: int, level_index := 99) -> void:
	for kv in [["undo", undo], ["slot", slot], ["hint", hint]]:
		var b: Dictionary = _badges[kv[0]]
		var open := Meta.unlocked(kv[0], level_index)
		b.lock.visible = not open
		b.icon.modulate = Color.WHITE if open else Color(1, 1, 1, 0.25)
		b.btn.modulate = Color.WHITE if open else Color(0.75, 0.8, 0.9)
		b.badge.visible = open and kv[1] > 0
		b.plus.visible = open and kv[1] <= 0
		b.count.text = str(kv[1])


## Figma "Booster description" card, shown after a booster unlocks.
func show_booster_tip(kind: String) -> void:
	_tip_icon.texture = _tex(BOOSTER_ICON[kind])
	_tip_text.text = tr(BOOSTER_NAME[kind]) + "\n" + tr(BOOSTER_DESC[kind])
	_tip.visible = true
	_tip_t = 4.5
	_pop(_tip)


func toast(msg: String, seconds := 1.5) -> void:
	_toast_text.text = msg
	_toast.visible = true
	_toast_t = seconds
	_pop(_toast)


func banner(text: String, hard := false) -> void:
	_banner_t = 1.8 if hard else 1.3
	_hard.visible = hard
	_banner.visible = not hard
	if hard:
		_hard_text.text = text
		_hard.modulate.a = 1.0
		return
	_banner_text.text = text
	_banner_red.visible = false
	_set_ink(_banner_text, BLUE)
	_pop(_banner)


func _set_ink(l: Label, ink: Color) -> void:
	var ls: LabelSettings = l.label_settings
	ls.outline_color = ink
	ls.shadow_color = ink


func tutorial(text: String) -> void:
	var on := text != ""
	if on and (not _tutorial.visible or _tutorial_text.text != text):
		_pop(_tutorial)
	_tutorial.visible = on
	_tutorial_text.text = text


## Point the hand at a viewport position, or hide it with null.
func point_at(pos) -> void:
	var on: bool = pos != null and not paused()
	_hand.visible = on
	if on:
		var bob := absf(sin(_hand_t * 5.0)) * 22.0
		_hand.position = pos - Vector2(22, 17) + Vector2(bob * 0.5, bob)


func float_text(text: String, pos: Vector2, big: bool) -> void:
	var t := _label(self, text, 84 if big else 68, Color.WHITE, RED_INK if big else BLUE, 3)
	_xy(t, pos - Vector2(450, 70), Vector2(900, 140))
	t.pivot_offset = t.size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(t, "position:y", t.position.y - 240, 1.5)
	tw.tween_property(t, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tw.chain().tween_callback(t.queue_free)
	_pop(t)


func show_win(stars: int, coins: int, is_last: bool) -> void:
	for i in 3:
		_stars[i].modulate = Color.WHITE if i < stars else Color(0.2, 0.22, 0.3, 0.85)
	_win_coins.text = str(coins)
	(_x2_btn.get_meta("label") as Label).text = str(coins)
	_next_label.text = "Home" if is_last else "Continue"
	_x2_btn.visible = true
	_toast.visible = false
	_show(_win)


func hide_x2() -> void:
	_x2_btn.visible = false


## "Keep playing?" offer: free = a +1 Road booster is in stock, else it costs `price` coins.
func show_pre_lose(msg: String, free: bool, price: int, affordable: bool) -> void:
	_lose_msg.text = msg
	_cont_label.text = "FREE" if free else str(price)
	_cont_label.position.x = 0 if free else 40
	_cont_coin.visible = not free
	_cont_btn.modulate = Color.WHITE if (free or affordable) else Color(0.75, 0.75, 0.75)
	_toast.visible = false
	_show(_pre_lose)


func show_lose(msg: String) -> void:
	_lose_msg.text = msg
	_toast.visible = false
	_show(_lose)


func show_booster_offer(kind: String, price: int, _affordable: bool) -> void:
	_boost_kind = kind
	_boost_ui.title.text = BOOSTER_NAME.get(kind, kind)
	(_boost_ui.icon as TextureRect).texture = _tex(BOOSTER_ICON[kind])
	_boost_ui.desc.text = tr(BOOSTER_DESC.get(kind, ""))
	_boost_ui.price.text = str(price)
	_show(_boost_offer)


func close_booster_offer() -> void:
	_hide(_boost_offer)


func hide_panels() -> void:
	_hide_all()


## True while a popup that should freeze the game is open.
func paused() -> bool:
	for o in _stack:
		if o.get_meta("freeze", true):
			return true
	return false


## Android back: close the top popup (true = handled). In a level with nothing open, open Pause.
func handle_back() -> bool:
	if splash_open() or _curtain.visible:
		return true
	if _back_top():
		return true
	if _hud.visible:
		_show(_pause)
		return true
	return false


## Keep clear of the camera cut-out and the gesture bar (insets in viewport pixels).
func apply_insets(top: float, bottom: float) -> void:
	_safe.offset_top = top
	_safe.offset_bottom = -bottom


func _refresh_levels(unlocked: int) -> void:
	for i in _level_buttons.size():
		var e: Dictionary = _level_buttons[i]
		var open := i <= unlocked
		e.btn.set_meta("disabled", not open)
		e.lock.visible = not open
		e.label.visible = open
		e.btn.modulate = Color.WHITE if open else Color(0.62, 0.68, 0.78)


# ============================================================ animation
func _process(delta: float) -> void:
	_hand_t += delta
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.visible = false
	if _banner_t > 0.0:
		_banner_t -= delta
		_hard.modulate.a = clampf(_banner_t / 0.5, 0.0, 1.0)
		if _banner_t <= 0.0:
			_banner.visible = false
			_hard.visible = false
	if _tip_t > 0.0:
		_tip_t -= delta
		if _tip_t <= 0.0:
			_tip.visible = false
	if _road_shake > 0.0:
		_road_shake -= delta
		_road.position = _road_base + Vector2(sin(_hand_t * 60.0) * 18.0 * _road_shake / 0.45, 0)
		if _road_shake <= 0.0:
			_road.position = _road_base
