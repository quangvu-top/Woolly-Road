extends SceneTree
## Headless tests: godot --headless --path . -s res://tests/run_tests.gd
## Expected numbers come from the three.js prototype (src/logic.js) and match the Unity port exactly; since
## 2026-11-08 the 50 levels come from tests/gen_levels.gd, so the level checks are rules, not fixed numbers.

var _pass := 0
var _fail := 0


func _init() -> void:
	_run("pick_lane prefers rightmost matching top", func():
		_eq(Puzzle.pick_lane([["P", "B"], [], ["Y", "B"]], "B"), 2)
		_eq(Puzzle.pick_lane([["P", "B"], [], ["Y", "Y"]], "B"), 0))
	_run("pick_lane uses rightmost empty only when nothing matches", func():
		_eq(Puzzle.pick_lane([[], ["P"], []], "B"), 2)
		_eq(Puzzle.pick_lane([["P"], ["Y"]], "B"), -1))
	_run("settle: full pen pushes bottom out, then clears", func():
		var s := Puzzle.make_state([["P", "B", "B", "B"], []], [[]], ["B"], 4)
		Puzzle.settle(s)
		_eq(s.lanes[0], [])
		_eq(s.lanes[1], ["P"])
		_eq(s.track.size(), 0))
	_run("status: lose when road full", func():
		var s := Puzzle.make_state([["P"], ["Y"]], [["B"]], ["B", "B"], 2)
		_eq(Puzzle.status(Puzzle.settle(s)), Puzzle.Status.LOSE))
	_run("send does not mutate input", func():
		var s0 := Puzzle.from_level(Levels.get_level(0))
		var before := Puzzle.key_of(s0)
		Puzzle.send(s0, 0)
		_eq(Puzzle.key_of(s0), before))

	# 50 levels: level 1 is the tutorial (always won), every level after it is a hard level on a curve that
	# never gets easier; each one is solvable, the hint line wins it, and the hint stays quick (state count)
	_run("there are 50 levels", func(): _eq(Levels.count(), 50))
	var ps := []
	var worst_nodes := 0
	var all_ok := true
	var msgs := ""
	for i in Levels.count():
		var lv := Levels.get_level(i)
		var r := Puzzle.analyze(Puzzle.from_level(lv))
		ps.append(r.p)
		worst_nodes = maxi(worst_nodes, r.nodes)
		var s := Puzzle.settle(Puzzle.from_level(lv))
		var guard := 0
		while Puzzle.status(s) == Puzzle.Status.PLAY and guard < 100:
			s = Puzzle.send(s, Puzzle.best_move(s).col)
			guard += 1
		if not r.win or Puzzle.status(s) != Puzzle.Status.WIN or int(lv.cap) != 5:
			all_ok = false
			msgs += "level %d (win %s, hint line %d, cap %d) " % [i + 1, r.win, Puzzle.status(s), lv.cap]
	_run("every level is solvable and won by following hints", func(): _true(all_ok, msgs))
	_run("level 1 is the tutorial: any taps win", func():
		_true(Levels.get_level(0).get("tutorial", false), "tutorial flag")
		_near(ps[0], 1.0, 1e-12))
	_run("level 2 on are hard levels, level 2 much harder than level 1", func():
		for i in range(1, Levels.count()):
			_true(Levels.get_level(i).get("hard", false), "level %d is a hard level" % (i + 1))
		_true(ps[1] <= 0.12, "level 2 random-tap win chance %.3f" % ps[1]))
	_run("levels never get easier", func():
		for i in range(1, ps.size()):
			_true(ps[i] <= ps[i - 1] + 1e-12, "level %d (p %.4f) not easier than %d (p %.4f)" % [i + 1, ps[i], i, ps[i - 1]]))
	_run("hint search stays small on every level", func(): _true(worst_nodes <= 2500, "nodes %d" % worst_nodes))

	_run("mulberry32 matches prototype", func():
		var r := Puzzle.Mulberry32.new(12345)
		_near(r.next(), 0.9797282677609473, 1e-15)
		_near(r.next(), 0.3067522644996643, 1e-15)
		_near(r.next(), 0.484205421525985, 1e-15))
	_run("generate matches prototype", func():
		var lv := Puzzle.to_level(Puzzle.generate(["P", "B", "Y", "L"], [4, 3, 0], 3, 4, 777))
		_eq(lv.lanes, ["PLYL", "YYB", ""])
		_eq(lv.queues, ["LBP", "BBP", "LPY"])
		_eq(lv.cap, 4))

	# ---- meta rules (lives, unlocks, names, daily gift)
	_run("lives: losing one starts the refill clock, one comes back per period", func():
		var s := {lives = 5, lives_t = 0.0}
		Meta.lose_life(s, 1000.0)
		_eq(s.lives, 4)
		_eq(s.lives_t, 1000.0)
		Meta.regen(s, 1000.0 + 20 * 60 - 1, 20)
		_eq(s.lives, 4)
		_near(Meta.next_life_in(s, 1000.0 + 20 * 60 - 1, 20), 1.0, 1e-6)
		Meta.regen(s, 1000.0 + 20 * 60 + 5, 20)
		_eq(s.lives, 5))
	_run("lives: partial period is kept, never above 5, never below 0", func():
		var s := {lives = 1, lives_t = 0.0}
		Meta.regen(s, 2.5 * 600.0, 10)   # 2.5 periods of 10 min
		_eq(s.lives, 3)
		_near(s.lives_t, 1200.0, 1e-6)
		Meta.regen(s, 99999.0, 10)
		_eq(s.lives, 5)
		var z := {lives = 0, lives_t = 0.0}
		Meta.lose_life(z, 0.0)
		_eq(z.lives, 0)
		Meta.add_lives(z, 9, 50.0)
		_eq(z.lives, 5))
	_run("lives: clock going backwards does not freeze the refill", func():
		var s := {lives = 2, lives_t = 5000.0}
		Meta.regen(s, 100.0, 20)
		_eq(s.lives, 2)
		_eq(s.lives_t, 100.0))
	_run("boosters unlock one per level after the tutorial", func():
		_eq(Meta.unlock_on(0), "")
		_eq(Meta.unlock_on(1), "undo")
		_eq(Meta.unlock_on(2), "slot")
		_eq(Meta.unlock_on(3), "hint")
		_true(not Meta.unlocked("hint", 2) and Meta.unlocked("hint", 3), "hint locked before level 4"))
	_run("nickname rules (3-14, letters digits _ . -)", func():
		_true(Meta.valid_name("Shepherd_01"), "plain name ok")
		_true(not Meta.valid_name("ab"), "too short")
		_true(not Meta.valid_name("abcdefghijklmno"), "too long")
		_true(not Meta.valid_name("Cừu"), "no accents")
		_true(not Meta.valid_name("a b c"), "no spaces"))
	_run("daily gift reward goes into the save", func():
		var s := {coins = 10, undo = 0}
		_eq(Meta.give_daily(s, {coins = 30}), 30)
		_eq(Meta.give_daily(s, {undo = 1}), 0)
		_eq(s.coins, 40)
		_eq(s.undo, 1))
	_run("vietnamese translation covers the main buttons", func():
		for k in ["PLAY", "Level %d", "RETRY", "Continue", "DAILY GIFT", "Refill Lives", "Are you sure?"]:
			_true(I18n.VI.has(k), "a translation for " + k))

	print("\n%d passed, %d failed" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


var _cur_ok := true
var _cur_msg := ""


func _run(name: String, body: Callable) -> void:
	_cur_ok = true
	_cur_msg = ""
	body.call()
	if _cur_ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, ": ", _cur_msg)


func _eq(a, b) -> void:
	if not (a == b):
		_cur_ok = false
		_cur_msg += "expected <%s> but was <%s>. " % [str(b), str(a)]


func _near(a: float, b: float, tol: float) -> void:
	if absf(a - b) > tol:
		_cur_ok = false
		_cur_msg += "expected %.17f but was %.17f. " % [b, a]


func _true(c: bool, what: String) -> void:
	if not c:
		_cur_ok = false
		_cur_msg += "expected " + what + ". "
