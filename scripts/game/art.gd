class_name Art
extends RefCounted
## Placeholder 3D art: colours, cached materials and primitive builders (replace with real models later).

const WOOL := {
	"P": Color("#ff9cc8"), "B": Color("#6cc6ff"), "Y": Color("#ffd64d"),
	"L": Color("#b99cff"), "O": Color("#ffa458"), "W": Color("#f7f3ea"), "K": Color("#5a5468"),
}
const GRASS := Color("#7ccd4f")
const GRASS_DARK := Color("#6bbd44")
const DIRT := Color("#d9b27c")
const DIRT_RIM := Color("#b98f5a")
const PEN_FLOOR := Color("#a6dc6e")
const LANE_STRIP := Color("#94d062")
const WOOD := Color("#c48d58")
const FACE := Color("#4a3f52")

static var _mats := {}
static var _box: BoxMesh
static var _sphere: SphereMesh
static var _cyl: CylinderMesh


static func wool(c: String) -> Color:
	return WOOL.get(c, Color.MAGENTA)


static func mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	m.metallic_specular = 0.15
	_mats[key] = m
	return m


static func mesh(kind: String) -> Mesh:
	match kind:
		"box":
			if _box == null:
				_box = BoxMesh.new()
			return _box
		"sphere":
			if _sphere == null:
				_sphere = SphereMesh.new()
				_sphere.radial_segments = 20
				_sphere.rings = 10
			return _sphere
		_:
			if _cyl == null:
				_cyl = CylinderMesh.new()
				_cyl.top_radius = 0.5
				_cyl.bottom_radius = 0.5
				_cyl.radial_segments = 12
			return _cyl


## A primitive (unit box / sphere of diameter 1 / cylinder of diameter 1 and height 2 scaled) under parent.
static func prim(kind: String, parent: Node3D, pos: Vector3, scl: Vector3, color: Color, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(kind)
	mi.material_override = mat(color)
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A flat box lying on the ground: centre (cx, cz), size w x d, top at `top`, height h.
static func slab(parent: Node3D, cx: float, cz: float, w: float, d: float, top: float, h: float, color: Color, yaw := 0.0) -> MeshInstance3D:
	var mi := prim("box", parent, Vector3(cx, top - h / 2.0, cz), Vector3(w, h, d), color, h > 0.15)
	mi.rotation.y = yaw
	return mi
