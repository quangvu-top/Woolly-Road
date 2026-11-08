# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends CanvasLayer
signal finished(ok: bool)
var _rewarded := false
var _left := 0.0
var _claim: Button
var _count: Label
func setup(kind: String, placement: String) -> void:
	_rewarded = kind == "rewarded"
	_left = 3.0 if _rewarded else 1.0
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	bg.add_child(box)
	var title := Label.new()
	title.text = "Simulated %s ad" % ("rewarded" if _rewarded else "interstitial")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var where := Label.new()
	where.text = "placement: %s\n(Horus simulator: the app shows AppLovin MAX here)" % (placement if placement != "" else "-")
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(where)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_count)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var close := Button.new()
	close.text = "Close" if not _rewarded else "Close (no reward)"
	close.pressed.connect(func(): _end(not _rewarded))
	row.add_child(close)
	if _rewarded:
		_claim = Button.new()
		_claim.text = "Claim reward"
		_claim.disabled = true
		_claim.pressed.connect(func(): _end(true))
		row.add_child(_claim)
	_tick(0.0)
func _process(delta: float) -> void:
	_tick(delta)
func _tick(delta: float) -> void:
	_left = maxf(0.0, _left - delta)
	if _claim:
		_claim.disabled = _left > 0.0
	_count.text = ("watch %.0f s more for the reward" % ceilf(_left)) if _rewarded and _left > 0.0 else ""
func _end(ok: bool) -> void:
	finished.emit(ok)
	queue_free()
