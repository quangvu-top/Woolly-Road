class_name MeshKit
extends RefCounted
## Merges many coloured primitives (sphere, box, cylinder, cone) and custom quads into ONE ArrayMesh with vertex
## colours, so a whole fence / tree / sheep body is a single draw call (Horus perf rule: merge static parts).
## Colours get a soft fake ambient occlusion: darker towards the bottom of each part.

const SEG := {"sphere": [14, 8], "cylinder": [12, 1], "cone": [12, 1]}

static var _arrays := {}
static var _mat: StandardMaterial3D

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()


## One shared material for every merged mesh (vertex colours as albedo).
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 0.9
		_mat.metallic_specular = 0.12
	return _mat


static func _prim(kind: String) -> Array:
	if _arrays.has(kind):
		return _arrays[kind]
	var m: PrimitiveMesh
	match kind:
		"sphere":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = SEG.sphere[0]
			s.rings = SEG.sphere[1]
			m = s
		"box":
			m = BoxMesh.new()
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = SEG.cylinder[0]
			c.rings = 1
			m = c
		"cone":
			var k := CylinderMesh.new()
			k.top_radius = 0.0
			k.bottom_radius = 0.5
			k.height = 1.0
			k.radial_segments = SEG.cone[0]
			k.rings = 1
			m = k
	_arrays[kind] = m.get_mesh_arrays()
	return _arrays[kind]


## Add a unit primitive (size 1, centred) transformed by `xf`, tinted `color`.
## `ao` darkens the lower half of the part (0 = flat colour).
func add(kind: String, xf: Transform3D, color: Color, ao := 0.25) -> MeshKit:
	var a := _prim(kind)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var base := _v.size()
	var nb := xf.basis.inverse().transposed()
	for k in verts.size():
		var p := verts[k]
		_v.append(xf * p)
		_n.append((nb * norms[k]).normalized())
		var shade := clampf(0.5 - p.y, 0.0, 1.0) * ao
		_c.append(color.darkened(shade))
	for j in idx:
		_i.append(base + j)
	return self


## Shorthand: position, scale, optional Euler rotation (radians).
func part(kind: String, pos: Vector3, scl: Vector3, color: Color, rot := Vector3.ZERO, ao := 0.25) -> MeshKit:
	var b := Basis.from_euler(rot).scaled(scl)
	return add(kind, Transform3D(b, pos), color, ao)


## A flat-shaded quad a-b-c-d (any winding; c == d makes a triangle). `facing` is the side that should be lit and
## visible: the winding is fixed up so Godot (clockwise = front face) shows it and the normal points that way.
## a, b get `color`; c, d get `color2` (default the same).
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, color2 = null, facing := Vector3.UP) -> MeshKit:
	var c2: Color = color2 if color2 != null else color
	var pts := [a, b, c, d]
	var cols := [color, color, c2, c2]
	var nrm := (b - a).cross(d - a).normalized()
	if nrm.dot(facing) < 0.0:
		nrm = -nrm
		pts = [a, d, c, b]
		cols = [color, c2, c2, color]
	var base := _v.size()
	for k in 4:
		_v.append(pts[k])
		_n.append(nrm)
		_c.append(cols[k])
	# a-b-c-d is counter-clockwise seen from the normal side; emit clockwise triangles
	_i.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	return self


func is_empty() -> bool:
	return _v.is_empty()


func commit() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_NORMAL] = _n
	arr[Mesh.ARRAY_COLOR] = _c
	arr[Mesh.ARRAY_INDEX] = _i
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, material())
	return m


## Commit into a MeshInstance3D under `parent`.
func instance(parent: Node3D, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
