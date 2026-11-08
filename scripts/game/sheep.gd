class_name Sheep
extends Node3D
## One sheep: placeholder body made of primitives + all motion (walk, hop, jump, squash, nope).
## Port of the prototype's Sheep class. Ticked manually by WoollyGame.

enum State { IDLE, QUEUE, JOINING, MERGE, TRACK, ENTERING, LANE, CLEARING, PARTY }

static var _count := 0

var color := "P"
var state := State.IDLE

# path walking
var path: Array[Vector3] = []
var speed := 4.6
var _on_arrive := Callable()

# road (arc-length) motion, driven by WoollyGame
var s := 0.0
var v := 0.0
var blend := 0.0
var merge_s := 0.0
var slot := -1             # road slot (game.gd ring) this sheep rides in, -1 = none
var hold := false          # level 1 coach: a pushed-out sheep waits at the pen exit until the card is read
var arrive_left := 0.0     # distance a walk had left over in its last frame (so the next move can use it)
var exit_wait := false     # pushed out of a pen: waits at the pen exit (hold) until the road there is clear
var join_col := -1         # queue column it was sent from, while it is on its way to the road
var committed := false     # on its way and past the point of no return: sheep on the road make room for it
var blend_from := Vector3.ZERO
var track_moving := false
var moving := false

# facing (radians)
var yaw := 0.0
var target_yaw := 0.0
var rest_yaw = null        # float or null: yaw to turn to when standing still
var side := 1              # +1 / -1: which way it faces in a pen
var jit := 0.0

var _hop := 0.0
var _hop_h := 0.0
var _y := 0.0
var _vy := 0.0
var _sq := 0.0
var _sqv := 0.0
var _wig := 0.0
var _seed := 0.0
var _bleat_t := 0.0
var _drop_delay := 0.0
var _pivot: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []


static func create(c: String) -> Sheep:
	var sh := Sheep.new()
	sh._build(c)
	return sh


func _build(c: String) -> void:
	color = c
	_count += 1
	side = 1 if _count % 2 == 1 else -1
	jit = randf_range(-0.15, 0.15)
	_seed = randf() * 100.0
	_hop = randf() * 6.0
	var meshes := _meshes(c)
	_pivot = Node3D.new()
	add_child(_pivot)
	_mesh(_pivot, meshes.body, Vector3.ZERO, true)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.76, 0.48)
	_pivot.add_child(_head)
	_mesh(_head, meshes.head, Vector3.ZERO, true)
	for p in [Vector3(-0.2, 0.28, 0.24), Vector3(0.2, 0.28, 0.24), Vector3(-0.2, 0.28, -0.28), Vector3(0.2, 0.28, -0.28)]:
		var hip := Node3D.new()
		hip.position = p
		_pivot.add_child(hip)
		_mesh(hip, meshes.leg, Vector3.ZERO, false)
		_legs.append(hip)


static var _cache := {}


func _mesh(parent: Node3D, m: Mesh, pos: Vector3, shadows: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Merged body / head / leg meshes per wool colour (built once, shared by every sheep of that colour).
static func _meshes(c: String) -> Dictionary:
	if _cache.has(c):
		return _cache[c]
	var wool := Art.wool(c)
	var face := Art.FACE
	# body (+z is forward): a soft core wrapped in puffs, a fluffy top and a tail puff
	var b := MeshKit.new()
	b.part("sphere", Vector3(0, 0.56, -0.03), Vector3(0.8, 0.62, 0.92), wool, Vector3.ZERO, 0.3)
	for i in 8:
		var a := i / 8.0 * TAU
		b.part("sphere", Vector3(cos(a) * 0.3, 0.55 + sin(a * 2.0) * 0.03, sin(a) * 0.36 - 0.03), Vector3.ONE * 0.4, wool, Vector3.ZERO, 0.35)
	for p in [Vector3(-0.15, 0.82, 0.12), Vector3(0.15, 0.82, 0.12), Vector3(-0.14, 0.84, -0.18), Vector3(0.14, 0.84, -0.18), Vector3(0, 0.88, -0.03)]:
		b.part("sphere", p, Vector3.ONE * 0.34, wool.lightened(0.06), Vector3.ZERO, 0.2)
	b.part("sphere", Vector3(0, 0.66, -0.5), Vector3.ONE * 0.2, wool.lightened(0.04), Vector3.ZERO, 0.2)
	# head (origin = neck pivot): dark face, lighter snout, big eyes with highlights, ears, blush, wool tuft
	var h := MeshKit.new()
	h.part("sphere", Vector3(0, 0, 0.1), Vector3(0.44, 0.46, 0.42), face, Vector3.ZERO, 0.25)
	h.part("sphere", Vector3(0, -0.1, 0.27), Vector3(0.27, 0.19, 0.15), face.lightened(0.14), Vector3.ZERO, 0.0)
	for sgn in [-1.0, 1.0]:
		h.part("sphere", Vector3(sgn * 0.1, 0.04, 0.27), Vector3(0.14, 0.15, 0.08), Color.WHITE, Vector3.ZERO, 0.0)
		h.part("sphere", Vector3(sgn * 0.095, 0.03, 0.31), Vector3(0.075, 0.09, 0.04), Color("#1d1a22"), Vector3.ZERO, 0.0)
		h.part("sphere", Vector3(sgn * 0.08, 0.06, 0.33), Vector3.ONE * 0.03, Color.WHITE, Vector3.ZERO, 0.0)
		h.part("sphere", Vector3(sgn * 0.16, -0.07, 0.27), Vector3(0.08, 0.04, 0.03), Color("#ff9cc8"), Vector3.ZERO, 0.0)
		h.part("sphere", Vector3(sgn * 0.26, 0.06, 0.06), Vector3(0.24, 0.08, 0.14), face, Vector3(0, 0, -sgn * 0.45), 0.0)
		h.part("sphere", Vector3(sgn * 0.27, 0.065, 0.075), Vector3(0.15, 0.05, 0.08), Color("#f3a0b8"), Vector3(0, 0, -sgn * 0.45), 0.0)
	h.part("sphere", Vector3(0, 0.21, 0.05), Vector3(0.32, 0.2, 0.3), wool, Vector3.ZERO, 0.15)
	for sgn in [-1.0, 1.0]:
		h.part("sphere", Vector3(sgn * 0.12, 0.19, 0.0), Vector3.ONE * 0.18, wool.lightened(0.05), Vector3.ZERO, 0.1)
	# leg (origin = hip): dark leg with a hoof
	var l := MeshKit.new()
	l.part("cylinder", Vector3(0, -0.12, 0), Vector3(0.12, 0.26, 0.12), face, Vector3.ZERO, 0.0)
	l.part("cylinder", Vector3(0, -0.25, 0.01), Vector3(0.14, 0.05, 0.15), face.darkened(0.35), Vector3.ZERO, 0.0)
	_cache[c] = {body = b.commit(), head = h.commit(), leg = l.commit()}
	return _cache[c]


func place(p: Vector3, y: float) -> void:
	position = p
	yaw = y
	target_yaw = y
	rotation.y = y


func walk(points: Array, spd: float, on_arrive := Callable()) -> void:
	path.clear()
	for p in points:
		path.append(p)
	speed = spd
	_on_arrive = on_arrive


## Change the final destination without losing the arrival callback.
func retarget(p: Vector3) -> void:
	if path.size() > 0:
		path[path.size() - 1] = p
	else:
		path.append(p)


func stop_walking() -> void:
	path.clear()
	_on_arrive = Callable()


func jump(vel := 4.5) -> void:
	if _y <= 0.001:
		_vy = vel


func squash(a := 0.25) -> void:
	_sqv -= a * 14.0


func nope() -> void:
	_wig = 1.0


func bleat() -> void:
	_bleat_t = 0.55


func drop_in(delay: float, height := 7.0) -> void:
	_drop_delay = delay
	_y = height
	_vy = 0.0
	visible = false
	_pivot.position.y = _y


static func yaw_to(dx: float, dz: float) -> float:
	return atan2(dx, dz)


func tick(dt: float, t: float) -> void:
	if _drop_delay > 0.0:
		_drop_delay -= dt
		if _drop_delay > 0.0:
			return
		visible = true

	var mv := track_moving
	if path.size() > 0:
		var p := position
		var tgt: Vector3 = path[0]
		var dx := tgt.x - p.x
		var dz := tgt.z - p.z
		var d := sqrt(dx * dx + dz * dz)
		var step := speed * dt
		p.y += (tgt.y - p.y) * minf(1.0, dt * 10.0)
		if d <= step:
			arrive_left = step - d
			p.x = tgt.x
			p.z = tgt.z
			position = p
			path.remove_at(0)
			if path.is_empty():
				var cb := _on_arrive
				_on_arrive = Callable()
				if cb.is_valid():
					cb.call(self)
		else:
			p.x += dx / d * step
			p.z += dz / d * step
			position = p
			if d > 0.05:
				target_yaw = yaw_to(dx, dz)
		mv = true
	moving = mv
	if path.is_empty() and not track_moving and rest_yaw != null:
		target_yaw = rest_yaw
	yaw = lerp_angle(yaw, target_yaw, minf(1.0, dt * 11.0))
	rotation.y = yaw

	# hop gait
	if mv:
		_hop += dt * 14.0
		_hop_h = absf(sin(_hop)) * 0.15
	else:
		_hop_h *= maxf(0.0, 1.0 - dt * 12.0)

	# ballistic jump
	if _y > 0.0 or _vy != 0.0:
		_vy -= 24.0 * dt
		_y += _vy * dt
		if _y <= 0.0:
			if _vy < -3.0:
				squash(minf(0.45, -_vy * 0.045))
			_y = 0.0
			_vy = 0.0

	# squash spring
	_sqv += (-_sq * 190.0 - _sqv * 11.0) * dt
	_sq += _sqv * dt
	var breathe := 0.0 if mv else sin(t * 2.2 + _seed) * 0.022
	var stretch := (_hop_h - 0.07) * 0.5 if mv else 0.0
	var sy := 1.0 - _sq + breathe + stretch
	var sxz := 1.0 + _sq * 0.55 - stretch * 0.4
	_pivot.scale = Vector3(sxz, maxf(0.2, sy), sxz)
	_pivot.position.y = _y + _hop_h

	# legs
	var sw := sin(_hop * 2.0) * 0.75 if mv else 0.0
	var k := minf(1.0, dt * 14.0)
	for i in 4:
		var target := sw if (i == 0 or i == 3) else -sw
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, target, k)

	# head: bob while walking, nod when bleating
	var hx := sin(_hop * 2.0) * 0.08 if mv else sin(t * 1.3 + _seed) * 0.04
	if _bleat_t > 0.0:
		_bleat_t -= dt
		hx = -0.55 * sin(minf(1.0, _bleat_t / 0.55) * PI)
	_head.rotation.x = hx - 0.12   # chin up a little so the face reads from the high camera

	# "nope" wiggle
	if _wig > 0.0:
		_wig = maxf(0.0, _wig - dt * 2.2)
		_pivot.rotation.z = sin(t * 45.0) * 0.22 * _wig
	else:
		_pivot.rotation.z = 0.0
