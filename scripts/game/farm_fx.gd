class_name FarmFx
extends Node3D
## Tiny particle system on MultiMeshes (one draw call per kind): dust puffs under walking sheep, wool bursts when a
## pen clears, confetti on a win. Ticked by WoollyGame.step so it pauses with the game and runs in tests.

const MAX_PUFFS := 360
const MAX_FLAKES := 220

var _puffs: MultiMeshInstance3D
var _flakes: MultiMeshInstance3D
var _p: Array = []   # puff particles: {pos, vel, age, life, s0, s1, col, grav}
var _f: Array = []   # confetti flakes: {pos, vel, age, life, col, rot, spin}


func _ready() -> void:
	_puffs = _make(SphereMesh.new(), MAX_PUFFS)
	var flake := BoxMesh.new()
	flake.size = Vector3(1, 0.15, 0.6)
	_flakes = _make(flake, MAX_FLAKES)


func _make(mesh: Mesh, n: int) -> MultiMeshInstance3D:
	if mesh is SphereMesh:
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 10
		mesh.rings = 5
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A soft dust puff at ground level.
func dust(pos: Vector3, n := 1, col := Color("#e8d3ae")) -> void:
	for i in n:
		_add_puff(pos + Vector3(randf_range(-0.15, 0.15), 0.08, randf_range(-0.15, 0.15)),
			Vector3(randf_range(-0.4, 0.4), randf_range(0.3, 0.7), randf_range(-0.4, 0.4)),
			0.4 + randf() * 0.15, 0.08, 0.24 + randf() * 0.1, col.lightened(0.15), -0.6)


## Wool flying everywhere (a pen cleared).
func burst(pos: Vector3, col: Color, n := 16) -> void:
	for i in n:
		var a := randf() * TAU
		var up := randf_range(2.5, 5.0)
		var out := randf_range(1.0, 3.0)
		var c := col if randf() < 0.75 else Color.WHITE
		_add_puff(pos, Vector3(cos(a) * out, up, sin(a) * out), 0.8 + randf() * 0.4, 0.32, 0.05, c.lightened(randf() * 0.15), 9.0)


## Confetti raining over the board (a win).
func confetti(centre: Vector3, n := 160) -> void:
	var cols := [Color("#ff5d8f"), Color("#ffd23a"), Color("#4fc3ff"), Color("#7be36a"), Color("#b98cff"), Color("#ff9e3d")]
	for i in n:
		if _f.size() >= MAX_FLAKES:
			_f.pop_front()
		_f.append({
			pos = centre + Vector3(randf_range(-5, 5), randf_range(5, 11), randf_range(-6, 4)),
			vel = Vector3(randf_range(-0.6, 0.6), randf_range(-2.5, -1.0), randf_range(-0.6, 0.6)),
			age = 0.0, life = 3.0 + randf() * 1.5, col = cols[randi() % cols.size()],
			rot = Vector3(randf() * TAU, randf() * TAU, randf() * TAU),
			spin = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)),
		})


func clear() -> void:
	_p.clear()
	_f.clear()
	_puffs.multimesh.visible_instance_count = 0
	_flakes.multimesh.visible_instance_count = 0


func _add_puff(pos: Vector3, vel: Vector3, life: float, s0: float, s1: float, col: Color, grav: float) -> void:
	if _p.size() >= MAX_PUFFS:
		_p.pop_front()
	_p.append({pos = pos, vel = vel, age = 0.0, life = life, s0 = s0, s1 = s1, col = col, grav = grav})


func tick(dt: float) -> void:
	var mm := _puffs.multimesh
	var alive := []
	for q in _p:
		q.age += dt
		if q.age >= q.life:
			continue
		q.vel.y -= q.grav * dt
		q.vel *= 1.0 - minf(1.0, dt * 1.5)
		q.pos += q.vel * dt
		if q.pos.y < 0.05:
			q.pos.y = 0.05
			q.vel.y = 0.0
		alive.append(q)
	_p = alive
	for k in _p.size():
		var q: Dictionary = _p[k]
		var t: float = q.age / q.life
		var s: float = lerpf(q.s0, q.s1, sin(minf(1.0, t * 1.6) * PI * 0.5)) * (1.0 - smoothstep(0.65, 1.0, t))
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * maxf(0.001, s)), q.pos))
		mm.set_instance_color(k, q.col)
	mm.visible_instance_count = _p.size()

	var fm := _flakes.multimesh
	var keep := []
	for f in _f:
		f.age += dt
		if f.age >= f.life:
			continue
		f.vel.x += sin(f.age * 3.0 + f.rot.x) * dt * 1.5
		f.pos += f.vel * dt
		f.rot += f.spin * dt
		keep.append(f)
	_f = keep
	for k in _f.size():
		var f: Dictionary = _f[k]
		var fade: float = 1.0 - smoothstep(0.8, 1.0, f.age / f.life)
		fm.set_instance_transform(k, Transform3D(Basis.from_euler(f.rot).scaled(Vector3.ONE * 0.16 * fade), f.pos))
		fm.set_instance_color(k, f.col)
	fm.visible_instance_count = _f.size()
