class_name FarmWorld
extends RefCounted
## Builds the farm board and scenery around a RoadLayout. Every static part is merged with MeshKit, so the whole
## world is ~6 draw calls: lawn (shader), road, pen, fences, scenery, small decor.

const DIRT := Color("#e2bd86")
const DIRT_DARK := Color("#c99a5f")
const DIRT_EDGE := Color("#a87a46")
const KERB := Color("#f6eedd")   # low stone kerb along both road edges (the reference's white curbs); goes red when the road is full
const PEN_FLOOR := Color("#a3d971")
const LANE_A := Color("#93cf62")
const LANE_B := Color("#9ad467")
const WOOD := Color("#c98f57")
const WOOD_DARK := Color("#9c6a3c")
const BARN_RED := Color("#d9473b")
const ROOF := Color("#7a3a2c")
const TRIM := Color("#fbf3e6")
const LEAF := [Color("#5fbf48"), Color("#4fae3f"), Color("#6ccb52")]
const TRUNK := Color("#8a5a36")

static var _grass_mat: ShaderMaterial


static func build(parent: Node3D, L: RoadLayout, level: Dictionary, level_index: int) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var stem_end := _stem_end(L, level)
	_lawn(root)
	_road(root, L, stem_end)
	root.set_meta("kerb", _kerbs(root, L))
	_pen(root, L)
	_scenery(root, L, stem_end, level_index)
	return root


static func _stem_end(L: RoadLayout, level: Dictionary) -> float:
	var max_q := 0
	for q in level.queues:
		max_q = maxi(max_q, String(q).length())
	return L.queue_z0 + (max_q - 1) * L.slot + 0.8


# ------------------------------------------------------------ lawn
static func _lawn(root: Node3D) -> void:
	if _grass_mat == null:
		_grass_mat = ShaderMaterial.new()
		_grass_mat.shader = load("res://assets/shaders/grass.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = _grass_mat
	mi.position = Vector3(0, 0, 2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


# ------------------------------------------------------------ road: one smooth ribbon + stem
static func _road(root: Node3D, L: RoadLayout, stem_end: float) -> void:
	var k := MeshKit.new()
	var T := L.track
	var y := RoadLayout.ROAD_Y
	var half := L.road / 2.0
	var n := ceili(T.length / 0.12)
	for i in n:
		var s0 := i * T.length / n
		var s1 := (i + 1) * T.length / n
		var p0 := T.point_at(s0)
		var p1 := T.point_at(s1)
		var t0 := (T.point_at(s0 + 0.05) - p0).normalized()
		var t1 := (T.point_at(s1 + 0.05) - p1).normalized()
		var n0 := Vector3(t0.z, 0, -t0.x)
		var n1 := Vector3(t1.z, 0, -t1.x)
		# subtle colour drift along the road so it is not a flat colour
		var tint := DIRT.lerp(DIRT_DARK, 0.18 + 0.12 * sin(s0 * 1.7) * sin(s0 * 0.63))
		var a_in := p0 - n0 * half
		var a_out := p0 + n0 * half
		var b_in := p1 - n1 * half
		var b_out := p1 + n1 * half
		k.quad(Vector3(a_out.x, y, a_out.z), Vector3(b_out.x, y, b_out.z), Vector3(b_in.x, y, b_in.z), Vector3(a_in.x, y, a_in.z), tint)
		# darker wheel ruts
		for off in [-half * 0.48, half * 0.48]:
			var r0: Vector3 = p0 + n0 * off
			var r1: Vector3 = p1 + n1 * off
			var w := 0.09
			k.quad(Vector3(r0.x + n0.x * w, y + 0.002, r0.z + n0.z * w), Vector3(r1.x + n1.x * w, y + 0.002, r1.z + n1.z * w),
				Vector3(r1.x - n1.x * w, y + 0.002, r1.z - n1.z * w), Vector3(r0.x - n0.x * w, y + 0.002, r0.z - n0.z * w), tint.darkened(0.07))
		# sides down to the lawn + a soft darker rim band on the grass
		for side in [-1.0, 1.0]:
			var e0: Vector3 = p0 + n0 * half * side
			var e1: Vector3 = p1 + n1 * half * side
			var top0: Vector3 = Vector3(e0.x, y, e0.z)
			var top1: Vector3 = Vector3(e1.x, y, e1.z)
			var bot0: Vector3 = Vector3(e0.x, 0.0, e0.z) + n0 * side * 0.06
			var bot1: Vector3 = Vector3(e1.x, 0.0, e1.z) + n1 * side * 0.06
			k.quad(top0, top1, bot1, bot0, DIRT_EDGE, DIRT_EDGE.darkened(0.15), n0 * side)
	# stem down to the queues
	var x0 := -L.stem_half
	var x1 := L.stem_half
	var z0 := L.stem_top()
	var z1 := stem_end
	var ys := y - 0.004
	k.quad(Vector3(x0, ys, z1), Vector3(x1, ys, z1), Vector3(x1, ys, z0), Vector3(x0, ys, z0), DIRT.lerp(DIRT_DARK, 0.2))
	for x in [x0, x1]:
		var dx := 0.06 * signf(x)
		k.quad(Vector3(x, ys, z0), Vector3(x, ys, z1), Vector3(x + dx, 0.0, z1), Vector3(x + dx, 0.0, z0), DIRT_EDGE, DIRT_EDGE.darkened(0.15), Vector3(signf(x), 0, 0))
	k.quad(Vector3(x1, ys, z1), Vector3(x0, ys, z1), Vector3(x0, 0.0, z1 + 0.06), Vector3(x1, 0.0, z1 + 0.06), DIRT_EDGE, DIRT_EDGE.darkened(0.15), Vector3.BACK)
	if z0 > L.hz + 0.01:   # the strip starts on the lawn, below the loop: give it a top edge too
		k.quad(Vector3(x0, ys, z0), Vector3(x1, ys, z0), Vector3(x1, 0.0, z0 - 0.06), Vector3(x0, 0.0, z0 - 0.06), DIRT_EDGE, DIRT_EDGE.darkened(0.15), Vector3.FORWARD)
	k.instance(root, false)


# ------------------------------------------------------------ pen: floor, lanes, arrows, fences
static func _pen(root: Node3D, L: RoadLayout) -> void:
	var k := MeshKit.new()
	var py := RoadLayout.PEN_Y
	k.part("box", Vector3(0, py - 0.04, 0), Vector3(L.pen_half_w * 2, 0.08, L.pen_half_h * 2), PEN_FLOOR, Vector3.ZERO, 0.0)
	for i in L.n_lanes:
		var c: Color = LANE_A if i % 2 == 0 else LANE_B
		k.part("box", Vector3(L.lane_x[i], py + 0.004, 0), Vector3(L.lane_w - 0.24, 0.01, L.pen_half_h * 2 - 0.3), c, Vector3.ZERO, 0.0)
		# two chevrons pointing into the pen (sheep enter at the far end and walk towards the player)
		for j in 2:
			var z := -L.pen_half_h + 0.45 + j * 0.32
			for sgn in [-1.0, 1.0]:
				k.part("box", Vector3(L.lane_x[i] + sgn * 0.12, py + 0.012, z), Vector3(0.3, 0.012, 0.07),
					Color(1, 1, 1, 1).lerp(c, 0.25 + j * 0.25), Vector3(0, sgn * deg_to_rad(38), 0), 0.0)
	k.instance(root, false)

	var f := MeshKit.new()
	var zs := L.pen_half_h - 0.35
	for i in L.n_lanes + 1:
		var x: float = -L.pen_half_w if i == 0 else (L.pen_half_w if i == L.n_lanes else (L.lane_x[i - 1] + L.lane_x[i]) / 2.0)
		var posts := 5
		for p in posts:
			var z := lerpf(-zs, zs, p / float(posts - 1))
			f.part("box", Vector3(x, 0.24, z), Vector3(0.13, 0.48, 0.13), WOOD_DARK)
			f.part("box", Vector3(x, 0.5, z), Vector3(0.16, 0.05, 0.16), WOOD)
		for h in [0.2, 0.38]:
			f.part("box", Vector3(x, h, 0), Vector3(0.06, 0.07, zs * 2), WOOD, Vector3.ZERO, 0.15)
	f.instance(root)


# ------------------------------------------------------------ scenery
static func _scenery(root: Node3D, L: RoadLayout, stem_end: float, level_index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + level_index
	var big := MeshKit.new()
	var small := MeshKit.new()
	var bx := -L.hx - 1.4
	var bz := -L.hz - 3.3
	_barn(big, Vector3(bx, 0, bz))
	_silo(big, Vector3(bx - 2.5, 0, bz + 0.6))
	var spots := [
		Vector3(L.hx + 1.5, 0, -L.hz - 2.2), Vector3(L.hx + 3.0, 0, -L.hz - 0.4), Vector3(L.hx + 1.9, 0, L.hz - 0.5),
		Vector3(-L.hx - 2.0, 0, 0.6), Vector3(-L.hx - 2.6, 0, L.hz + 1.6), Vector3(L.hx + 2.6, 0, L.hz + 2.4),
		Vector3(1.4, 0, -L.hz - 4.6), Vector3(-L.stem_half - 3.4, 0, stem_end + 0.6), Vector3(L.stem_half + 3.6, 0, stem_end + 1.2),
	]
	for p in spots:
		_tree(big, p, 0.85 + rng.randf() * 0.4, rng)
	for b in 8:
		var p := _free_spot(L, stem_end, rng, 1.6)
		_bush(big, p, 0.5 + rng.randf() * 0.35, rng)
	for h in [Vector3(-L.stem_half - 1.6, 0, stem_end - 0.8), Vector3(L.stem_half + 1.5, 0, stem_end - 1.4), Vector3(bx + 1.9, 0, bz + 1.9)]:
		_hay(big, h, rng)
	for r in 5:
		var p := _free_spot(L, stem_end, rng, 1.0)
		big.part("sphere", p + Vector3(0, 0.08, 0), Vector3(0.45, 0.28, 0.38) * (0.7 + rng.randf() * 0.6), Color("#b6b2a8"), Vector3(0, rng.randf() * TAU, 0), 0.35)
	for i in 70:
		var p := _free_spot(L, stem_end, rng, 0.5)
		var col: Color = [Color("#ffffff"), Color("#ffd6e8"), Color("#fff3a6"), Color("#ff9cc8")][rng.randi() % 4]
		small.part("cylinder", p + Vector3(0, 0.07, 0), Vector3(0.025, 0.14, 0.025), Color("#3f8a2f"), Vector3.ZERO, 0.0)
		small.part("sphere", p + Vector3(0, 0.16, 0), Vector3(0.13, 0.07, 0.13), col, Vector3.ZERO, 0.0)
		small.part("sphere", p + Vector3(0, 0.18, 0), Vector3(0.05, 0.04, 0.05), Color("#ffcf3a"), Vector3.ZERO, 0.0)
	for i in 120:
		var p := _free_spot(L, stem_end, rng, 0.3)
		var g: Color = LEAF[rng.randi() % 3].lightened(0.05)
		for b in 3:
			small.part("cone", p + Vector3((b - 1) * 0.05, 0.08, 0), Vector3(0.05, 0.18 + rng.randf() * 0.08, 0.05), g,
				Vector3(0, 0, (b - 1) * 0.35), 0.4)
	big.instance(root)
	small.instance(root, false)


## A random lawn spot away from the road, pen and queue stem.
static func _free_spot(L: RoadLayout, stem_end: float, rng: RandomNumberGenerator, margin: float) -> Vector3:
	for attempt in 40:
		var x := rng.randf_range(-L.hx - 6.0, L.hx + 6.0)
		var z := rng.randf_range(-L.hz - 6.0, stem_end + 4.0)
		var in_ring := absf(x) < L.hx + L.road / 2.0 + margin and absf(z) < L.hz + L.road / 2.0 + margin
		var in_stem := absf(x) < L.stem_half + margin and z > L.hz - 1.0 and z < stem_end + margin
		if not in_ring and not in_stem:
			return Vector3(x, 0, z)
	return Vector3(L.hx + 5.0, 0, 0)


static func _barn(k: MeshKit, o: Vector3) -> void:
	var w := 3.0
	var d := 2.6
	var h := 1.9
	k.part("box", o + Vector3(0, h / 2, 0), Vector3(w, h, d), BARN_RED, Vector3.ZERO, 0.3)
	# gable ends + roof planes
	var rise := 1.0
	for z in [-d / 2, d / 2]:
		var left := o + Vector3(-w / 2, h, z)
		var right := o + Vector3(w / 2, h, z)
		var top := o + Vector3(0, h + rise, z)
		k.quad(left, right, top, top, BARN_RED, BARN_RED.lightened(0.05), Vector3(0, 0, signf(z)))
	var slope := atan2(rise, w / 2)
	var plane := sqrt(rise * rise + w * w / 4) + 0.2
	for sgn in [-1.0, 1.0]:
		k.part("box", o + Vector3(sgn * w / 4, h + rise / 2, 0), Vector3(plane, 0.14, d + 0.4), ROOF, Vector3(0, 0, -sgn * slope), 0.1)
	k.part("box", o + Vector3(0, h + rise + 0.02, 0), Vector3(0.22, 0.12, d + 0.44), ROOF.darkened(0.2), Vector3.ZERO, 0.0)
	# white trim and door with the X
	var fz := o.z + d / 2 + 0.02
	k.part("box", Vector3(o.x, o.y + 0.7, fz), Vector3(1.2, 1.4, 0.04), Color("#a8352d"), Vector3.ZERO, 0.0)
	k.part("box", Vector3(o.x, o.y + 1.42, fz + 0.01), Vector3(1.32, 0.1, 0.04), TRIM, Vector3.ZERO, 0.0)
	for sgn in [-1.0, 1.0]:
		k.part("box", Vector3(o.x + sgn * 0.62, o.y + 0.7, fz + 0.01), Vector3(0.1, 1.42, 0.04), TRIM, Vector3.ZERO, 0.0)
		k.part("box", Vector3(o.x, o.y + 0.7, fz + 0.02), Vector3(1.5, 0.09, 0.03), TRIM, Vector3(0, 0, sgn * 0.86), 0.0)
	k.part("box", Vector3(o.x, o.y + h + 0.35, fz), Vector3(0.6, 0.45, 0.04), Color("#4b2a22"), Vector3.ZERO, 0.0)
	for sgn in [-1.0, 1.0]:
		k.part("box", Vector3(o.x + sgn * (w / 2 - 0.05), o.y + h / 2, fz), Vector3(0.1, h, 0.05), TRIM, Vector3.ZERO, 0.0)


static func _silo(k: MeshKit, o: Vector3) -> void:
	k.part("cylinder", o + Vector3(0, 1.4, 0), Vector3(1.3, 2.8, 1.3), Color("#e9e1d2"), Vector3.ZERO, 0.3)
	for i in 4:
		k.part("cylinder", o + Vector3(0, 0.55 + i * 0.6, 0), Vector3(1.34, 0.05, 1.34), Color("#b8ad9a"), Vector3.ZERO, 0.0)
	k.part("sphere", o + Vector3(0, 2.8, 0), Vector3(1.32, 1.0, 1.32), Color("#c8473b"), Vector3.ZERO, 0.2)


static func _tree(k: MeshKit, o: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	k.part("cylinder", o + Vector3(0, 0.5 * s, 0), Vector3(0.28, 1.0, 0.28) * s, TRUNK, Vector3.ZERO, 0.3)
	var g: Color = LEAF[rng.randi() % 3]
	k.part("sphere", o + Vector3(0, 1.25 * s, 0), Vector3(1.6, 1.25, 1.6) * s, g.darkened(0.08), Vector3.ZERO, 0.35)
	for i in 4:
		var a := i / 4.0 * TAU + rng.randf()
		k.part("sphere", o + Vector3(cos(a) * 0.45, 1.55 + rng.randf() * 0.2, sin(a) * 0.45) * s, Vector3.ONE * (0.95 + rng.randf() * 0.2) * s, g, Vector3.ZERO, 0.3)
	k.part("sphere", o + Vector3(0, 2.05 * s, 0), Vector3(0.95, 0.8, 0.95) * s, g.lightened(0.08), Vector3.ZERO, 0.25)


static func _bush(k: MeshKit, o: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var g: Color = LEAF[rng.randi() % 3]
	for i in 3:
		k.part("sphere", o + Vector3((i - 1) * 0.35 * s, 0.32 * s, rng.randf_range(-0.12, 0.12)), Vector3(0.75, 0.65, 0.7) * s * (1.1 if i == 1 else 0.9), g, Vector3.ZERO, 0.35)
	if rng.randf() < 0.6:
		for i in 4:
			k.part("sphere", o + Vector3(rng.randf_range(-0.4, 0.4) * s, 0.55 * s, rng.randf_range(-0.2, 0.25) * s), Vector3.ONE * 0.1, Color("#ff6b7a"), Vector3.ZERO, 0.0)


static func _hay(k: MeshKit, o: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf() * TAU
	k.part("cylinder", o + Vector3(0, 0.42, 0), Vector3(0.84, 0.95, 0.84), Color("#e8c25e"), Vector3(PI / 2, yaw, 0), 0.3)
	# two twine bands around the roll
	for sgn in [-1.0, 1.0]:
		var off := Basis.from_euler(Vector3(0, yaw, 0)) * Vector3(0, 0, sgn * 0.22)
		k.part("cylinder", o + Vector3(0, 0.42, 0) + off, Vector3(0.87, 0.06, 0.87), Color("#b98a2e"), Vector3(PI / 2, yaw, 0), 0.2)


# ------------------------------------------------------------ kerbs
## Low cream stone kerbs on both edges of the loop, open where the queue's strip joins it. One mesh with its own
## material (white vertices x albedo) so the game can tint it: it pulses red while the road is full.
static func _kerbs(root: Node3D, L: RoadLayout) -> MeshInstance3D:
	var k := MeshKit.new()
	var T := L.track
	var y0 := RoadLayout.ROAD_Y
	var h := 0.11
	var w := 0.16
	var half := L.road / 2.0
	var n := ceili(T.length / 0.12)
	for i in n:
		var s0 := i * T.length / n
		var s1 := (i + 1) * T.length / n
		var p0 := T.point_at(s0)
		var p1 := T.point_at(s1)
		var t0 := (T.point_at(s0 + 0.05) - p0).normalized()
		var t1 := (T.point_at(s1 + 0.05) - p1).normalized()
		var n0 := Vector3(t0.z, 0, -t0.x)
		var n1 := Vector3(t1.z, 0, -t1.x)
		for side in [-1.0, 1.0]:
			# the outer kerb opens where the strip from the queue runs into the loop
			if side > 0.0 and p0.z > L.hz - 0.2 and absf((p0.x + p1.x) / 2.0) < L.stem_half:
				continue
			var a0: Vector3 = p0 + n0 * side * (half + 0.02)
			var a1: Vector3 = p1 + n1 * side * (half + 0.02)
			var b0: Vector3 = a0 + n0 * side * w
			var b1: Vector3 = a1 + n1 * side * w
			var top := func(v: Vector3) -> Vector3: return Vector3(v.x, y0 + h, v.z)
			var low := func(v: Vector3) -> Vector3: return Vector3(v.x, y0 - 0.02, v.z)
			k.quad(top.call(a0), top.call(a1), top.call(b1), top.call(b0), Color.WHITE)
			k.quad(top.call(a0), top.call(a1), low.call(a1), low.call(a0), Color.WHITE, Color.WHITE.darkened(0.25), -n0 * side)
			k.quad(top.call(b1), top.call(b0), low.call(b0), low.call(b1), Color.WHITE, Color.WHITE.darkened(0.25), n0 * side)
	var mi := k.instance(root, false)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = KERB
	m.roughness = 0.85
	m.metallic_specular = 0.12
	mi.material_override = m
	return mi
