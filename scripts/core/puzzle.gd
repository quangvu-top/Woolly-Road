class_name Puzzle
extends RefCounted
## Pure puzzle model (no rendering). Port of prototype/src/logic.js and the Unity WoollyRoad.Core.Puzzle.
## Used by the real-time game (hint / undo) and by tests that verify every level is solvable.
##
## A state is a Dictionary:
##   lanes  : Array of Array[String]  each pen bottom(exit) -> top(entry), max LANE_CAP
##   queues : Array of Array[String]  each column front-first
##   track  : Array[String]           sheep on the road, oldest first
##   cap    : int                     road capacity
##   cycle  : bool                    set by settle() when sheep would circle forever (a loss)

const LANE_CAP := 4
const SETTLE_STEP_LIMIT := 200

enum Status { PLAY, WIN, LOSE }


static func make_state(lanes: Array, queues: Array, track: Array, cap: int) -> Dictionary:
	return {lanes = lanes, queues = queues, track = track, cap = cap, cycle = false}


static func clone(s: Dictionary) -> Dictionary:
	return {
		lanes = s.lanes.map(func(l): return l.duplicate()),
		queues = s.queues.map(func(q): return q.duplicate()),
		track = s.track.duplicate(),
		cap = s.cap,
		cycle = s.get("cycle", false),
	}


static func from_level(lv: Dictionary) -> Dictionary:
	return make_state(
		lv.lanes.map(func(str): return _chars(str)),
		lv.queues.map(func(str): return _chars(str)),
		[], lv.cap)


static func to_level(s: Dictionary) -> Dictionary:
	return {
		lanes = s.lanes.map(func(l): return "".join(l)),
		queues = s.queues.map(func(q): return "".join(q)),
		cap = s.cap,
	}


static func _chars(str: String) -> Array:
	var out := []
	for i in str.length():
		out.append(str[i])
	return out


## A sheep on the road meets the pens right-to-left. A pen whose top matches wins;
## an empty pen is used only when no pen matches. Returns -1 if none fits.
static func pick_lane(lanes: Array, color: String) -> int:
	for i in range(lanes.size() - 1, -1, -1):
		var l: Array = lanes[i]
		if l.size() > 0 and l[l.size() - 1] == color:
			return i
	for i in range(lanes.size() - 1, -1, -1):
		if lanes[i].is_empty():
			return i
	return -1


## Resolve all automatic movement (in place) until nothing on the road can park.
static func settle(s: Dictionary) -> Dictionary:
	var steps := 0
	var moved := true
	while moved:
		moved = false
		for k in s.track.size():
			var c: String = s.track[k]
			var li := pick_lane(s.lanes, c)
			if li < 0:
				continue
			steps += 1
			if steps > SETTLE_STEP_LIMIT:
				s.cycle = true
				return s
			s.track.remove_at(k)
			var lane: Array = s.lanes[li]
			if lane.size() == LANE_CAP:
				s.track.append(lane.pop_front())   # a full pen pushes its bottom sheep out
			lane.append(c)
			if lane.size() == LANE_CAP and lane.all(func(x): return x == c):
				lane.clear()                        # four of a colour clears
			moved = true
			break
	return s


static func can_send(s: Dictionary, col: int) -> bool:
	return s.queues[col].size() > 0 and s.track.size() < s.cap


## A new, settled state after sending the front sheep of a column.
static func send(s: Dictionary, col: int) -> Dictionary:
	var n := clone(s)
	n.track.append(n.queues[col].pop_front())
	return settle(n)


## Status of a settled state.
static func status(s: Dictionary) -> Status:
	if s.get("cycle", false):
		return Status.LOSE
	var q_empty: bool = s.queues.all(func(q): return q.is_empty())
	if q_empty and s.track.is_empty() and s.lanes.all(func(l): return l.is_empty()):
		return Status.WIN
	if s.track.size() >= s.cap:
		return Status.LOSE
	if q_empty:
		return Status.LOSE
	return Status.PLAY


static func key_of(s: Dictionary) -> String:
	var lanes: Array = s.lanes.map(func(l): return "".join(l))
	var queues: Array = s.queues.map(func(q): return "".join(q))
	return "|".join(lanes) + "/" + "|".join(queues) + "/" + "".join(s.track) + "/" + str(s.cap)


## Exhaustive analysis of every tap sequence.
## Returns {p: win chance under random taps, win: can be won, moves: [{col, p, win}], nodes: distinct states}.
static func analyze(start: Dictionary, limit: int = 400000, quiet := false) -> Dictionary:
	var ctx := {memo = {}, nodes = 0, limit = limit, quiet = quiet}
	var r := _rec(settle(clone(start)), ctx)
	return {p = r.p, win = r.win, moves = r.get("moves", []), nodes = ctx.memo.size()}


static func _rec(s: Dictionary, ctx: Dictionary) -> Dictionary:
	var st := status(s)
	if st == Status.WIN:
		return {p = 1.0, win = true}
	if st == Status.LOSE:
		return {p = 0.0, win = false}
	var k := key_of(s)
	if ctx.memo.has(k):
		return ctx.memo[k]
	ctx.nodes += 1
	if ctx.nodes > ctx.limit:
		if not ctx.quiet:   # the level generator probes past its cap on purpose
			push_error("Puzzle.analyze: search limit")
		return {p = 0.0, win = false}
	var sum := 0.0
	var n := 0
	var win := false
	var moves := []
	for c in s.queues.size():
		if not can_send(s, c):
			continue
		var r := _rec(send(s, c), ctx)
		moves.append({col = c, p = r.p, win = r.win})
		sum += r.p
		n += 1
		win = win or r.win
	var res := {p = (sum / n) if n > 0 else 0.0, win = win, moves = moves}
	ctx.memo[k] = res
	return res


## Best next tap: prefer moves that can still win, then the most forgiving one. col = -1 if none.
static func best_move(state: Dictionary) -> Dictionary:
	var s := settle(clone(state))
	if status(s) != Status.PLAY:
		return {col = -1, p = 0.0, win = false}
	var best := {col = -1, p = -1.0, win = false}
	for c in s.queues.size():
		if not can_send(s, c):
			continue
		var r := analyze(send(s, c))
		if (r.win and not best.win) or (r.win == best.win and r.p > best.p):
			best = {col = c, p = r.p, win = r.win}
	return best


# ---------- level generation tools ----------

## Builds a random level: LANE_CAP sheep of each colour, shuffled, the first ones filling the pens per fill,
## the rest dealt round-robin into the queues. Returns {} if a pen would start already cleared.
static func generate(colors: Array, fill: Array, n_cols: int, cap: int, seed: int) -> Dictionary:
	var rng := Mulberry32.new(seed)
	var bag := []
	for c in colors:
		for i in LANE_CAP:
			bag.append(c)
	for i in range(bag.size() - 1, 0, -1):
		var j := int(floor(rng.next() * (i + 1)))
		var t = bag[i]
		bag[i] = bag[j]
		bag[j] = t
	var lanes := []
	var idx := 0
	for f in fill:
		var l: Array = bag.slice(idx, idx + f)
		idx += f
		if l.size() == LANE_CAP and l.all(func(x): return x == l[0]):
			return {}
		lanes.append(l)
	var queues := []
	for c in n_cols:
		queues.append([])
	var k := 0
	for c in bag.slice(idx):
		queues[k % n_cols].append(c)
		k += 1
	return make_state(lanes, queues, [], cap)


## Deterministic PRNG, bit-identical to the prototype's mulberry32.
class Mulberry32:
	var _a: int

	func _init(seed: int) -> void:
		_a = seed & 0xFFFFFFFF

	## Uniform float in [0, 1).
	func next() -> float:
		_a = (_a + 0x6D2B79F5) & 0xFFFFFFFF
		var t := _imul(_a ^ (_a >> 15), 1 | _a)
		t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

	## Low 32 bits of a 32x32 multiply without overflowing 64-bit ints.
	static func _imul(a: int, b: int) -> int:
		a &= 0xFFFFFFFF
		b &= 0xFFFFFFFF
		var lo := a * (b & 0xFFFF)
		var hi := ((a * (b >> 16)) & 0xFFFF) << 16
		return (lo + hi) & 0xFFFFFFFF
