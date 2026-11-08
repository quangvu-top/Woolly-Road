extends SceneTree
## Level generator (offline tool, not run by the game or the tests):
##   godot --headless --path . -s res://tests/gen_levels.gd
## 1. Builds a pool of random boards from several recipes (Puzzle.generate) and keeps the ones that are
##    solvable, quick for the in-game hint, and hard in the right way.
## 2. Lays levels 2..50 on a smooth difficulty curve: each level takes the unused board whose random-tap win
##    chance is nearest its target, always below the level before (so no level is easier than the last).
## Prints the Levels.ALL lines to paste into scripts/core/levels.gd (level 1 is the hand-made tutorial).
##
## "Hard": p = win chance when tapping at random (Puzzle.analyze); traps = wrong taps on the winning line that
## make the level unwinnable (the player has to think ahead, or replay to learn it).

const PALETTE := ["P", "B", "Y", "L", "O", "W", "K"]
const RECIPES := [
	{colors = 5, fill = [4, 3, 0], cols = 3, seeds = 900},
	{colors = 5, fill = [4, 4, 0], cols = 3, seeds = 900},
	{colors = 6, fill = [4, 3, 0], cols = 3, seeds = 700},
	{colors = 6, fill = [4, 4, 0], cols = 3, seeds = 700},
	{colors = 7, fill = [4, 4, 0], cols = 3, seeds = 500},
	{colors = 7, fill = [4, 4, 3, 0], cols = 3, seeds = 500},
	{colors = 7, fill = [4, 4, 4, 0], cols = 4, seeds = 300},
]
const NODE_CAP := 2500   # keeps the in-game hint (Puzzle.best_move) quick on a phone
const P_FIRST := 0.085   # level 2: about 1 win in 12 random runs, a few tries for a thinking player
const P_LAST := 0.008    # level 50


func _init() -> void:
	var pool := []
	var seen := {}
	for ri in RECIPES.size():
		var rc: Dictionary = RECIPES[ri]
		var t0 := Time.get_ticks_msec()
		var kept := 0
		for k in int(rc.seeds):
			var st := Puzzle.generate(PALETTE.slice(0, rc.colors), rc.fill, rc.cols, 5, 7919 * (ri + 1) + k)
			if st.is_empty():
				continue
			var key := Puzzle.key_of(st)
			if seen.has(key):
				continue
			seen[key] = true
			var r := Puzzle.analyze(st, NODE_CAP + 1, true)
			if r.nodes > NODE_CAP or not r.win or r.p > 0.12 or r.p < 0.004:
				continue
			if r.moves.all(func(m): return m.win):   # some opening tap must already lose
				continue
			var traps := _traps(st)
			if traps < 2:
				continue
			pool.append({st = st, p = r.p, traps = traps, nodes = r.nodes, size = int(rc.colors) * 4, recipe = ri})
			kept += 1
		print("# recipe %d: kept %d (%d ms)" % [ri, kept, Time.get_ticks_msec() - t0])
	print("# pool: %d boards" % pool.size())

	var used := {}
	var prev_p := 1.0
	for n in range(2, 51):
		var u := (n - 2) / 48.0
		var target := exp(lerpf(log(P_FIRST), log(P_LAST), u))
		var best := -1
		var best_s := INF
		for i in pool.size():
			var c: Dictionary = pool[i]
			if used.has(i) or c.p >= prev_p:
				continue
			# nearest to the target; early levels prefer smaller boards, later ones bigger
			var size_pref := absf(c.size - lerpf(20.0, 28.0, u)) * 0.04
			var s := absf(log(c.p) - log(target)) + size_pref
			if s < best_s:
				best_s = s
				best = i
		if best < 0:
			print("# level %d: no board left below p %.4f" % [n, prev_p])
			continue
		used[best] = true
		var c: Dictionary = pool[best]
		prev_p = c.p
		var lv := Puzzle.to_level(c.st)
		print("\t{lanes = %s, queues = %s, cap = 5, hard = true},  # %d: p = %.3f, traps %d, nodes %d" % [
			_strs(lv.lanes), _strs(lv.queues), n, c.p, c.traps, c.nodes])
	quit()


## Wrong taps that would lose, counted along the winning line the hint follows.
static func _traps(start: Dictionary) -> int:
	var s := Puzzle.settle(Puzzle.clone(start))
	var traps := 0
	var guard := 0
	while Puzzle.status(s) == Puzzle.Status.PLAY and guard < 60:
		guard += 1
		var r := Puzzle.analyze(s, NODE_CAP + 1, true)
		if r.moves.any(func(m): return not m.win):
			traps += 1
		var mv := Puzzle.best_move(s)
		if mv.col < 0:
			break
		s = Puzzle.send(s, mv.col)
	return traps


static func _strs(a: Array) -> String:
	return "[" + ", ".join(a.map(func(x): return "\"%s\"" % x)) + "]"
