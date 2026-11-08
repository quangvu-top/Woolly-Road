class_name RoadLayout
extends RefCounted
## Board geometry. Port of prototype/src/layout.js (Godot uses the same axes as three.js:
## +x right, +y up, +z towards the camera). The queue sits at +z, the top of the pen at -z.

const ROAD_Y := 0.07   # top of the dirt road
const PEN_Y := 0.035   # top of the pen floor
const MIN_GAP := 0.8   # loop edge -> front queue sheep when the screen has no room for open ground between them

var n_lanes: int
var n_cols: int
var lane_w := 1.42
var slot := 1.05
var pen_pad := 1.3       # free floor above + below the 4 slots (chevrons at the top)
var pen_low := 0.55      # floor below the bottom slot
var road := 1.1
var r := 1.3
var col_gap := 1.42      # queue columns line up with the pen lanes
var pen_half_w: float
var pen_half_h: float
var hx: float
var hz: float
var road_outer_z: float
var queue_z0: float
var stem_half: float
var lane_x: Array[float] = []
var col_x: Array[float] = []
var s_in: Array[float] = []
var s_out: Array[float] = []
var s_join: Array[float] = []
var track: Track


func _init(nl: int, nc: int) -> void:
	n_lanes = nl
	n_cols = nc
	pen_half_w = nl * lane_w / 2.0 + 0.2
	pen_half_h = (Puzzle.LANE_CAP * slot + pen_pad) / 2.0
	hx = pen_half_w + road / 2.0
	hz = pen_half_h + road / 2.0
	track = Track.new(hx, hz, r)
	for i in nl:
		lane_x.append((i - (nl - 1) / 2.0) * lane_w)
	for c in nc:
		col_x.append((c - (nc - 1) / 2.0) * col_gap)
	stem_half = (nc - 1) * col_gap / 2.0 + 0.85
	road_outer_z = hz + road / 2.0
	set_gap(MIN_GAP)
	for i in nl:
		s_in.append(track.nearest_s(lane_x[i], -hz))
		s_out.append(track.nearest_s(lane_x[i], hz))
	for c in nc:
		s_join.append(track.nearest_s(col_x[c], hz))


## Pen slot j (0 = bottom/exit, near the player) of lane i.
func slot_pos(i: int, j: float) -> Vector3:
	return Vector3(lane_x[i], PEN_Y, pen_half_h - pen_low - slot * (j + 0.5))


## Entrance of lane i on the far side of the pen.
func lane_top(i: int) -> Vector3:
	return Vector3(lane_x[i], PEN_Y, -pen_half_h + 0.1)


## Distance from the outer road edge to the front queue row. The game picks it from the screen so the loop
## sits in the middle of the space above the queue (reference layout); the dirt strip joins them.
func set_gap(g: float) -> void:
	queue_z0 = road_outer_z + maxf(MIN_GAP, g)


## Where the queue's dirt strip starts: it always runs up into the loop, so the road joins the queue.
func stem_top() -> float:
	return hz


## k-th sheep of queue column c (0 = front).
func queue_pos(c: int, k: int) -> Vector3:
	return Vector3(col_x[c], ROAD_Y, queue_z0 + k * slot)


## Where a sent sheep waits to merge onto the road.
func join_wait(c: int) -> Vector3:
	return Vector3(col_x[c], ROAD_Y, road_outer_z + 0.35)


## Closed one-way road around the pen, sampled by arc length.
## Direction: near side (+x) -> right side (-z) -> far side (-x) -> left side (+z).
class Track:
	var _x := PackedFloat32Array()
	var _z := PackedFloat32Array()
	var _cum := PackedFloat32Array()
	var length := 0.0

	func _init(hx: float, hz: float, r: float) -> void:
		const STEP := 0.04
		const H := PI / 2.0
		_line(-hx + r, hz, hx - r, hz, STEP)
		_arc(hx - r, hz - r, H, 0.0, r, STEP)
		_line(hx, hz - r, hx, -hz + r, STEP)
		_arc(hx - r, -hz + r, 0.0, -H, r, STEP)
		_line(hx - r, -hz, -hx + r, -hz, STEP)
		_arc(-hx + r, -hz + r, -H, -2.0 * H, r, STEP)
		_line(-hx, -hz + r, -hx, hz - r, STEP)
		_arc(-hx + r, hz - r, 2.0 * H, H, r, STEP)
		var n := _x.size()
		_cum.resize(n + 1)
		var acc := 0.0
		for i in n:
			_cum[i] = acc
			var j := (i + 1) % n
			acc += Vector2(_x[j] - _x[i], _z[j] - _z[i]).length()
		_cum[n] = acc
		length = acc

	func _line(x0: float, z0: float, x1: float, z1: float, step: float) -> void:
		var n := maxi(1, ceili(Vector2(x1 - x0, z1 - z0).length() / step))
		for i in n:
			_x.append(x0 + (x1 - x0) * i / n)
			_z.append(z0 + (z1 - z0) * i / n)

	func _arc(cx: float, cz: float, a0: float, a1: float, r: float, step: float) -> void:
		var n := maxi(2, ceili(absf(a1 - a0) * r / step))
		for i in n:
			var a := a0 + (a1 - a0) * i / n
			_x.append(cx + cos(a) * r)
			_z.append(cz + sin(a) * r)

	func wrap_s(s: float) -> float:
		return fposmod(s, length)

	func point_at(s: float) -> Vector3:
		s = wrap_s(s)
		var n := _x.size()
		var lo := 0
		var hi := n
		while hi - lo > 1:
			var m := (lo + hi) >> 1
			if _cum[m] <= s:
				lo = m
			else:
				hi = m
		var t := (s - _cum[lo]) / maxf(1e-6, _cum[lo + 1] - _cum[lo])
		var j := (lo + 1) % n
		return Vector3(lerpf(_x[lo], _x[j], t), RoadLayout.ROAD_Y, lerpf(_z[lo], _z[j], t))

	func nearest_s(x: float, z: float) -> float:
		var best := 0
		var bd := INF
		for i in _x.size():
			var d := (_x[i] - x) * (_x[i] - x) + (_z[i] - z) * (_z[i] - z)
			if d < bd:
				bd = d
				best = i
		return _cum[best]
