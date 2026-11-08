class_name WoollyGame
extends Node3D
## Real-time game: road traffic, pens, push-out, clears, win/lose, boosters, tutorial tips, camera fit,
## plus the Horus SDK hooks (rewarded ads, interstitial pacing, analytics). Port of the Unity WoollyGame /
## prototype game.js. The board is built from primitives, so the scene only needs this node.

enum Mode { MENU, INTRO, PLAY, WON, LOST }

const TRACK_SPEED := 4.4
const WALK := 4.8
const GAP := 1.05
const PRAISE := ["Baa-rilliant!", "Ewe did it!", "Woolly good!", "Shear joy!", "Lamb-tastic!", "Fleece-tastic!"]
const BOOSTER_KINDS := ["undo", "slot", "hint"]
const QUEUE_YAW := PI      # queue sheep face up the screen, towards the road
const QUEUE_SHOWN := 3     # queue rows the gameplay camera shows; the rest of the line runs under the boosters

var mode := Mode.MENU
var level_index := 0
var paused_by_app := false   # Horus "pause" (app in background or an ad covering the game)

var hud: Hud
var store: HorusSaveStore
var S := {}                  # the save (see main.gd defaults)

var _cam: Camera3D
var _world: Node3D
var _flock: Node3D
var _fx: FarmFx
var _lay: RoadLayout
var _level := {}
var _sheep: Array[Sheep] = []
var _road: Array[Sheep] = []
var _pens: Array = []        # [{sheep: Array[Sheep], pending: bool, clearing: bool}]
var _queues: Array = []      # [Array[Sheep]]
var _joiners: Array = []     # per queue column: sheep sent from it still on their way to the road, in order
var _timers: Array = []      # [{at, fn}]
var _history: Array = []
var _tips: Array = []
var _tip_showing := false
var _tip_until := 0.0
var _t := 0.0
var _cam_shake := 0.0
var _cam_base := Vector3.ZERO
var _cam_target := Vector3.ZERO
var _last_size := Vector2.ZERO
var _menu_view := false
var _cap_bonus := 0
var _ring := 0.0            # arc position of road slot 0; the cap_now() slots are spread evenly and go round together
var _full_flash := 0.0      # extra red on the kerbs after a tap on a full road (fades)
var _boosters_used := 0
var _entries := 0
var _stuck_t := 0.0
var _combo := 0
var _last_clear_t := -9.0
var _tut_step := 0
var _tut_pushed := false
var _tut_held: Sheep = null
var _hint_target := Callable()
var _reward := 0
var _x2_taken := false
var _session_start := 0.0
var _load_id := 0


func setup(h: Hud, st: HorusSaveStore, save: Dictionary) -> void:
	hud = h
	store = st
	S = save
	_session_start = Time.get_ticks_msec() / 1000.0
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.near = 0.3
	_cam.far = 200.0
	add_child(_cam)
	_cam.make_current()
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.55
	sun.light_color = Color("#fff4e2")
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.55
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(28), 0)
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#bfe8ff")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb4a8")
	env.ambient_light_energy = 0.32
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_flock = Node3D.new()
	add_child(_flock)
	_fx = FarmFx.new()
	add_child(_fx)


func persist() -> void:
	store.save(S)


func booster_price() -> int:
	return maxi(1, int(Horus.rc.number("booster_price", 60.0)))


# ------------------------------------------------------------ level flow
func go_home() -> void:
	_load_id += 1
	load_level(int(S.unlocked), false, true)
	hud.show_home(int(S.unlocked) + 1, int(S.unlocked))


func lose_life() -> void:
	Meta.lose_life(S, Time.get_unix_time_from_system())
	persist()


func load_level(i: int, intro := true, menu := false) -> void:
	_clear_all()
	level_index = i
	_level = Levels.get_level(i)
	_lay = RoadLayout.new(_level.lanes.size(), _level.queues.size())
	_place_queue()
	_build_world()
	_cap_bonus = 0
	_ring = 0.0
	_boosters_used = 0
	_history.clear()
	_entries = 0
	_stuck_t = 0.0
	_combo = 0
	_last_clear_t = -9.0
	_tut_step = 0
	_tut_pushed = false
	_tut_held = null
	hud.coach_hide()
	_x2_taken = false
	_pens = []
	for _l in _level.lanes:
		_pens.append({sheep = [], pending = false, clearing = false})
	_queues = []
	for _q in _level.queues:
		_queues.append([])
	_tips.clear()
	_tip_showing = false
	hud.tutorial("")
	_set_hint(Callable())
	hud.hide_panels()
	_build_from(Puzzle.from_level(_level), intro and not menu)
	_menu_view = menu
	_fit_camera()
	hud.set_level(i + 1)
	if not menu:
		hud.show_gameplay()
	_refresh_hud()
	Horus.crash_keys({map = "level_%d" % (i + 1), screen = "home" if menu else "game"})
	if menu:
		mode = Mode.MENU
		return
	mode = Mode.INTRO
	Horus.an.log("level_start", {level = i + 1})
	_load_id += 1
	var id := _load_id
	# Bus Dash "New booster unlocked!": first time a level brings a booster, before play starts
	var unlock := Meta.unlock_on(i)
	if unlock != "" and not (unlock in S.get("seen_unlock", [])):
		hud.show_unlock(unlock)
		await hud.unlock_done
		if id != _load_id:
			return
		S.seen_unlock = S.get("seen_unlock", []) + [unlock]
		persist()
		hud.show_booster_tip(unlock)
	if intro:
		if _level.get("hard", false):
			hud.banner(tr("HARD LEVEL"), true)
		else:
			hud.banner(tr("Level %d") % (i + 1))
	_after(1.5 if intro else 0.1, func():
		mode = Mode.PLAY
		_on_play_start())


func _build_from(st: Dictionary, intro: bool) -> void:
	_joiners = []
	for _q in st.queues:
		_joiners.append([])
	var d := 0
	for i in st.lanes.size():
		for j in st.lanes[i].size():
			var s := _spawn(st.lanes[i][j])
			s.state = Sheep.State.LANE
			s.rest_yaw = _lane_yaw(s)
			s.place(_lay.slot_pos(i, j), s.rest_yaw)
			_pens[i].sheep.append(s)
			if intro:
				s.drop_in(0.15 + d * 0.05 + randf() * 0.05)
				d += 1
	for c in st.queues.size():
		for k in st.queues[c].size():
			var s := _spawn(st.queues[c][k])
			s.state = Sheep.State.QUEUE
			s.rest_yaw = QUEUE_YAW
			s.place(_lay.queue_pos(c, k), s.rest_yaw)
			_queues[c].append(s)
			if intro:
				s.drop_in(0.15 + d * 0.05)
				d += 1
	for k in st.track.size():
		var s := _spawn(st.track[k])
		s.state = Sheep.State.TRACK
		s.slot = k % cap_now()
		s.s = _slot_s(s.slot)
		s.v = 0.0
		s.place(_lay.track.point_at(s.s), 0.0)
		_road.append(s)


## Pen sheep face the player (down the screen), with a little random tilt so the rows look alive.
static func _lane_yaw(s: Sheep) -> float:
	return s.jit * 0.5


func _spawn(c: String) -> Sheep:
	var s := Sheep.create(c)
	_flock.add_child(s)
	_sheep.append(s)
	return s


func _remove_sheep(s: Sheep) -> void:
	if not _sheep.has(s):
		return
	_sheep.erase(s)
	_road.erase(s)
	s.queue_free()


func _clear_all() -> void:
	for s in _sheep:
		s.queue_free()
	_sheep.clear()
	_road.clear()
	_timers.clear()
	if _fx:
		_fx.clear()
	if _world:
		_world.queue_free()
		_world = null


func _after(sec: float, fn: Callable) -> void:
	_timers.append({at = _t + sec, fn = fn})


# ------------------------------------------------------------ placeholder world
func _build_world() -> void:
	_world = FarmWorld.build(self, _lay, _level, level_index)


# ------------------------------------------------------------ camera
func _fit_camera() -> void:
	var vp := get_viewport().get_visible_rect().size
	_last_size = vp
	if not _menu_view:
		_frame_play(vp)
		return
	var L := _lay
	var W := L.hx + L.road / 2.0 + 0.55
	var top := -(L.hz + L.road / 2.0) - 0.7
	var bottom := L.queue_z0 + 2 * L.slot + 0.7
	var pts: Array[Vector3] = []
	for x in [-W, W]:
		for z in [top, bottom]:
			for y in [0.0, 1.0]:
				pts.append(Vector3(x, y, z))
	var dist := _frame(vp, pts, top, bottom, 0.4, -0.4, 0.72, 58.0, false)
	# camera down along its own up axis -> board floats above the PLAY button
	var shift := 0.4 * dist * tan(deg_to_rad(_cam.fov) * 0.5)
	var down := -_cam.global_transform.basis.y * shift
	_cam_base += down
	_cam_target += down


## Gameplay framing (reference layout, Parking Loop): a 2-lane loop is ~70% of the screen width and every level
## keeps that scale until the loop would pass ~94%; the first QUEUE_SHOWN queue rows end at the top of the
## booster tray (the rest of the line runs on under it). Returns the screen heights (NDC, +1 = top) that
## _place_queue() balances: the loop's centre and the middle of the space between the top bar and the queue.
func _frame_play(vp: Vector2) -> Dictionary:
	var L := _lay
	var R := L.hx + L.road / 2.0 + 0.05
	var rz := L.hz + L.road / 2.0
	var bottom := L.queue_pos(0, QUEUE_SHOWN).z - 0.68   # head and ears of the first hidden sheep (it faces up)
	var loop: Array[Vector3] = []
	for x in [-R, R]:
		for z in [-rz, rz]:
			loop.append(Vector3(x, 0.0, z))
	for x in [-R + 0.4, R - 0.4]:
		loop.append(Vector3(x, 1.0, -L.hz))      # top of a sheep walking on the far road
	var pts: Array[Vector3] = loop.duplicate()
	for x in [-L.stem_half, L.stem_half]:
		pts.append(Vector3(x, 1.08, bottom))
	var bar := 1.0 - 2.0 * (hud.top_bar_bottom() + 24.0) / vp.y
	var y_bot := 1.0 - 2.0 * (hud.tray_top(vp.y) - 6.0) / vp.y
	var x_lim := minf(0.94, 0.70 * R / 2.77)   # 2.77 = R of a 2-lane loop
	_frame(vp, pts, -rz, bottom, bar, y_bot, x_lim, 64.0, true)
	var lo := 9.0
	var hi := -9.0
	for p in loop:
		var y := _ndc_y(p, vp)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	var board_top := _ndc_y(Vector3(0, 1.08, L.queue_z0 - 0.68), vp)   # head of the front queue sheep
	return {loop = (lo + hi) / 2.0, want = (bar + board_top) / 2.0}


func _ndc_y(p: Vector3, vp: Vector2) -> float:
	return 1.0 - _cam.unproject_position(p).y / vp.y * 2.0


## Road between the loop and the queue, sized so the loop + pen sit in the middle of the space above the
## queue. Depends on the screen shape, so it runs before the world is built.
func _place_queue() -> void:
	var vp := get_viewport().get_visible_rect().size
	_lay.set_gap(RoadLayout.MIN_GAP)
	var r := _frame_play(vp)
	if r.loop >= r.want:
		return   # short screen: the loop already reaches the middle with the queue right under it
	var lo := RoadLayout.MIN_GAP
	var hi := 24.0
	for i in 24:
		var m := (lo + hi) / 2.0
		_lay.set_gap(m)
		r = _frame_play(vp)
		if r.loop < r.want:
			lo = m
		else:
			hi = m
	_lay.set_gap((lo + hi) / 2.0)


## Fit the camera (pitch in degrees) so every point is within |x| <= x_lim and y_bot..y_top (NDC), as close as
## possible. anchor_bottom pins the lowest point to y_bot, otherwise the content is centred. Returns the distance.
func _frame(vp: Vector2, pts: Array[Vector3], top: float, bottom: float, y_top: float, y_bot: float,
		x_lim: float, pitch_deg: float, anchor_bottom: bool) -> float:
	var pitch := deg_to_rad(pitch_deg)
	var dir := Vector3(0, sin(pitch), cos(pitch))
	# look target z; an Array because lambdas capture locals by value and the centring passes change it
	var tz: Array[float] = [(top + bottom) / 2.0]

	var test := func(dist: float) -> Dictionary:
		var target := Vector3(0, 0, tz[0])
		_cam.global_position = target + dir * dist
		_cam.look_at(target, Vector3.UP)
		var ok := true
		var ymin := 9.0
		var ymax := -9.0
		for p in pts:
			var sp := _cam.unproject_position(p)
			var nx := sp.x / vp.x * 2.0 - 1.0
			var ny := 1.0 - sp.y / vp.y * 2.0
			if absf(nx) > x_lim:
				ok = false
			ymin = minf(ymin, ny)
			ymax = maxf(ymax, ny)
		return {ok = ok and ymax <= y_top and ymin >= y_bot, ymin = ymin, ymax = ymax}

	var search := func() -> float:
		var lo := 4.0
		var hi := 90.0
		for k in 28:
			var m := (lo + hi) / 2.0
			if test.call(m).ok:
				hi = m
			else:
				lo = m
		return hi

	var want := (y_top + y_bot) / 2.0
	var dist := 0.0
	for pass_i in 5:
		dist = search.call()
		var r: Dictionary = test.call(dist)
		var off: float = (y_bot - r.ymin) if anchor_bottom else (want - (r.ymin + r.ymax) / 2.0)
		# content too low on screen (off > 0) -> move the look target towards the player (+z)
		tz[0] += off * (bottom - top) / maxf(0.1, r.ymax - r.ymin)
	dist = search.call()
	test.call(dist)
	_cam_base = _cam.global_position
	_cam_target = Vector3(0, 0, tz[0])
	return dist


func _apply_camera(dt: float) -> void:
	_cam_shake = maxf(0.0, _cam_shake - dt)
	var k := _cam_shake * _cam_shake * 0.6
	_cam.global_position = _cam_base + Vector3((randf() - 0.5) * k, (randf() - 0.5) * k, sin(_t * 0.4) * 0.05)
	_cam.look_at(_cam_target, Vector3.UP)


# ------------------------------------------------------------ frame + input
func _process(delta: float) -> void:
	if _lay == null:
		return
	if get_viewport().get_visible_rect().size != _last_size:
		_fit_camera()
	if not paused_by_app and not hud.paused():
		step(minf(delta, 1.0 / 20.0))
	_apply_camera(delta)
	_place_road_sign()
	_update_kerbs(delta)


## Road full (reference: the curbs blink red about once a second): the stone kerbs pulse red while every slot is
## taken, and flash once more when a tap is turned away.
func _update_kerbs(dt: float) -> void:
	if _world == null or not _world.has_meta("kerb"):
		return
	var mi: MeshInstance3D = _world.get_meta("kerb")
	var m := mi.material_override as StandardMaterial3D
	if m == null:
		return
	_full_flash = maxf(0.0, _full_flash - dt * 2.0)
	var k := _full_flash
	if road_full():
		k = maxf(k, 0.55 + 0.45 * sin(_t * TAU * 1.1))
	m.albedo_color = FarmWorld.KERB.lerp(Color("#e8463c"), clampf(k, 0.0, 1.0))


## Every road slot is taken (sheep on their way count too, like the reference's counter).
func road_full() -> bool:
	return mode == Mode.PLAY and _road.size() >= cap_now()


## Free-slots sign just under the loop's bottom-right corner, right edge on the loop's outer edge (reference).
func _place_road_sign() -> void:
	if _menu_view:
		return
	var corner := _cam.unproject_position(Vector3(_lay.hx + _lay.road / 2.0, 0.0, _lay.road_outer_z))
	hud.place_road(Vector2(corner.x - Hud.ROAD_SIGN.x / 2.0, corner.y + Hud.ROAD_SIGN.y / 2.0 + 16.0))


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if pressed and not hud.paused():
		tap(event.position)


## Tap: the queue sheep nearest the touch (within ~70 px of its body on screen) sends its column.
func tap(pos: Vector2) -> void:
	if mode != Mode.PLAY:
		return
	var best: Sheep = null
	var best_d := 75.0
	for s in _sheep:
		if not s.visible:
			continue
		var sp := _cam.unproject_position(s.global_position + Vector3(0, 0.55, 0))
		var d := sp.distance_to(pos)
		if d < best_d or (best != null and s.state == Sheep.State.QUEUE and best.state != Sheep.State.QUEUE and d < 75.0):
			best_d = d
			best = s
	if best == null:
		return
	if best.state == Sheep.State.QUEUE:
		for c in _queues.size():
			if _queues[c].has(best):
				if not _tut_allows(c):
					best.nope()
					return
				send(c)
				return
	if best.state == Sheep.State.LANE or best.state == Sheep.State.TRACK:
		best.bleat()
		best.jump(3.0)


func cap_now() -> int:
	return int(_level.cap) + _cap_bonus


func send(c: int) -> void:
	var q: Array = _queues[c]
	if q.is_empty():
		return
	var s: Sheep = q[0]
	if _road.size() >= cap_now():
		# like the reference: no message; the sheep shakes its head, the sign jolts, the kerbs flash red
		hud.shake_road()
		s.nope()
		s.bleat()
		_full_flash = 1.0
		return
	_history.append(snapshot())
	if _history.size() > 40:
		_history.pop_front()
	q.pop_front()
	s.state = Sheep.State.JOINING
	s.rest_yaw = null
	_road.append(s)
	# like the reference: every tap sends a sheep at once, it runs in one go and joins the road where it arrives.
	# Its pace (within a narrow band) is picked so it arrives in a gap between the sheep already going round;
	# sheep sent from the same column run nose to tail, never faster than the one ahead.
	var ms: float = _lay.s_join[c]
	var dest := _lay.track.point_at(ms)
	var J: Array = _joiners[c]
	s.merge_s = ms
	s.join_col = c
	s.slot = -1
	var speed := _join_speed(ms, Vector2(dest.x - s.position.x, dest.z - s.position.z).length())
	if not J.is_empty():
		var front: Sheep = J[J.size() - 1]
		speed = minf(speed, front.speed)
	J.append(s)
	s.walk([dest], speed, func(x: Sheep): _merge_on(x, ms))
	s.jump(3.4)
	s.squash(0.3)
	s.bleat()
	for k in q.size():
		q[k].walk([_lay.queue_pos(c, k)], minf(3.2, speed))   # never faster than the sheep ahead
		q[k].rest_yaw = QUEUE_YAW
	_entries = 0
	_set_hint(Callable())
	_refresh_hud()
	_tutorial_event("send")


## Advance the simulation by dt seconds (also used by tests).
func step(dt: float) -> void:
	_t += dt
	if not _timers.is_empty():
		var due: Array = _timers.filter(func(x): return x.at <= _t)
		if not due.is_empty():
			_timers = _timers.filter(func(x): return x.at > _t)
			for x in due:
				x.fn.call()
	if mode != Mode.MENU:
		_update_road(dt)
	for s in _sheep.duplicate():
		if is_instance_valid(s):
			s.tick(dt, _t)
			_walk_dust(s, dt)
	_fx.tick(dt)
	if mode == Mode.PLAY:
		_check_clears()
		_check_end(dt)
	_update_tips()
	_update_hand()


## Little dust puffs behind sheep walking on the road (green-ish on the pen floor).
func _walk_dust(s: Sheep, dt: float) -> void:
	if not s.visible or not (s.track_moving or (s.moving and s.state != Sheep.State.LANE)):
		return
	var t: float = s.get_meta("dust_t", randf() * 0.2) - dt
	if t <= 0.0:
		t = 0.16 + randf() * 0.08
		_fx.dust(s.position, 1, Color("#e3f5c4") if s.state == Sheep.State.ENTERING else Color("#e8d3ae"))
	s.set_meta("dust_t", t)


# ------------------------------------------------------------ rules
func _can_enter(i: int, color: String) -> bool:
	var l: Dictionary = _pens[i]
	if l.pending:
		return false
	if l.sheep.size() > 0:
		return l.sheep[l.sheep.size() - 1].color == color
	for o in _pens:
		if not o.pending and o.sheep.size() > 0 and o.sheep[o.sheep.size() - 1].color == color:
			return false
	return true


func _any_enter(color: String) -> bool:
	for i in _pens.size():
		if _can_enter(i, color):
			return true
	return false


func _enter_lane(s: Sheep, i: int) -> void:
	var lane: Dictionary = _pens[i]
	_road.erase(s)
	s.slot = -1
	s.state = Sheep.State.ENTERING
	s.rest_yaw = null
	s.track_moving = false
	_entries += 1
	var pushed: Sheep = null
	if lane.sheep.size() >= Puzzle.LANE_CAP:
		pushed = lane.sheep.pop_front()
	lane.sheep.append(s)
	for j in lane.sheep.size():
		var o: Sheep = lane.sheep[j]
		if o == s:
			continue
		if o.state == Sheep.State.LANE:
			o.speed = 3.4
		o.retarget(_lay.slot_pos(i, j))
	s.walk([_lay.lane_top(i), _lay.slot_pos(i, lane.sheep.size() - 1)], WALK, func(x: Sheep):
		x.state = Sheep.State.LANE
		x.rest_yaw = _lane_yaw(x)
		x.squash(0.22)
		_fx.dust(x.position, 2, Color("#e3f5c4")))
	if pushed != null:
		pushed.stop_walking()
		pushed.state = Sheep.State.TRACK
		pushed.rest_yaw = null
		pushed.s = _lay.s_out[i]
		pushed.slot = -1
		pushed.v = 0.8
		pushed.blend = 1.0
		pushed.blend_from = pushed.position
		_road.append(pushed)
		pushed.jump(4.2)
		_fx.dust(pushed.position, 4)
		pushed.bleat()
		if _road_clear_at(pushed.s):
			_assign_ordered()            # drops into the gap at the pen exit
		else:
			_wait_at_exit(pushed, i)     # a sheep is passing right there: step out when the road is clear
		_tutorial_event("push", i, pushed)
	if lane.sheep.size() == Puzzle.LANE_CAP and lane.sheep.all(func(o): return o.color == s.color):
		lane.pending = true
	_tutorial_event("enter", i)
	_refresh_hud()


func _check_clears() -> void:
	for i in _pens.size():
		var lane: Dictionary = _pens[i]
		if not lane.pending or lane.clearing:
			continue
		if not lane.sheep.all(func(x): return x.state == Sheep.State.LANE and x.path.is_empty()):
			continue
		lane.clearing = true
		var list: Array = lane.sheep.duplicate()
		var centre := Vector3(_lay.lane_x[i], 0.05, _lay.slot_pos(i, 1.5).z)
		for j in list.size():
			var s: Sheep = list[j]
			s.state = Sheep.State.CLEARING
			_after(0.05 + j * 0.09, func():
				s.jump(6.5)
				s.bleat())
			_after(0.33 + j * 0.09, func():
				_fx.burst(s.position + Vector3(0, 0.7, 0), Art.wool(s.color))
				_remove_sheep(s))
		_after(0.4 + list.size() * 0.09, func():
			lane.sheep.clear()
			lane.pending = false
			lane.clearing = false
			_on_cleared(centre))


func _on_cleared(centre: Vector3) -> void:
	_combo = _combo + 1 if _t - _last_clear_t < 2.6 else 1
	_last_clear_t = _t
	_cam_shake = 0.3
	var sp := _cam.unproject_position(centre + Vector3(0, 1.2, 0))
	hud.float_text(tr("Combo x%d!") % _combo if _combo > 1 else PRAISE.pick_random(), sp, _combo > 1)
	_earn(10 * _combo, "clear")
	_tutorial_event("clear")


static func _crossed(a: float, b: float, e: float, L: float) -> bool:
	if b < L:
		return a < e and b >= e
	return a < e or (b - L) >= e


## Signed arc distance a -> b along the driving direction, in (-L/2, L/2].
func _arc(a: float, b: float) -> float:
	var L := _lay.track.length
	var d := fposmod(b - a, L)
	return d - L if d > L / 2.0 else d


## Where road slot k is right now.
func _slot_s(k: int) -> float:
	var L := _lay.track.length
	return fposmod(_ring + k * L / cap_now(), L)


## Which sheep may turn into a pen now, and which pen: the same choice as the puzzle model (Puzzle.settle), so
## the real game plays out exactly like the levels were designed and the hints stay right. The oldest sheep on
## the road (in send/push order) that has a pen parks first, in Puzzle.pick_lane's pen; a pen still clearing
## counts as empty (in the model it already is), so sheep wait a lap for it rather than take another.
## Returns {sheep, lane} or {}.
func _next_parker() -> Dictionary:
	var lanes: Array = _pens.map(func(l): return [] if l.pending else l.sheep.map(func(x): return x.color))
	for s in _road:
		var li := Puzzle.pick_lane(lanes, s.color)
		if li >= 0:
			return {sheep = s, lane = li}
	return {}


## A sheep from a column's line is on the road.
func _joined(x: Sheep) -> void:
	var c := x.join_col
	x.join_col = -1
	if c >= 0 and c < _joiners.size():
		(_joiners[c] as Array).erase(x)


## Slots taken by sheep on (or on their way to) the road, except `skip`.
func _taken(skip: Sheep = null) -> Array:
	var used := []
	for o in _road:
		if o != skip and o.slot >= 0:
			used.append(o.slot)
	return used


## Can a sheep at road position `at` reach slot k (as it will be `t` seconds from now) without running through
## another sheep? Sheep keep their order on the road, so the slot must lie between its neighbours, and nobody may
## be right at the spot. offroad: it waits beside the road, so sheep passing in front of it do not matter.
func _slot_clear(at: float, k: int, t: float, used: Array, offroad: bool) -> bool:
	var L := _lay.track.length
	var d := _arc(at, fposmod(_slot_s(k) + TRACK_SPEED * t, L))
	for j in used:
		var dj := _arc(at, fposmod(_slot_s(j) + TRACK_SPEED * t, L))
		if not offroad and absf(dj) < 1.3:
			return false                      # someone is right there
		if d > 0.0 and dj > -1.3 and dj < d:
			return false                      # it would have to run through that sheep to catch its slot
		if d < 0.0 and not offroad and dj < 0.0 and dj > d:
			return false                      # that sheep would run into it while it lets its slot come round
	return true


## The free slot nearest to road position `at` that is clear (see _slot_clear) right now, or -1.
func _pick_slot(at: float, offroad: bool, skip: Sheep = null) -> int:
	var used := _taken(skip)
	var best := -1
	var best_d := INF
	for k in cap_now():
		if k in used or not _slot_clear(at, k, 0.0, used, offroad):
			continue
		var d := absf(_arc(at, _slot_s(k)))
		if d < best_d:
			best = k
			best_d = d
	return best


## Running pace for a sent sheep that has `d` to go to the join point at road position `ms`: within a narrow
## band round the usual pace, the one that lands it farthest from the sheep going round (so it slips into a gap).
const JOIN_V := 5.5


func _join_speed(ms: float, d: float) -> float:
	var L := _lay.track.length
	var best_v := JOIN_V
	var best_room := -INF
	for i in 11:
		var v := JOIN_V * lerpf(0.8, 1.3, i / 10.0)
		var t := d / v
		var room := INF
		for o in _road:
			if o.state != Sheep.State.TRACK or o.hold:
				continue
			# where it will be: on its slot's line if it has one, else at the road's pace
			var at: float = (_slot_s(o.slot) if o.slot >= 0 else o.s) + TRACK_SPEED * t
			room = minf(room, absf(_arc(ms, fposmod(at, L))))
		var score := minf(room, 2.5) - absf(v - JOIN_V) * 0.05   # enough room first, then the usual pace
		if score > best_room:
			best_room = score
			best_v = v
	return best_v


## Will the road at `ms` be clear (nobody within a body's length) `eta` seconds from now, at today's speeds?
func _merge_clear(ms: float, eta: float) -> bool:
	return _merge_room(ms, eta) >= 1.25


func _merge_room(ms: float, eta: float) -> float:
	var L := _lay.track.length
	var room := INF
	for o in _road:
		if o.state == Sheep.State.TRACK and not o.hold:
			# where it will be at its current pace, and where its slot will be (it is closing in on it): count both
			room = minf(room, absf(_arc(ms, fposmod(o.s + o.v * eta, L))))
			if o.slot >= 0:
				room = minf(room, absf(_arc(ms, fposmod(_slot_s(o.slot) + TRACK_SPEED * eta, L))))
	return room


## Steer the sheep running from the queue to the road, every frame (reference: cars launch at once and slip into
## the traffic). Each picks the pace that brings it to the road in a gap. Before it gets close enough to touch the
## sheep going round (MERGE_HOLD from the middle of the road) it checks the road is really clear there; then it is
## committed and goes on, and sheep coming up behind make room for it. If it is not clear it waits at that spot,
## out of everyone's way. Sheep from the same column keep their distance behind the one ahead.
const MERGE_HOLD := 1.3
const MERGE_TOUCH := 0.75   # closer than this to the middle of the road it would touch a sheep going past
const BRAKE := 14.0         # how hard a running sheep can slow down (units/s²)


## Top speed that still lets a sheep stop within `room` (eases into a stop instead of stopping dead).
static func _brake_to(room: float, dt: float) -> float:
	return minf(sqrt(2.0 * BRAKE * maxf(0.0, room)), maxf(0.0, room) / maxf(dt, 1e-4))


func _steer_joiners(dt: float) -> void:
	var L := _lay.track.length
	for s in _road:
		if s.state != Sheep.State.JOINING or s.path.is_empty() or s.join_col < 0:
			continue
		var dest: Vector3 = s.path[s.path.size() - 1]
		var r := Vector2(dest.x - s.position.x, dest.z - s.position.z).length()
		var want := JOIN_V
		if not s.committed:
			var best := -INF
			for i in 9:
				var v := JOIN_V * lerpf(0.4, 1.45, i / 8.0)
				var score := minf(_merge_room(s.merge_s, r / v), 2.0) - absf(v - s.speed) * 0.08 - absf(v - JOIN_V) * 0.03
				if score > best:
					best = score
					want = v
		var J: Array = _joiners[s.join_col]
		var idx := J.find(s)
		var gap := INF
		if idx > 0:
			var f: Sheep = J[idx - 1]
			gap = Vector2(f.position.x - s.position.x, f.position.z - s.position.z).length()
			if gap < 1.6:
				want = minf(want, f.speed * gap / 1.6)
		s.speed = maxf(1.2, s.speed + (want - s.speed) * minf(1.0, dt * 10.0))
		if gap < INF:
			s.speed = minf(s.speed, _brake_to(gap - 1.15, dt))   # never into the one ahead
		if not s.committed and r <= MERGE_HOLD + s.speed * s.speed / (2.0 * BRAKE) + s.speed * dt + 0.05:
			# the road right now: room behind for the sheep coming up to give way, nobody just ahead
			var clear := true
			for o in _road:
				if o.state == Sheep.State.TRACK and not o.hold:
					var behind := fposmod(s.merge_s - o.s, L)   # how far it still has to come
					var ahead := fposmod(o.s + o.v * r / maxf(s.speed, 1.2) - s.merge_s, L)   # how far past it will be when we get there
					if behind < 1.5 or ahead < 1.4:
						clear = false
			if clear:
				# the ones behind it from the same column go with it, nose to tail (the reference's cars do)
				for i in range(maxi(0, idx), J.size()):
					(J[i] as Sheep).committed = true
			else:
				s.speed = minf(s.speed, _brake_to(r - MERGE_HOLD, dt))   # ease to a stop just short of the road
		elif s.committed:
			# committed: still never into a sheep that is just past the join point (it is moving off); the last
			# MERGE_TOUCH from the middle of the road waits for that, the sheep coming up behind are giving way
			for o in _road:
				if o.state == Sheep.State.TRACK and not o.hold and fposmod(o.s - s.merge_s, L) < 1.2:
					s.speed = minf(s.speed, _brake_to(r - MERGE_TOUCH, dt))
	# the queue never runs up into the sheep that just left it (or into each other) while that one is slow
	for c in _queues.size():
		var q: Array = _queues[c]
		var J: Array = _joiners[c] if c < _joiners.size() else []
		var ahead_pos: Variant = (J[J.size() - 1] as Sheep).position if not J.is_empty() else null
		for k in q.size():
			var qs: Sheep = q[k]
			if ahead_pos != null and not qs.path.is_empty():
				var a: Vector3 = ahead_pos
				var gap := Vector2(a.x - qs.position.x, a.z - qs.position.z).length()
				qs.speed = minf(3.2, maxf(0.0, gap - 1.15) / maxf(dt, 1e-4))
			ahead_pos = qs.position


## A sent sheep reaches the road: it joins at once where it is, and every sheep on the road gets a slot again in
## the even spread, keeping their order (so the newcomer drops into the gap it arrived in, nobody passes anybody).
func _merge_on(x: Sheep, ms: float) -> void:
	_joined(x)
	x.committed = false
	x.state = Sheep.State.TRACK
	x.s = fposmod(ms + x.arrive_left, _lay.track.length)   # carry on along the road by the last frame's leftover
	x.position = _lay.track.point_at(x.s)
	x.v = minf(x.speed, TRACK_SPEED * 1.5)
	# right behind another sheep: fall in at its pace instead of braking hard
	var L := _lay.track.length
	for o in _road:
		if o != x and o.state == Sheep.State.TRACK and not o.hold and fposmod(o.s - x.s, L) < 1.8:
			x.v = minf(x.v, o.v)
	x.blend = 0.0
	x.stop_walking()
	_assign_ordered()


## Give the sheep on the road slots in the current spread (the slot count changed: +1 Road), keeping their
## order round the loop so nobody has to pass anybody, and moving them as little as possible. Sheep still on
## their way keep their slot only if it is free; they pick again when they reach the road.
func _assign_ordered() -> void:
	var L := _lay.track.length
	var n := cap_now()
	var riders: Array[Sheep] = []
	riders.assign(_road.filter(func(x): return x.state == Sheep.State.TRACK and not x.hold))
	riders.sort_custom(func(a, b): return a.s < b.s)
	var others: Array[Sheep] = []
	others.assign(_road.filter(func(x): return not (x in riders)))
	var reserved := []
	for x in others:
		if x.slot >= n or x.slot in reserved:
			x.slot = -1
		elif x.slot >= 0:
			reserved.append(x.slot)
	var free: Array[int] = []
	free.assign(range(n).filter(func(k): return not (k in reserved)))
	free.sort_custom(func(a, b): return _slot_s(a) < _slot_s(b))
	var m := riders.size()
	var nf := free.size()
	if m == 0 or m > nf:
		for x in riders:
			x.slot = -1
		return
	var best_cost := INF
	var best: Array[int] = []
	for r in nf:   # rotate the free slots, then try every way to keep m of them in order
		for mask in range(1 << nf):
			var picked: Array[int] = []
			for b in nf:
				if mask & (1 << b):
					picked.append(free[(r + b) % nf])
			if picked.size() != m:
				continue
			var cost := 0.0
			for i in m:
				cost += absf(_arc(riders[i].s, _slot_s(picked[i])))
			if cost < best_cost:
				best_cost = cost
				best = picked
	for i in m:
		riders[i].slot = best[i]


func _reslot() -> void:
	_assign_ordered()


## Is the road clear for a sheep to step on at `at` (nobody within a body's length)?
func _road_clear_at(at: float) -> bool:
	for o in _road:
		if o.state == Sheep.State.TRACK and not o.hold:
			var d := _arc(at, o.s)
			if d > -1.6 and d < 1.3:
				return false
	return true


func _update_road(dt: float) -> void:
	var T := _lay.track
	var L := T.length
	_ring = fposmod(_ring + TRACK_SPEED * dt, L)
	_steer_joiners(dt)
	# a sheep waiting beside the road steps on when its slot reaches it and nobody is right there
	for s in _road.duplicate():
		if s.state != Sheep.State.MERGE or not s.path.is_empty():
			continue
		if s.join_col >= 0 and s.join_col < _joiners.size() and not _joiners[s.join_col].is_empty() \
				and _joiners[s.join_col][0] != s:
			continue   # not at the front of its column's line yet
		# the first free slot that comes past (its own planned one, or any other free one) and room on the road
		var used := _taken(s)
		var take := -1
		for k in cap_now():
			var a := _arc(s.merge_s, _slot_s(k))
			if not (k in used) and a >= -0.06 and a < 0.8 and (take < 0 or k == s.slot):
				take = k
		if take >= 0 and _road_clear_at(s.merge_s):
			s.slot = take
			_joined(s)
			s.state = Sheep.State.TRACK
			s.s = s.merge_s
			s.v = TRACK_SPEED
			s.blend = 1.0
			s.blend_from = s.position
			s.stop_walking()
	# a sheep pushed out of a pen waits at the pen exit until nobody is passing there, then drops into the gap
	# (the even slots are shared out again in road order, like for a sheep coming from the queue)
	for s in _road:
		if s.exit_wait and s.path.is_empty():
			if _road_clear_at(s.s):
				s.exit_wait = false
				s.hold = false
				_assign_ordered()
				s.v = TRACK_SPEED * 0.6
				s.blend = 1.0
				s.blend_from = s.position
				s.jump(3.0)
	var changed := false
	for s in _road.duplicate():
		if s.state != Sheep.State.TRACK:
			continue
		if s.hold:
			continue
		if s.slot < 0 or s.slot >= cap_now():
			s.slot = _pick_slot(s.s, false, s)
		var prev: float = s.s
		# how far its slot is ahead of it (no slot yet: keep the road's pace)
		var err := _arc(prev, _slot_s(s.slot)) if s.slot >= 0 else TRACK_SPEED * dt
		# match the slot by speed alone, never stopping: up to 1.5x when it is ahead, down to 0.6x when it is behind
		var want := clampf(TRACK_SPEED + err * 2.5, TRACK_SPEED * 0.6, TRACK_SPEED * 1.5)
		s.v += (want - s.v) * minf(1.0, dt * 8.0)
		var step: float = s.v * dt if err < 0.0 else clampf(s.v * dt, 0.0, err)
		# never into the sheep ahead: sheep keep their order on the road (no running through each other)
		var ahead := INF
		for o in _road:
			if o != s and o.state == Sheep.State.TRACK and not o.hold:
				var g := fposmod(o.s - prev, L)
				if g > 0.0001 and g < ahead:
					ahead = g
			elif o.state == Sheep.State.JOINING and o.committed:   # a sheep about to step on here: make room for it
				var gj := fposmod(o.merge_s - prev, L)
				if gj > 0.0001 and gj < ahead:
					ahead = gj
		var room := maxf(0.0, ahead - 1.15)
		if step > room:
			step = room
			s.v = minf(s.v, room / maxf(dt, 1e-4))
		var next: float = prev + step
		if mode == Mode.PLAY and s.blend < 0.3:
			var np := _next_parker()
			if not np.is_empty() and np.sheep == s:
				var i: int = np.lane
				if _crossed(prev, next, _lay.s_in[i], L) and _can_enter(i, s.color):
					_enter_lane(s, i)
					changed = true
					continue
		s.s = fmod(next, L)
		var p := T.point_at(s.s)
		if s.blend > 0.0:
			s.blend = maxf(0.0, s.blend - dt / 0.42)
			var e: float = s.blend * s.blend * (3.0 - 2.0 * s.blend)
			p = p.lerp(s.blend_from, e)
		var dx: float = p.x - s.position.x
		var dz: float = p.z - s.position.z
		if dx * dx + dz * dz > 1e-7:
			s.target_yaw = Sheep.yaw_to(dx, dz)
		s.position = p
		s.track_moving = s.v > 0.4
	if changed:
		_refresh_hud()


func _transitional() -> bool:
	for s in _sheep:
		if s.state in [Sheep.State.JOINING, Sheep.State.MERGE, Sheep.State.ENTERING, Sheep.State.CLEARING] \
				or (s.state == Sheep.State.TRACK and s.blend > 0.0):
			return true
	for l in _pens:
		if l.pending:
			return true
	return false


func is_settled() -> bool:
	return mode == Mode.PLAY and not _transitional()


## Settled and no sheep on the road can still reach a pen (matches Puzzle.settle).
func is_quiet() -> bool:
	if not is_settled():
		return false
	for s in _road:
		if _any_enter(s.color):
			return false
	return true


func _check_end(dt: float) -> void:
	if _entries > 60:
		_lose("loop")
		return
	if _transitional():
		_stuck_t = 0.0
		return
	var q_empty: bool = _queues.all(func(q): return q.is_empty())
	if q_empty and _road.is_empty() and _pens.all(func(l): return l.sheep.is_empty()):
		_win()
		return
	var none_can: bool = _road.all(func(s): return not _any_enter(s.color))
	var stuck: bool = (none_can and (_road.size() >= cap_now() or q_empty)) if _road.size() > 0 else q_empty
	if stuck:
		_stuck_t += dt
		if _stuck_t > 1.6:
			_lose("empty" if q_empty else "full")
	else:
		_stuck_t = 0.0


# ------------------------------------------------------------ end states
func _win() -> void:
	mode = Mode.WON
	_tips.clear()
	_tip_showing = false
	hud.tutorial("")
	_set_hint(Callable())
	_cam_shake = 0.35
	_fx.confetti(Vector3(0, 0, 0))
	var cols := {}
	for str in _level.lanes + _level.queues:
		for ch in str:
			cols[ch] = true
	var keys := cols.keys()
	for k in keys.size():
		var s := _spawn(keys[k])
		s.state = Sheep.State.PARTY
		s.rest_yaw = 0.0
		var x := (k - (keys.size() - 1) / 2.0) * minf(1.0, (_lay.pen_half_w * 2 - 0.6) / maxf(1, keys.size() - 1))
		s.place(Vector3(x, 0.05, 0.4 + (k % 2) * 0.5), 0.0)
		s.drop_in(0.1 + k * 0.08, 6.0)
		for j in 6:
			_after(0.9 + k * 0.07 + j * 0.62, func(): s.jump(5.0))
	var stars := maxi(1, 3 - _boosters_used)
	S.unlocked = maxi(int(S.unlocked), mini(Levels.count() - 1, level_index + 1))
	S.runs = int(S.get("runs", 0)) + 1
	_reward = 50 + stars * 10
	Horus.an.result(true)
	Horus.an.log("level_end", {level = level_index + 1, result = "win", stars = stars})
	_after(2.4, func():
		hud.show_win(stars, _reward, level_index == Levels.count() - 1)
		_earn(_reward, "level_win"))
	persist()


func _lose(reason: String) -> void:
	if mode != Mode.PLAY:
		return
	mode = Mode.LOST
	_tips.clear()
	_tip_showing = false
	hud.tutorial("")
	_set_hint(Callable())
	for s in _road:
		s.nope()
	hud.shake_road()
	var msg := "The road is full and no sheep can find a pen." if reason == "full" \
		else ("No sheep left to send, but the pens are still mixed up." if reason == "empty" \
		else "The flock keeps going round in circles!")
	Horus.an.log("level_end", {level = level_index + 1, result = "lose", reason = reason})
	# a full road can be rescued with +1 Road ("Keep playing?"); everything else goes straight to Level Failed
	if reason == "full" and _cap_bonus < 2:
		_after(1.1, func(): hud.show_pre_lose(msg, int(S.slot) > 0, booster_price(), int(S.coins) >= booster_price()))
	else:
		Horus.an.result(false)
		lose_life()
		_after(1.1, func(): hud.show_lose(msg))


## "Keep playing?" paid with a +1 Road booster or coins.
func continue_with_slot() -> void:
	if mode != Mode.LOST:
		return
	var price := booster_price()
	if int(S.slot) > 0:
		S.slot = int(S.slot) - 1
	elif int(S.coins) >= price:
		S.coins = int(S.coins) - price
		Horus.an.spend("coin", price, "slot")
	else:
		hud.toast(tr("Not enough coins"))
		hud.show_shop(false)
		return
	persist()
	_resume_with_extra_road()


## "Keep playing?" paid with a rewarded ad.
func continue_with_ad() -> void:
	if mode != Mode.LOST or Horus.ads.busy():
		return
	var r := await Horus.ads.rewarded("extra_road")
	if not r.ok:
		if r.reason != "busy":
			hud.toast("No ad right now, try again soon")
		return
	Horus.monetize.note_rewarded(S.ads, Time.get_unix_time_from_system() * 1000.0)
	_resume_with_extra_road()


func _resume_with_extra_road() -> void:
	_cap_bonus += 1
	_reslot()
	mode = Mode.PLAY
	_stuck_t = 0.0
	hud.hide_panels()
	hud.toast("+1 road space!")
	_refresh_hud()


## Pre-lose popup closed: the level is lost for good.
func give_up() -> void:
	Horus.an.result(false)
	lose_life()


## Win screen: x2 coins for a rewarded ad.
func double_reward() -> void:
	if _x2_taken or Horus.ads.busy():
		return
	var r := await Horus.ads.rewarded("double_reward")
	if not r.ok:
		if r.reason != "busy":
			hud.toast("No ad right now, try again soon")
		return
	_x2_taken = true
	Horus.monetize.note_rewarded(S.ads, Time.get_unix_time_from_system() * 1000.0)
	_earn(_reward, "x2_ad")
	hud.toast(tr("+%d coins!") % _reward)
	await next_level()


## Win screen "Continue": an interstitial when the pacing rules allow, then the next level.
func next_level() -> void:
	if hud.is_open(hud._rate) or hud.is_open(hud._ads_break):
		return   # already on the way (double taps)
	if level_index == 2 and not S.get("rated", false):
		hud.show_rate()
		await hud.rate_done
	if level_index + 1 >= Levels.count():
		hud.toast(tr("You finished every level! More coming soon."), 2.5)
		hud.transition(go_home)
		return
	if not S.get("no_ads", false):
		var rules := {"interEvery": maxi(1, int(Horus.rc.number("inter_every", 2.0))), "interFromRun": 2}
		var now := Time.get_unix_time_from_system() * 1000.0
		var due: Dictionary = Horus.monetize.inter_due(S.ads, rules, {
			now = now, runs = int(S.runs), noAds = S.get("no_ads", false), x2Skipped = not _x2_taken,
			sinceStart = Time.get_ticks_msec() / 1000.0 - _session_start,
		})
		if due.due and Horus.ads.ready().get("inter", false) and not Horus.ads.busy():
			Horus.monetize.note_inter(S.ads, int(S.runs), now)
			persist()
			hud.show_ads_break()
			await get_tree().create_timer(1.0).timeout
			await Horus.ads.inter("level_end")
			hud.hide_ads_break()
	var nxt := level_index + 1
	hud.transition(func(): load_level(nxt))


# ------------------------------------------------------------ coins + boosters
func _earn(n: int, source: String) -> void:
	S.coins = int(S.coins) + n
	Horus.an.earn("coin", n, source)
	persist()
	_refresh_hud()


## Use one booster: from the stock, else for coins. Returns false (and offers more) when neither.
func _spend_booster(kind: String) -> bool:
	if int(S[kind]) > 0:
		S[kind] = int(S[kind]) - 1
	else:
		hud.show_booster_offer(kind, booster_price(), int(S.coins) >= booster_price())
		return false
	_boosters_used += 1
	Horus.an.log("booster_use", {type = kind, level = level_index + 1})
	persist()
	_refresh_hud()
	return true


## Booster offer popup: get one for coins.
func buy_booster_coins(kind: String) -> void:
	if int(S.coins) < booster_price():
		hud.toast(tr("Not enough coins"))
		hud.show_shop(false)
		return
	S.coins = int(S.coins) - booster_price()
	S[kind] = int(S[kind]) + 1
	Horus.an.spend("coin", booster_price(), kind)
	persist()
	hud.close_booster_offer()
	hud.toast(tr("+1 booster!"))
	_refresh_hud()


## Booster offer popup: get one for a rewarded ad.
func buy_booster_ad(kind: String) -> void:
	if Horus.ads.busy():
		return
	var r := await Horus.ads.rewarded("free_booster")
	if not r.ok:
		if r.reason != "busy":
			hud.toast("No ad right now, try again soon")
		return
	Horus.monetize.note_rewarded(S.ads, Time.get_unix_time_from_system() * 1000.0)
	S[kind] = int(S[kind]) + 1
	persist()
	hud.close_booster_offer()
	hud.toast(tr("+1 booster!"))
	_refresh_hud()


func snapshot() -> Dictionary:
	return Puzzle.make_state(
		_pens.map(func(l): return [] if l.pending else l.sheep.map(func(s): return s.color)),
		_queues.map(func(q): return q.map(func(s): return s.color)),
		_road.map(func(s): return s.color),
		cap_now())


func use_booster(kind: String) -> void:
	if not Meta.unlocked(kind, level_index):
		hud.toast(tr("Unlocks at Level %d") % (int(Meta.UNLOCK[kind]) + 1))
		return
	match kind:
		"undo": use_undo()
		"slot": use_slot()
		"hint": use_hint()


func use_undo() -> void:
	if mode != Mode.PLAY:
		return
	if _history.is_empty():
		hud.toast("Nothing to undo")
		return
	if not _spend_booster("undo"):
		return
	var st: Dictionary = _history.pop_back()
	_timers.clear()
	for s in _sheep.duplicate():
		_remove_sheep(s)
	_pens = []
	for _l in _level.lanes:
		_pens.append({sheep = [], pending = false, clearing = false})
	_queues = []
	for _q in _level.queues:
		_queues.append([])
	_road.clear()
	_build_from(st, false)
	for s in _sheep:
		s.squash(0.35)
	_entries = 0
	_stuck_t = 0.0
	_set_hint(Callable())
	_refresh_hud()


func use_slot() -> void:
	if mode != Mode.PLAY:
		return
	if _cap_bonus >= 2:
		hud.toast("The road is as long as it gets!")
		return
	if not _spend_booster("slot"):
		return
	_cap_bonus += 1
	_reslot()
	hud.toast("+1 road space!")
	_refresh_hud()


func use_hint() -> void:
	if mode != Mode.PLAY:
		return
	if _transitional():
		hud.toast("Wait for the flock to settle...")
		return
	var mv := Puzzle.best_move(snapshot())
	if mv.col < 0 or not mv.win:
		hud.toast("No winning move - try Undo!", 1.9)
		return
	if not _spend_booster("hint"):
		return
	var c: int = mv.col
	_set_hint(func(): return _front_pos(c))
	if not _queues[c].is_empty():
		_queues[c][0].jump(3.0)


func _front_pos(c: int) -> Vector3:
	return _queues[c][0].position if not _queues[c].is_empty() else _lay.join_wait(c)


func _set_hint(target: Callable) -> void:
	_hint_target = target
	_update_hand()


func _update_hand() -> void:
	if not _hint_target.is_valid() or _cam == null:
		hud.point_at(null)
		return
	var p: Vector3 = _hint_target.call() + Vector3(0, 0.9, 0)
	if _cam.is_position_behind(p):
		hud.point_at(null)
		return
	hud.point_at(_cam.unproject_position(p))


func _refresh_hud() -> void:
	if _level.is_empty():
		return
	hud.set_road(_road.map(func(s): return s.color), cap_now())
	hud.set_boosters(int(S.undo), int(S.slot), int(S.hint), level_index)
	hud.set_coins(int(S.coins))


# ------------------------------------------------------------ tutorial
func _queue_tip(text: String, hold := 2.6) -> void:
	_tips.append({text = text, hold = hold})


func _update_tips() -> void:
	if _tip_showing and _t < _tip_until:
		return
	if not _tips.is_empty():
		var tp: Dictionary = _tips.pop_front()
		_tip_showing = true
		_tip_until = _t + tp.hold
		hud.tutorial(tp.text)
	elif _tip_showing:
		_tip_showing = false
		hud.tutorial("")


func _on_play_start() -> void:
	if _level.get("tutorial", false):
		_coach_send()
	elif level_index == 1:
		_queue_tip("If the road fills with sheep that can't find a pen, you lose!", 4)
	elif level_index == 2:
		_queue_tip("Stuck? Try Undo, +1 Road or a Hint!", 4)


# Level 1 coach, step by step like the reference tutorial:
#   1 dim screen, window on one queue sheep + hand: "Send a sheep..." (only that sheep can be tapped)
#   2 the sheep goes round the road            3 it walks into its pen: the game waits on "Sheep go into the pen..."
#   then the full pen's bottom sheep pops out: the game waits on "Pushed-out sheep join the road"
#   4 free play
const TUT_COL := 1


func _coach_send() -> void:
	_tut_step = 1
	_set_hint(func(): return _front_pos(TUT_COL))
	var q := _lay.queue_pos(TUT_COL, 0)
	hud.coach(tr("Send a sheep and start sorting colours"),
		_screen_box([q + Vector3(-0.75, 0, -1.0), q + Vector3(0.75, 0, -1.0), q + Vector3(-0.75, 1.3, 0.7), q + Vector3(0.75, 1.3, 0.7)]),
		_coach_y())


## Taps the coach allows right now (level 1 before free play: only the shown sheep, once).
func _tut_allows(c: int) -> bool:
	if not _level.get("tutorial", false) or _tut_step == 0 or _tut_step >= 4:
		return true
	return _tut_step == 1 and c == TUT_COL


func _tutorial_event(ev: String, lane := -1, who: Sheep = null) -> void:
	if not _level.get("tutorial", false):
		return
	if ev == "send" and _tut_step == 1:
		_tut_step = 2
		hud.coach_hide()
		_set_hint(Callable())
	elif ev == "push" and _tut_step == 2 and who != null:
		# like the reference's yellow car: the pushed-out sheep waits at the pen exit while the cards explain it
		_tut_pushed = true
		_tut_held = who
		_wait_at_exit(who, lane)
		who.exit_wait = false   # held by the coach card, not by traffic (_release_held lets it go)
	elif ev == "enter" and _tut_step == 2:
		_tut_step = 3
		_after(0.5, func():
			hud.coach(tr("Sheep go into the pen with their colour"), _lane_box(lane, false), _coach_y(), func():
				if not _tut_pushed:
					_tut_step = 4
					return
				hud.coach(tr("Pushed-out sheep join the road"), _lane_box(lane, true), _coach_y(), func():
					_tut_step = 4
					_release_held())))


## Let the sheep held at the pen exit step onto the road.
func _release_held() -> void:
	var h := _tut_held
	_tut_held = null
	if h == null or not is_instance_valid(h) or not h.hold:
		return
	h.bleat()
	h.exit_wait = true   # the road update lets it out as soon as the road at the exit is clear


## A pushed-out sheep stands at the exit of pen i (off the road, no slot) until the road there is clear.
func _wait_at_exit(x: Sheep, i: int) -> void:
	x.hold = true
	x.exit_wait = true
	x.slot = -1
	x.walk([Vector3(_lay.lane_x[i], RoadLayout.PEN_Y, _lay.pen_half_h - 0.05)], 2.6)




## Screen window round pen lane i (with_road: down over the road below it, where pushed sheep come out).
func _lane_box(i: int, with_road: bool) -> Rect2:
	var x0 := _lay.lane_x[i] - _lay.lane_w / 2.0
	var x1 := _lay.lane_x[i] + _lay.lane_w / 2.0
	var z0 := -_lay.pen_half_h
	var z1 := _lay.road_outer_z if with_road else _lay.pen_half_h
	return _screen_box([Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x0, 1.1, z1), Vector3(x1, 1.1, z1), Vector3(x0, 0, z1), Vector3(x1, 0, z1)])


func _screen_box(pts: Array) -> Rect2:
	var r := Rect2(_cam.unproject_position(pts[0]), Vector2.ZERO)
	for p in pts:
		r = r.expand(_cam.unproject_position(p))
	return r.grow(14.0)


## Coach card height: the stretch of road between the loop and the queue.
func _coach_y() -> float:
	var a := _cam.unproject_position(Vector3(0, 0, _lay.road_outer_z)).y
	var b := _cam.unproject_position(Vector3(0, 1.08, _lay.queue_z0 - 0.68)).y
	return (a + b) / 2.0



# ------------------------------------------------------------ test helpers
func queue_count(c: int) -> int:
	return _queues[c].size()


func column_count() -> int:
	return _queues.size()


func force_win() -> void:
	_timers.clear()   # e.g. the intro timer that would switch back to PLAY
	_win()


func force_lose(reason: String) -> void:
	_lose(reason)
