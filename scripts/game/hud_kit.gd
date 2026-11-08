class_name HudKit
extends Control
## Builders shared by every screen (Figma "Bus Dash" kit) and the popup stack.
## The viewport is the Figma frame (886x1920) and the project stretches canvas_items/expand, so every number
## passed to these helpers is a Figma pixel.
##   Hud      (hud.gd)      : home, gameplay HUD, pause, settings, levels, keep playing, win, lose + the API
##   HudMeta  (hud_meta.gd) : splash, transitions, daily gift, profile, language, lives, offers, shop, unlock...
##   HudKit   (this file)   : images, labels, buttons, popups, the overlay stack, Android back

const FW := 886.0
const FH := 1920.0
const BLUE := Color("#274cb7")
const NAV_BLUE := Color("#3d70f3")
const GREEN_INK := Color("#2d7f15")
const RED_INK := Color("#a3123a")
const YELLOW_INK := Color("#b5650a")
const DIM := Color(0, 0, 0, 0.8)   # Bus Dash darkens the game to ~20% behind popups

## Figma export scale of each PNG (pixels per Figma px) and 9-slice borders in texture px (left, top, right, bottom).
const SCALE := {
	"popup": 1.5, "popup_inset": 1.5, "ribbon_red": 1.5, "ribbon_blue": 1.5, "win_horn_big": 1.5, "win_horn_small": 1.5,
	"btn_green": 1.5, "btn_yellow": 1.5, "btn_blue": 1.5, "btn_red": 1.5, "btn_grey": 1.5, "btn_play": 1.5,
	"bar_bottom": 1.5, "tab_home": 1.5, "coin_pile": 1.5, "tg_sound_on": 1.5, "tg_sound_off": 1.5, "tg_music_on": 1.5,
	"tg_music_off": 1.5, "tg_haptic_on": 1.5, "tg_haptic_off": 1.5,
	"ic_close": 2.0, "pill_dark": 2.0, "pill_level": 2.0, "btn_pause": 2.0, "btn_retry": 2.0, "btn_booster": 2.0,
	"ic_nav_right": 2.0, "ic_starterpack": 2.0, "ic_removeads": 2.0, "avatar_frame": 2.0, "label_white": 2.0,
	"ic_settings": 2.5, "ic_home": 3.5,
	"dg_board": 2.0, "dg_inner": 2.0, "dg_title": 2.0, "ic_heart_big": 2.0, "ic_check": 2.0, "ic_edit": 2.0,
	"ic_noads": 2.0, "ribbon_noads": 2.0, "ic_star_small": 2.0, "unlock_glow": 2.0,
	"bar_track": 2.0, "bar_fill": 2.0, "hard_band": 1.5, "ic_hardlvl": 2.0,
}
const BORDER := {
	"popup": [70, 250, 70, 70], "popup_inset": [60, 60, 60, 60], "pill_dark": [90, 60, 90, 60], "pill_level": [100, 0, 100, 0],
	"btn_green": [100, 0, 100, 0], "btn_yellow": [100, 0, 100, 0], "btn_blue": [100, 0, 100, 0], "btn_red": [100, 0, 100, 0],
	"btn_grey": [100, 0, 100, 0], "btn_play": [150, 0, 150, 0], "label_white": [60, 0, 60, 0],
	"dg_board": [90, 90, 90, 90], "dg_inner": [70, 70, 70, 70], "bar_track": [70, 0, 70, 0], "bar_fill": [54, 0, 54, 0],
}

var _font: FontVariation          # every label uses this; its base font switches for Vietnamese (see set_ui_font)
var _lilita: Font
var _system_bold: SystemFont
var _top: Control                 # toasts and transitions: always above the popups
var _stack: Array[Control] = []   # open overlays, bottom -> top


func _init_kit() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lilita = load("res://assets/fonts/LilitaOne-Regular.ttf")
	_system_bold = SystemFont.new()
	_system_bold.font_names = PackedStringArray(["Segoe UI Black", "Roboto Black", "Roboto", "Noto Sans", "Arial", "sans-serif"])
	_system_bold.font_weight = 900
	_font = FontVariation.new()
	_font.base_font = _lilita


## Lilita One has no Vietnamese letters (51 missing): use the system's heaviest sans for "vi".
func set_ui_font(lang: String) -> void:
	_font.base_font = _system_bold if lang == "vi" else _lilita


# ============================================================ overlay stack
## Show an overlay on top of whatever is open (it remembers what is under it: closing returns there).
func _show(overlay: Control) -> void:
	var under := top_overlay()
	if under and under != overlay:
		under.visible = false   # one popup at a time; it comes back when the one on top closes
	_stack.erase(overlay)
	_stack.append(overlay)
	overlay.visible = true
	move_child(overlay, get_child_count() - 1)
	if _top:
		move_child(_top, get_child_count() - 1)
	if overlay.has_meta("on_show"):
		(overlay.get_meta("on_show") as Callable).call()
	var content := overlay.get_node_or_null("Content")
	if content:
		_pop(content)


func _hide(overlay: Control) -> void:
	var was_top := overlay == top_overlay()
	overlay.visible = false
	_stack.erase(overlay)
	if was_top and not _stack.is_empty():
		_stack[-1].visible = true


## Close everything at once (no popup underneath is revealed).
func _hide_all() -> void:
	for o in _stack:
		o.visible = false
	_stack.clear()


func top_overlay() -> Control:
	return _stack[-1] if not _stack.is_empty() else null


## Open = in the stack (it may be hidden under the popup on top).
func is_open(overlay: Control) -> bool:
	return overlay != null and overlay in _stack


## Android back / the popup's X: run the top overlay's close action. Returns false when nothing is open.
func _back_top() -> bool:
	var o := top_overlay()
	if o == null:
		return false
	var cb: Callable = o.get_meta("back", Callable())
	if cb.is_valid():
		cb.call()
	else:
		_hide(o)
	return true


## A full-screen dim layer that blocks taps. `back` runs for the X button and Android back (default: close).
## `freeze` = true pauses the game while it is open.
func _overlay(name: String, back := Callable(), freeze := true, dim := DIM) -> Control:
	var o := ColorRect.new()
	o.name = name
	o.color = dim
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(o)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.set_meta("back", back if back.is_valid() else func(): _hide(o))
	o.set_meta("freeze", freeze)
	o.visible = false
	return o


func _close_of(o: Control) -> Callable:
	return func(): (o.get_meta("back") as Callable).call()


# ============================================================ builders
static var _tex_cache := {}


static func _tex(name: String) -> Texture2D:
	if name == "":
		return null
	if not _tex_cache.has(name):
		var path := "res://assets/ui/%s.png" % name
		_tex_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[name]


func _full(parent: Control, name: String) -> Control:
	var c := Control.new()
	c.name = name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Top-left placement in the parent's Figma coordinates (resets anchors so the size sticks).
func _xy(c: Control, pos: Vector2, size: Vector2) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = pos
	c.size = size


## Centre-anchored placement in Figma pixels: `anchor` (0..1 of the parent), `centre` offset from it, `size`.
func _place(c: Control, anchor: Vector2, centre: Vector2, size: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = centre.x - size.x / 2.0
	c.offset_right = centre.x + size.x / 2.0
	c.offset_top = centre.y - size.y / 2.0
	c.offset_bottom = centre.y + size.y / 2.0


## Place by the Figma frame's top-left corner, keeping the element centred on screen horizontally.
func _frame(c: Control, pos: Vector2, size: Vector2) -> void:
	_place(c, Vector2(0.5, 0.5), Vector2(pos.x + size.x / 2.0 - FW / 2.0, pos.y + size.y / 2.0 - FH / 2.0), size)


func _place_edges(c: Control, a0: Vector2, a1: Vector2, o0: Vector2, o1: Vector2) -> void:
	c.anchor_left = a0.x
	c.anchor_top = a0.y
	c.anchor_right = a1.x
	c.anchor_bottom = a1.y
	c.offset_left = o0.x
	c.offset_top = o0.y
	c.offset_right = o1.x
	c.offset_bottom = o1.y


## An image. 9-slice textures become a NinePatchRect drawn at the texture's density (scaled down to Figma px),
## others a TextureRect that keeps its aspect. Missing textures fall back to a flat colour.
func _img(parent: Control, name: String, fallback: Color) -> Control:
	var tex := _tex(name)
	if tex == null:
		var cr := ColorRect.new()
		cr.color = fallback
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(cr)
		return cr
	if BORDER.has(name):
		var holder := _NinePatchHolder.new()
		holder.setup(tex, BORDER[name], SCALE.get(name, 1.0))
		parent.add_child(holder)
		return holder
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


## Full-screen background image that covers the screen at any aspect (crops the overflow).
func _cover(parent: Control, name: String, fallback: Color) -> Control:
	var bg := _img(parent, name, fallback)
	if bg is TextureRect:
		(bg as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bg


## A rounded flat panel (cards, cells, tabs) when the kit has no art for it.
func _panel(parent: Control, color: Color, radius := 30, border := Color(0, 0, 0, 0), border_w := 0) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _label(parent: Control, text: String, size: float, color: Color, outline = null, outline_w := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = _font
	ls.font_size = int(size)
	ls.font_color = color
	if outline != null and outline_w > 0.0:
		ls.outline_size = int(outline_w * 2.0)
		ls.outline_color = outline
		ls.shadow_color = outline
		ls.shadow_offset = Vector2(0, outline_w * 1.6)
		ls.shadow_size = 0
	l.label_settings = ls
	parent.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return l


## A pressable image: squashes while held, fires on release inside.
func _btn(parent: Control, tex_name: String, fallback: Color, cb: Callable) -> Control:
	var root := _PressArea.new()
	root.on_press = cb
	parent.add_child(root)
	var bg := _img(root, tex_name, fallback)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.set_meta("bg", bg)
	return root


## A button with a label; position/size relative to the parent's top-left (Figma frame coordinates).
func _text_btn(parent: Control, tex_name: String, text: String, ink: Color, pos: Vector2, size: Vector2, cb: Callable, font_size := 52) -> Control:
	var b := _btn(parent, tex_name, Color("#5cc24a"), cb)
	_xy(b, pos, size)
	var l := _label(b, text, font_size, Color.WHITE, ink, 3)
	b.set_meta("label", l)
	return b


## Yellow "[ad] Watch Ads" button.
func _ads_btn(parent: Control, pos: Vector2, size: Vector2, cb: Callable, text := "Watch Ads") -> Control:
	var b := _text_btn(parent, "btn_yellow", text, YELLOW_INK, pos, size, cb, 44)
	(b.get_meta("label") as Label).position.x = 36
	_ad_icon(b, Vector2(30, size.y / 2.0 - 36))
	return b


## Green "[coin] N" button. The label is in meta "label".
func _coin_btn(parent: Control, pos: Vector2, size: Vector2, price: int, cb: Callable) -> Control:
	var b := _text_btn(parent, "btn_green", str(price), GREEN_INK, pos, size, cb, 56)
	var coin := _img(b, "ic_gold", Color("#ffc93c"))
	_xy(coin, Vector2(size.x * 0.18, size.y / 2.0 - 42), Vector2(85, 85))
	(b.get_meta("label") as Label).position.x = 40
	return b


func _ad_icon(btn: Control, pos: Vector2) -> void:
	var ic := _img(btn, "ic_watchads", Color("#8a5a00"))
	_xy(ic, pos, Vector2(72, 72))


## Popup panel (Figma popup3): title and close button; children use the panel's top-left (Figma) coordinates.
func _popup(parent: Control, title: String, size: Vector2, on_close: Callable) -> Control:
	var panel := _img(parent, "popup", Color("#eef2fb"))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size = size
	var t := _label(panel, title, 76, Color.WHITE, BLUE, 3)
	t.set_anchors_preset(Control.PRESET_TOP_WIDE)
	t.offset_top = 22
	t.offset_bottom = 122
	t.offset_left = 90
	t.offset_right = -90
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.clip_text = false
	panel.set_meta("title", t)
	var close := _btn(panel, "ic_close", BLUE, on_close)
	close.anchor_left = 1
	close.anchor_right = 1
	close.offset_left = -96
	close.offset_right = -40
	close.offset_top = 47
	close.offset_bottom = 103
	return panel


## The usual Bus Dash popup: overlay + 752-wide panel with its Figma top-left y, and the light inset box.
func _std_popup(name: String, title: String, h: float, top_y: float, back := Callable()) -> Control:
	var o := _overlay(name, back)
	var content := _full(o, "Content")
	var panel := _popup(content, title, Vector2(752, h), _close_of(o))
	_frame(panel, Vector2(67, top_y), Vector2(752, h))
	o.set_meta("panel", panel)
	return o


## Offer card of the Bus Dash shop (Remove Ads Bundle / Starter Pack / Helper Pack): white rim, `top` body and a
## darker `strip` of height `strip_h` along the bottom for the name and the price. Children use its top-left.
func _card(parent: Control, pos: Vector2, size: Vector2, top: Color, strip: Color, strip_h: float) -> Panel:
	var card := _panel(parent, top, 46, Color.WHITE, 10)
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel")
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 6)
	_xy(card, pos, size)
	if strip_h > 0.0:
		var s := _panel(card, strip, 0)
		var sb2: StyleBoxFlat = s.get_theme_stylebox("panel")
		sb2.corner_radius_bottom_left = 36
		sb2.corner_radius_bottom_right = 36
		_xy(s, Vector2(10, size.y - 10 - strip_h), Vector2(size.x - 20, strip_h))
	return card


## Name on a card strip (left aligned) and the green price button on its right; returns the button.
func _card_footer(card: Panel, title: String, ink: Color, strip_h: float, price: String, cb: Callable, btn := Vector2(258, 90), font := 52.0) -> Control:
	var y := card.size.y - 10 - strip_h
	var t := _label(card, title, font, Color.WHITE, ink, 3)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	_xy(t, Vector2(50, y), Vector2(460, strip_h))
	return _text_btn(card, "btn_green", price, GREEN_INK, Vector2(card.size.x - 50 - btn.x, y + (strip_h - btn.y) / 2.0), btn, cb, 44)


## A rounded darker tile inside a card (the coin and booster boxes).
func _tile(parent: Control, pos: Vector2, size: Vector2, color: Color) -> Panel:
	var t := _panel(parent, color, 34)
	_xy(t, pos, size)
	return t


## Item in a tile: icon on top, white count under it.
func _item(parent: Control, icon: String, count: String, ink: Color, pos: Vector2, icon_size := 100.0, font := 46.0) -> void:
	var ic := _img(parent, icon, Color.WHITE)
	_xy(ic, pos, Vector2(icon_size, icon_size))
	var n := _label(parent, count, font, Color.WHITE, ink, 3)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	_xy(n, pos + Vector2(-30, icon_size - 6), Vector2(icon_size + 60, font * 1.3))


func _inset(panel: Control, pos: Vector2, size: Vector2) -> Control:
	var inset := _img(panel, "popup_inset", Color("#dfe6f5"))
	_xy(inset, pos, size)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return inset


## Big heart with a number on it (Refill Lives / Full of Heart / "-1" warnings).
func _heart(parent: Control, pos: Vector2, size: float, text: String) -> Label:
	var h := _img(parent, "ic_heart_big", Color("#ff4d5e"))
	_xy(h, pos, Vector2(size, size))
	return _label(h, text, size * 0.3, Color.WHITE, RED_INK, 3)


## Cute sheep face drawn with circles (avatar, flock art, sad lose sheep). Centred in `parent` (any size).
func _sheep_face(parent: Control, size: Vector2, wool := Color("#fff6ee"), bg := true, sad := false) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	_xy(root, (parent.size - size) / 2.0 if parent.size != Vector2.ZERO else Vector2.ZERO, size)
	var dot := func(c: Color, x: float, y: float, w: float, h: float):
		var d := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(size.x))
		sb.anti_aliasing = true
		d.add_theme_stylebox_override("panel", sb)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(d)
		d.size = Vector2(w, h) * size.x
		d.position = Vector2(0.5 + x - w / 2.0, 0.5 - y - h / 2.0) * size.x
	if bg:
		dot.call(Color("#bfe7ff"), 0, 0, 1.0, 1.0)
	for i in 7:
		var a := i / 7.0 * TAU
		dot.call(wool.darkened(0.08), cos(a) * 0.29, sin(a) * 0.27 + 0.03, 0.44, 0.44)
	for i in 7:
		var a := i / 7.0 * TAU + 0.4
		dot.call(wool, cos(a) * 0.25, sin(a) * 0.23 + 0.05, 0.38, 0.38)
	var ear_y := -0.02 if sad else 0.02
	dot.call(Art.FACE, -0.27, ear_y, 0.2, 0.12)
	dot.call(Art.FACE, 0.27, ear_y, 0.2, 0.12)
	dot.call(Art.FACE, 0, -0.06, 0.42, 0.48)
	dot.call(wool, 0, 0.17, 0.36, 0.2)
	dot.call(Color.WHITE, -0.08, -0.04, 0.11, 0.13)
	dot.call(Color.WHITE, 0.08, -0.04, 0.11, 0.13)
	if sad:
		dot.call(Color("#1d1a22"), -0.08, -0.07, 0.055, 0.05)   # pupils looking down
		dot.call(Color("#1d1a22"), 0.08, -0.07, 0.055, 0.05)
		dot.call(Art.FACE, -0.08, 0.015, 0.13, 0.05)            # heavy lids
		dot.call(Art.FACE, 0.08, 0.015, 0.13, 0.05)
		dot.call(Color("#8fd3ff"), -0.13, -0.15, 0.045, 0.09)   # tears
		dot.call(Color("#8fd3ff"), 0.13, -0.15, 0.045, 0.09)
		dot.call(Color("#2a2330"), 0, -0.2, 0.1, 0.035)         # little frown
	else:
		dot.call(Color("#1d1a22"), -0.075, -0.05, 0.055, 0.07)
		dot.call(Color("#1d1a22"), 0.085, -0.05, 0.055, 0.07)
		dot.call(Color("#ff9cc8"), -0.15, -0.15, 0.08, 0.05)
		dot.call(Color("#ff9cc8"), 0.15, -0.15, 0.08, 0.05)
	return root


## Three happy sheep (offers, daily gift, win): wool colours left, right, centre (centre is bigger, in front).
func _flock(parent: Control, centre: Vector2, size: float, cols := ["B", "Y", "P"]) -> Control:
	var flock := Control.new()
	flock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(flock)
	_xy(flock, centre - Vector2(size, size) / 2.0, Vector2(size, size))
	var k := size / 415.0
	for f in [[-120, -40, 180, cols[0]], [120, -40, 180, cols[1]], [0, -75, 220, cols[2]]]:
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flock.add_child(slot)
		var s: float = f[2] * k
		_xy(slot, Vector2(size / 2.0 + f[0] * k - s / 2.0, size / 2.0 + f[1] * k - s / 2.0), Vector2(s, s))
		_sheep_face(slot, Vector2(s, s), Art.wool(f[3]), false)
	return flock


func _pop(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(0.65, 0.65)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Draws a 9-slice texture at its own density (e.g. 1.5x) and scales it down to fill this control's Figma-px size.
class _NinePatchHolder extends Control:
	var _np: NinePatchRect
	var _k := 1.0

	func setup(tex: Texture2D, border: Array, k: float) -> void:
		_k = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_np = NinePatchRect.new()
		_np.texture = tex
		_np.patch_margin_left = border[0]
		_np.patch_margin_top = border[1]
		_np.patch_margin_right = border[2]
		_np.patch_margin_bottom = border[3]
		_np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_np)
		resized.connect(_fit)

	func _fit() -> void:
		_np.position = Vector2.ZERO
		_np.size = size * _k
		_np.scale = Vector2.ONE / _k


## Touch area with a squash-on-hold effect; calls on_press when released inside.
## Drags (scrolling the shop) cancel the press.
class _PressArea extends Control:
	var on_press := Callable()
	var pass_drag := false   # inside a ScrollContainer: let the press bubble so dragging scrolls
	var silent := false      # no press animation (the hidden cheat door must not look like a button)
	var _down := false
	var _at := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _gui_input(e: InputEvent) -> void:
		if _down and pass_drag and (e is InputEventMouseMotion or e is InputEventScreenDrag) and e.position.distance_to(_at) > 24.0:
			_down = false
			scale = Vector2.ONE
			return
		var is_press: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
		if not is_press:
			return
		if e.pressed:
			if get_meta("disabled", false):
				return
			_down = true
			_at = e.position
			pivot_offset = size / 2.0
			if not silent:
				scale = Vector2(0.92, 0.92)
			if not pass_drag:
				accept_event()
		elif _down:
			_down = false
			scale = Vector2.ONE
			accept_event()
			if Rect2(Vector2.ZERO, size).has_point(e.position) and on_press.is_valid():
				on_press.call()
