extends Node
## Scene test with the real game, the Horus autoload and its simulator:
##   godot --headless --path . res://tests/autoplay.tscn                 -> gameplay + SDK checks
##   godot --path . res://tests/autoplay.tscn -- --capture <dir>          -> screenshots of every screen
## Exit code 0 = all passed.

var main: Node
var game: WoollyGame
var hud: Hud
var _pass := 0
var _fail := 0


func _ready() -> void:
	# fresh install: no save, no app backup copy
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://horus/backup.json"))
	for f in DirAccess.get_files_at("user://"):
		if f.ends_with(".json") or f.ends_with(".cfg") or f.begins_with("woolly"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	main = load("res://main.tscn").instantiate()
	add_child(main)
	print("main added")
	while main.game == null or main.game._lay == null:
		await get_tree().process_frame
	print("booted")
	game = main.game
	hud = main.hud
	main.S.seen_unlock = Meta.BOOSTERS.duplicate()   # unlock screens are checked on their own (flow tests)
	var args := OS.get_cmdline_user_args()
	var cap := args.find("--capture")
	if cap >= 0:
		await _capture(args[cap + 1] if args.size() > cap + 1 else "capture")
	else:
		await _tests()
		await _flow_tests()
	print("\n%d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _check(name: String, ok: bool, detail := "") -> void:
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, " ", detail)


func _sim(seconds: float) -> void:
	game.paused_by_app = true   # keep _process from stepping too: the test drives time
	var t := 0.0
	while t < seconds:
		game.step(1.0 / 60.0)
		t += 1.0 / 60.0


func _tests() -> void:
	_check("boot: home screen, Horus simulated", game.mode == WoollyGame.Mode.MENU and Horus.simulated)
	for i in [0, 1, 2, 3, 4, 5, 9, 19, 29, 39, 49]:   # the tutorial, the first hard levels and a spread to 50 (all 50: run_tests.gd)
		game.load_level(i)
		_sim(2.0)
		var sends := 0
		var t := 0.0
		var expect := ""
		var drift := ""
		while game.mode == WoollyGame.Mode.PLAY and t < 300.0:
			if hud.is_open(hud._coach):
				hud._coach_next()   # level 1 coach cards: Continue
			if game.is_quiet():
				var snap := game.snapshot()
				var key := Puzzle.key_of(Puzzle.settle(Puzzle.clone(snap)))
				if expect != "" and key != expect and drift == "":
					drift = "after %d sends: model %s, game %s" % [sends, expect, key]
				var mv := Puzzle.best_move(snap)
				if not mv.win:
					break
				expect = Puzzle.key_of(Puzzle.send(Puzzle.settle(Puzzle.clone(snap)), mv.col))
				game.send(mv.col)
				sends += 1
			game.step(1.0 / 60.0)
			t += 1.0 / 60.0
		_check("level %d won by following hints (%d sends)" % [i + 1, sends], game.mode == WoollyGame.Mode.WON, "mode=%d t=%.1f" % [game.mode, t])
		_check("level %d plays out exactly like the puzzle model" % (i + 1), drift == "", drift)
		_sim(3.0)

	# spamming one column always ends (win or lose), never hangs
	game.load_level(4)
	_sim(2.0)
	var t2 := 0.0
	while game.mode == WoollyGame.Mode.PLAY and t2 < 300.0:
		for c in game.column_count():
			if game.queue_count(c) > 0:
				game.send(c)
				break
		game.step(1.0 / 60.0)
		t2 += 1.0 / 60.0
	_check("spamming a column reaches an end state", game.mode == WoollyGame.Mode.WON or game.mode == WoollyGame.Mode.LOST)

	# level 1 coach: only the shown sheep first, then the pen card, then the push card, then free play
	game.load_level(0)
	_sim(2.0)
	_check("tutorial: only the shown sheep can be sent first", not game._tut_allows(0) and game._tut_allows(game.TUT_COL) and hud.coach_open())
	game.send(game.TUT_COL)
	var tt := 0.0
	while not hud.is_open(hud._coach) and tt < 10.0:
		game.step(1.0 / 60.0)
		tt += 1.0 / 60.0
	_check("tutorial: the game waits on the pen card", hud.is_open(hud._coach) and hud.paused(), "t=%.1f" % tt)
	hud._coach_next()
	_sim(1.0)
	_check("tutorial: then the pushed-out card", hud.is_open(hud._coach))
	hud._coach_next()
	_check("tutorial: free play after Continue", game._tut_step == 4 and not hud.coach_open() and game._tut_allows(0))

	# rapid taps (reference video): every tap sends a sheep at once, the counter counts it straight away; on a full
	# road a tap is turned away without a message and the kerbs go red
	game.load_level(9, false)
	_sim(0.5)
	var col_seq := [0, 1, 0, 2, 1]
	for c in col_seq:
		game.send(c)
		_sim(0.1)
	_check("rapid taps: five taps put five sheep on their way at once", game._road.size() == 5 and game.road_full(), "road %d" % game._road.size())
	var before_q := game.queue_count(2)
	game.send(2)
	game._update_kerbs(0.1)
	var kerb_mat := (game._world.get_meta("kerb") as MeshInstance3D).material_override as StandardMaterial3D
	_check("full road: another tap is turned away, no message", game.queue_count(2) == before_q and not hud._toast.visible)
	_check("full road: the kerbs turn red", kerb_mat.albedo_color.r > kerb_mat.albedo_color.g + 0.15, str(kerb_mat.albedo_color))

	# sheep never run through each other: random taps on several levels, every frame no two moving sheep overlap
	var hits := 0
	var hit_at := ""
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for li in [1, 4, 9, 29, 49]:
		game.load_level(li, false)
		_sim(0.5)
		var ot := 0.0
		while ot < 40.0 and game.mode == WoollyGame.Mode.PLAY:
			if rng.randf() < 0.025:
				var c := rng.randi() % game.column_count()
				if game.queue_count(c) > 0 and game._road.size() < game.cap_now():
					game.send(c)
			game.step(1.0 / 60.0)
			ot += 1.0 / 60.0
			var o := _overlap()
			if o != "":
				hits += 1
				if hit_at == "":
					hit_at = "level %d t=%.2f %s" % [li + 1, ot, o]
	_check("sheep never run through each other", hits == 0, "%d overlapping frames, first: %s" % [hits, hit_at])

	# a sent sheep runs from the queue into its road slot without stopping (no stop-and-go at the road edge)
	game.load_level(4)
	_sim(2.0)
	var stalls := 0
	var longest := 0
	var max_jolt := 0.0
	var jolt_at := ""
	var frames := 0
	var worst := ""
	for k in 4:
		var c := k % game.column_count()
		if game.queue_count(c) == 0 or game.mode != WoollyGame.Mode.PLAY:
			continue
		var sh: Sheep = game._queues[c][0]
		game.send(c)
		var last := sh.position
		var moving := false
		var run := 0
		var v_prev := -1.0
		var on_road_t := -1.0
		var t := 0.0
		while t < 6.0 and is_instance_valid(sh) and sh.state != Sheep.State.ENTERING and (on_road_t < 0.0 or t - on_road_t < 1.2):
			game.step(1.0 / 60.0)
			t += 1.0 / 60.0
			var v := Vector2(sh.position.x - last.x, sh.position.z - last.z).length() * 60.0
			last = sh.position
			if v > 1.0:
				moving = true
				run = 0
			elif moving:
				stalls += 1
				run += 1
				if run > longest:
					longest = run
					worst = "sheep %d at t=%.2f (state %d) %s" % [k, t, sh.state, _ahead_info(sh)]
			frames += 1
			if v_prev > 0.0 and absf(v - v_prev) > max_jolt:
				max_jolt = absf(v - v_prev)
				jolt_at = "sheep %d at t=%.2f (state %d) %.1f -> %.1f" % [k, t, sh.state, v_prev, v]
			v_prev = v
			if on_road_t < 0.0 and sh.state == Sheep.State.TRACK:
				on_road_t = t
		_sim(0.6)
	# a short give-way at the road edge is fine (a sheep is passing right there); standing about is not
	_check("sent sheep reach the road without standing about", longest <= 24, "longest stop %d frames (%d stalled of %d); %s" % [longest, stalls, frames, worst])
	_check("and without sudden speed jumps", max_jolt < 2.0, "biggest change in one frame %.2f: %s" % [max_jolt, jolt_at])

	# road slots: sheep on the road ride evenly spaced slots (L / cap apart), one sheep per slot, also after +1 Road
	game.load_level(4)
	_sim(2.0)
	for k in 15:   # keep sending sheep that find no pen yet, until two of them circle
		if game._road.filter(func(s): return s.state == Sheep.State.TRACK).size() >= 2 or game.mode != WoollyGame.Mode.PLAY:
			break
		var pick := k % game.column_count()
		for c in game.column_count():
			if game.queue_count(c) > 0 and not game._any_enter(game._queues[c][0].color):
				pick = c
		game.send(pick)
		_sim(2.5)
	_sim(4.0)
	_check("road sheep sit in evenly spaced slots", _slots_ok(), _slot_info())
	game._cap_bonus += 1
	game._reslot()
	_sim(4.0)
	_check("+1 Road re-spreads the slots evenly", _slots_ok(), _slot_info())

	# purchase: goods once per token, saved before finish
	var coins0 := int(main.S.coins)
	var r := await Horus.iap.buy("starter_pack")
	_check("simulated purchase ok", r.get("status") == "ok", str(r))
	if r.get("status") == "ok":
		main._grant(r)
		main._grant(r)   # the same order reported twice
		_check("starter pack granted exactly once", int(main.S.coins) == coins0 + 500, "coins %d -> %d" % [coins0, main.S.coins])
	# remove ads is a one-off
	var r2 := await Horus.iap.buy("remove_ads")
	if r2.get("status") == "ok":
		main._grant(r2)
	_check("remove ads sets no_ads", bool(main.S.get("no_ads", false)))

	# rewarded: three taps while the first ad is open -> one ad
	game.load_level(1)
	_sim(2.0)
	game.mode = WoollyGame.Mode.LOST
	var tap_ad := game.continue_with_ad
	for _i in 3:
		tap_ad.call()   # three quick taps, not awaited
	_check("second tap sees the ad as busy", Horus.ads.busy())
	await get_tree().create_timer(5.0).timeout   # the simulated ad's reward button opens after 3 s
	_check("extra road ad resumed play once", game.mode == WoollyGame.Mode.PLAY and game.cap_now() <= int(Levels.get_level(1).cap) + 1, "cap_now=%d" % game.cap_now())

	# the save survives a reload
	main.store.flush()
	var again: Dictionary = main.store.load()
	_check("save reloads coins, unlock, purchases", int(again.coins) == int(main.S.coins) and int(again.unlocked) == int(main.S.unlocked) and again.buys.size() == main.S.buys.size())


func _slots_ok() -> bool:
	var L: float = game._lay.track.length
	var gap: float = L / game.cap_now()
	var on: Array = game._road.filter(func(s): return s.state == Sheep.State.TRACK)
	var seen := {}
	for s in on:
		if s.slot < 0 or seen.has(s.slot) or absf(game._arc(s.s, game._slot_s(s.slot))) > 0.05:
			return false
		seen[s.slot] = true
	for a in on:
		for b in on:
			if a != b:
				var d: float = fposmod(b.s - a.s, L) / gap
				if absf(d - roundf(d)) > 0.02:
					return false
	return on.size() >= 2


func _slot_info() -> String:
	return "cap=%d road=%s" % [game.cap_now(), str(game._road.map(func(s): return "%d:%d@%.2f" % [s.state, s.slot, s.s]))]


func _wait(sec: float) -> void:
	game.paused_by_app = false
	await get_tree().create_timer(sec).timeout


## A real tap (press + release) at a viewport position, through the GUI like a finger.
func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e, true)
		await get_tree().process_frame
	await get_tree().create_timer(0.08).timeout


## Two sheep closer than a body (one of them on the move: joining, on the road or walking into a pen)?
func _overlap() -> String:
	const MOVING := [Sheep.State.JOINING, Sheep.State.MERGE, Sheep.State.TRACK, Sheep.State.ENTERING]
	var all: Array = game._sheep.filter(func(s): return is_instance_valid(s) and s.visible and not s.hold)
	for i in all.size():
		var a: Sheep = all[i]
		for j in range(i + 1, all.size()):
			var b: Sheep = all[j]
			if not (a.state in MOVING or b.state in MOVING):
				continue
			var d := Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length()
			if d < 0.7:
				return "states %d/%d slots %d/%d d=%.2f pos %s / %s s %.2f/%.2f ms %.2f/%.2f" % [a.state, b.state, a.slot, b.slot, d, a.position, b.position, a.s, b.s, a.merge_s, b.merge_s]
	return ""


## Tap the button whose label reads `text` inside `root`.
func _tap_key(root: Control, text: String) -> void:
	var l := _find_label(root, text)
	if l != null:
		await _tap(l.get_global_rect().get_center())


func _find_label(root: Node, text: String) -> Label:
	for n in root.find_children("*", "Label", true, false):
		if (n as Label).text == text and (n as Label).is_visible_in_tree():
			return n
	return null


## Real-time wait until cond() is true (or max_sec passes).
func _until(cond: Callable, max_sec: float) -> void:
	game.paused_by_app = false
	var t := 0.0
	while t < max_sec and not cond.call():
		await get_tree().create_timer(0.1).timeout
		t += 0.1


## The UX flow (docs/UX_FLOW.md): no popup is a dead end, and the main edges go where the table says.
func _flow_tests() -> void:
	var S: Dictionary = main.S
	S.coins = 1000
	main.S.rated = true
	game.go_home()
	await _wait(0.3)

	# cheat door with real taps: 10 taps on "Version" (Settings on Home, Pause in a level), 0312 on the keypad,
	# then coins typed on the keypad + ADD. Also a wrong code does not open it.
	for where in ["settings", "pause"]:
		hud.hide_panels()
		if where == "pause":
			game.load_level(1, false)
			await _wait(0.3)
		var host: Control = hud._settings if where == "settings" else hud._pause
		hud._show(host)
		await _wait(0.5)
		var ver := _find_label(host, Hud.VERSION)
		var at := ver.get_global_rect().get_center() + Vector2(0, 14) if ver != null else Vector2(-1, -1)   # a finger a bit low
		for _i in 10:
			await _tap(at)
			await get_tree().create_timer(0.4).timeout   # slow taps still count
		_check("cheat (%s): 10 taps on Version open the password box" % where, hud.is_open(hud._cheat_pass), "version label at %s" % at)
		for k in "1111":
			await _tap_key(hud._cheat_pass, k)
		_check("cheat (%s): a wrong code keeps it shut" % where, hud.is_open(hud._cheat_pass) and not hud.is_open(hud._cheat))
		for k in "0312":
			await _tap_key(hud._cheat_pass, k)
		_check("cheat (%s): 0312 on the keypad opens the cheats" % where, hud.is_open(hud._cheat))
		var coins0 := int(S.coins)
		for k in "500":
			await _tap_key(hud._cheat, k)
		await _tap_key(hud._cheat, "ADD")
		_check("cheat (%s): typed 500 coins are added" % where, int(S.coins) == coins0 + 500, "%d -> %d" % [coins0, S.coins])
		hud.hide_panels()
	game.go_home()
	await _wait(0.3)

	# every overlay has a way out (its X / Android back)
	var stuck := []
	var count := 0
	for o in hud.get_children():
		if not (o is ColorRect and o.has_meta("back")) or o == hud._ads_break:
			continue   # Ads break closes itself when the interstitial ends
		count += 1
		game.go_home()
		hud.hide_panels()
		if o == hud._win or o == hud._lose or o == hud._pre_lose:
			game.load_level(1, false)
			await _wait(0.3)
		hud._show(o)
		await _wait(0.05)
		hud.handle_back()
		await _wait(1.0)   # a scene change runs under the curtain for ~0.8 s
		if o.visible:
			stuck.append(o.name)
		if hud.is_open(hud._lose):   # pre-lose X leads to Level failed, whose back goes Home
			hud.handle_back()
			await _wait(1.0)
	_check("all %d popups close with back (no dead end)" % count, stuck.is_empty(), str(stuck))
	hud.hide_panels()

	# out of hearts on Level failed (real taps): RETRY opens Refill Lives, closing it comes back to Level failed,
	# and its HOME button gets the player out (it used to loop RETRY -> Refill -> Level failed)
	game.load_level(7, false)
	await _wait(0.3)
	S.lives = 0
	S.lives_t = Time.get_unix_time_from_system()
	game.force_lose("empty")
	await _wait(1.4)
	_check("Level failed shows HOME and RETRY", hud.is_open(hud._lose) and _find_label(hud._lose, "HOME") != null and _find_label(hud._lose, "RETRY") != null)
	await _tap_key(hud._lose, "RETRY")
	await _wait(0.3)
	_check("no hearts: RETRY opens Refill Lives", hud.is_open(hud._refill))
	hud.handle_back()
	await _wait(0.3)
	_check("closing Refill Lives comes back to Level failed", hud.is_open(hud._lose) and hud._lose.visible)
	await _tap_key(hud._lose, "HOME")
	await _wait(1.2)
	_check("HOME on Level failed goes Home with nothing left open", game.mode == WoollyGame.Mode.MENU and hud.top_overlay() == null and hud._home.visible, "mode %d top %s" % [game.mode, hud.top_overlay()])
	S.lives = Meta.MAX_LIVES
	hud.hide_panels()

	# PLAY without hearts -> Refill Lives -> refill with coins -> the level starts
	game.go_home()
	S.lives = 0
	S.lives_t = Time.get_unix_time_from_system()
	hud.play_pressed.emit()
	_check("PLAY with 0 hearts opens Refill Lives", hud.is_open(hud._refill) and main._pending_level == int(S.unlocked))
	hud.refill_coins.emit()
	await _wait(0.7)
	_check("refill fills hearts and starts the waiting level", int(S.lives) == Meta.MAX_LIVES and not hud.is_open(hud._refill) and game.mode != WoollyGame.Mode.MENU)

	# Pause > HOME > QUIT costs a heart and goes home
	hud._show(hud._pause)
	hud._show(hud._quit_confirm)
	hud.quit_level.emit()
	await _wait(0.7)
	_check("quit costs 1 heart and returns Home", int(S.lives) == Meta.MAX_LIVES - 1 and game.mode == WoollyGame.Mode.MENU and hud._home.visible)

	# Pause > RESTART > RETRY costs a heart and restarts; with the last heart -> Refill Lives at Home
	game.load_level(0)
	await _wait(0.3)
	hud.restart_level.emit()
	await _wait(0.7)
	_check("restart costs 1 heart and restarts the level", int(S.lives) == Meta.MAX_LIVES - 2 and game.level_index == 0 and game.mode != WoollyGame.Mode.MENU)
	S.lives = 1
	hud.restart_level.emit()
	await _wait(0.3)
	_check("restart with the last heart opens Refill Lives over Home", int(S.lives) == 0 and hud.is_open(hud._refill) and game.mode == WoollyGame.Mode.MENU)
	hud.handle_back()
	_check("closing Refill Lives forgets the waiting level", main._pending_level == -1 and not hud.is_open(hud._refill))
	Meta.add_lives(S, 5, 0.0)

	# booster out of stock -> Buy more booster -> not enough coins -> Shop -> back -> back
	game.load_level(3, false)
	await _wait(0.4)
	S.slot = 0
	S.coins = 0
	game.use_booster("slot")
	_check("empty booster opens Buy more booster", hud.is_open(hud._boost_offer))
	hud.booster_coins.emit("slot")
	_check("not enough coins opens the Shop on top", hud.shop_open() and hud.top_overlay() == hud._shop)
	hud.handle_back()
	_check("closing the Shop returns to the offer", hud.top_overlay() == hud._boost_offer)
	S.coins = 100
	hud.booster_coins.emit("slot")
	_check("buying with coins closes the offer and adds the booster", int(S.slot) == 1 and not hud.is_open(hud._boost_offer))
	hud.hide_panels()

	# locked booster: a toast, no offer
	game.load_level(1, false)
	await _wait(0.4)
	S.slot = 0
	game.use_booster("slot")
	_check("locked booster does not open an offer", not hud.is_open(hud._boost_offer))

	# Daily Gift
	S.daily = Horus.liveops.create_calendar()
	main._refresh_meta()
	S.coins = 0
	hud._open_daily()
	hud.daily_claim.emit()
	await _wait(1.0)
	_check("daily gift day 1 gives 30 coins once", int(S.coins) == 30 and not main._daily_info().claimable and not hud.daily_open())

	# Profile > Change name (bad, then good) > notify > SAVE; locked frame for coins
	hud.show_profile()
	hud._open_rename()
	hud._rename_edit.text = "ab"
	hud._rename_ok()
	_check("bad nickname keeps Change name open with an error", hud.is_open(hud._rename) and hud._rename_err.text != "")
	hud._rename_edit.text = "Woolly_1"
	hud._rename_ok()
	_check("good nickname shows the success popup", hud.is_open(hud._renamed) and not hud.is_open(hud._rename))
	hud.handle_back()
	_check("success popup returns to Profile", hud.top_overlay() == hud._profile)
	S.coins = 500
	hud._prof_tab(1)
	hud._prof_pick(4)
	_check("locked frame bought for 100 coins", 4 in S.frames and int(S.coins) == 400)
	hud.profile_save.emit(hud._prof.name, hud._prof.avatar, int(hud._prof.frame))
	_check("profile saved", str(S.name) == "Woolly_1" and int(S.frame) == 4)
	hud.hide_panels()

	# Language
	hud.lang_pick.emit("vi")
	_check("Vietnamese switches the UI text", tr("PLAY") == "CHƠI")
	hud.lang_pick.emit("en")
	_check("English back", tr("PLAY") == "PLAY")

	# New booster unlocked screen (first time on level 2)
	S.seen_unlock = []
	game.load_level(1)
	await _wait(0.3)
	_check("level 2 shows New booster unlocked first", hud.is_open(hud._unlock) and game.mode == WoollyGame.Mode.INTRO)
	hud.handle_back()
	await _wait(1.8)
	_check("Continue starts the level and remembers it", game.mode == WoollyGame.Mode.PLAY and "undo" in S.seen_unlock)
	S.seen_unlock = Meta.BOOSTERS.duplicate()

	# Win level 3 -> Rate us -> next level ; win the last level -> Home
	S.rated = false
	game.load_level(2, false)
	await _wait(0.3)
	game.force_win()
	game.next_level()
	_check("first win of level 3 asks Rate us", hud.is_open(hud._rate))
	hud.handle_back()
	await _wait(0.8)
	_check("after Rate us the next level loads", bool(S.rated) and game.level_index == 3 and game.mode != WoollyGame.Mode.MENU)
	game.load_level(Levels.count() - 1, false)
	await _wait(0.3)
	game.force_win()
	game.next_level()
	await _wait(0.8)
	_check("winning the last level returns Home", game.mode == WoollyGame.Mode.MENU)


func _capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var shots := []
	var shot := func(name: String):
		print("shot ", name)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join(name + ".png"))
		shots.append(name)
	var S: Dictionary = main.S
	var pop := func(o: Control, name: String):   # open over a clean screen, let the pop animation finish
		hud._show(o)
		await _wait(0.45)
		await shot.call(name)
		hud._hide(o)
	S.coins = 1250
	S.lives = 3
	S.lives_t = Time.get_unix_time_from_system() - 300
	S.daily = Horus.liveops.create_calendar()
	S.daily.day = 2
	main._refresh_meta()
	hud.show_splash()
	await _wait(0.6)
	await shot.call("S01_loading")
	hud.hide_splash()
	game.go_home()
	await _wait(1.2)
	hud.hide_panels()   # the boot Daily Gift
	await _wait(0.3)
	await shot.call("S02_home")
	hud._open_daily()
	await _wait(0.45)
	await shot.call("S03_daily_gift")
	hud.hide_panels()
	hud.show_profile()
	await _wait(0.45)
	await shot.call("S04_profile")
	hud._prof_tab(1)
	await _wait(0.1)
	await shot.call("S04b_profile_frames")
	hud._prof_tab(0)
	hud._open_rename()
	await _wait(0.45)
	await shot.call("S05_change_name")
	hud._rename_edit.text = "Woolly_1"
	hud._rename_ok()
	await _wait(0.45)
	await shot.call("S06_name_changed")
	hud.hide_panels()
	await pop.call(hud._settings, "S07_settings")
	await pop.call(hud._cheat_pass, "C01_cheat_password")
	await pop.call(hud._cheat, "C02_cheat")
	await pop.call(hud._language, "S08_language")
	await pop.call(hud._privacy, "S09_privacy")
	hud.show_refill(100)
	await _wait(0.45)
	await shot.call("S10_refill_lives")
	hud.hide_panels()
	await pop.call(hud._full_heart, "S11_full_heart")
	await pop.call(hud._starter, "S12_starter_pack")
	await pop.call(hud._no_ads, "S13_no_ads")
	hud.show_shop(true)
	await _wait(0.45)
	await shot.call("S14_shop")
	hud._shop_scroll.scroll_vertical = 1200
	await _wait(0.2)
	await shot.call("S14b_shop_bottom")
	hud.hide_panels()
	await pop.call(hud._levels, "S15_levels")
	S.unlocked = 49
	hud._refresh_levels(49)
	hud._show(hud._levels)
	await _wait(0.45)
	await shot.call("S15b_levels_50")
	hud._hide(hud._levels)
	S.unlocked = 4
	hud._refresh_levels(4)
	hud._curtain.visible = true
	hud._curtain.modulate.a = 1.0
	await _wait(0.1)
	await shot.call("S16_loading_between")
	hud._curtain.visible = false
	# level 1 coach (reference tutorial): send -> parks in its pen -> pushed-out sheep joins the road
	game.load_level(0)
	await _wait(2.2)
	await shot.call("T01_tut_send")
	game.send(game.TUT_COL)
	await _until(func(): return hud.is_open(hud._coach), 10.0)
	await _wait(0.4)
	await shot.call("T02_tut_pen")
	hud._coach_next()
	await _until(func(): return hud.is_open(hud._coach), 5.0)
	await _wait(0.4)
	await shot.call("T03_tut_push")
	hud._coach_next()
	S.seen_unlock = []
	game.load_level(1)
	await _wait(0.5)
	await shot.call("S18_unlock_booster")
	hud.handle_back()
	await _wait(0.5)
	await shot.call("S19_booster_tip")
	S.seen_unlock = Meta.BOOSTERS.duplicate()
	game.load_level(4)
	await _wait(0.5)
	await shot.call("S20_hard_level")
	await _wait(2.2)
	await shot.call("S17b_gameplay_5_deep")      # 5-deep queues: the camera shows the first 3 rows
	game.send(0)
	await _wait(1.2)
	await shot.call("S17c_gameplay_push_up")     # column 1 moved up one place
	# rapid taps like the reference video: five sheep on their way at once, then the full road
	game.load_level(9, false)
	await _wait(0.6)
	for c in [0, 1, 0, 2, 1]:
		game.send(c)
		await _wait(0.12)
	await _wait(0.2)
	await shot.call("S17d_rapid_taps")
	await _wait(1.6)
	game.send(2)   # turned away: the sheep shakes its head, the sign jolts, the kerbs flash red
	await _wait(0.08)
	await shot.call("S17e_road_full")
	game.load_level(2)
	await _wait(2.0)
	game.send(0)
	await _wait(0.6)
	game.send(1)
	await _wait(2.5)
	await shot.call("S17_gameplay")
	await pop.call(hud._pause, "S21_pause")
	await pop.call(hud._quit_confirm, "S22_quit")
	await pop.call(hud._restart_confirm, "S23_restart")
	hud.show_booster_offer("slot", 60, true)
	await _wait(0.45)
	await shot.call("S24_buy_booster")
	hud.hide_panels()
	game.load_level(1, false)
	await _wait(0.5)
	game.mode = WoollyGame.Mode.PLAY
	game.force_lose("full")
	await _wait(1.8)
	await shot.call("S25_keep_playing")
	hud.hide_panels()
	hud.show_lose("The road is full and no sheep can find a pen.")
	await _wait(0.6)
	await shot.call("S26_level_failed")
	hud.hide_panels()
	game.load_level(2, false)
	await _wait(0.5)
	game.force_win()
	await _wait(3.2)
	await shot.call("S27_win")
	hud.hide_panels()
	await pop.call(hud._ads_break, "S28_ads_break")
	hud.show_rate()
	await _wait(0.45)
	await shot.call("S29_rate_us")
	hud.hide_panels()
	main.hud.lang_pick.emit("vi")
	game.go_home()
	await _wait(0.9)
	await shot.call("V02_home_vi")
	await pop.call(hud._settings, "V07_settings_vi")
	hud.show_refill(100)
	await _wait(0.45)
	await shot.call("V10_refill_vi")
	hud.hide_panels()
	main.hud.lang_pick.emit("en")
	_check("captured %d screens" % shots.size(), shots.size() >= 30)


## What is just ahead of a road sheep (for failure messages).
func _ahead_info(sh: Sheep) -> String:
	var L: float = game._lay.track.length
	var out := ""
	var best := INF
	for o in game._road:
		if o == sh:
			continue
		var at: float = o.s if o.state == Sheep.State.TRACK else (o.merge_s if o.committed else INF)
		if at == INF:
			continue
		var g := fposmod(at - sh.s, L)
		if g < best:
			best = g
			out = "ahead: state %d committed %s gap %.2f slot %d/%d err %.2f" % [o.state, o.committed, g, o.slot, sh.slot, game._arc(sh.s, game._slot_s(sh.slot)) if sh.slot >= 0 else 0.0]
	return out
