class_name Meta
extends RefCounted
## Meta-game rules with no UI (unit-tested in tests/run_tests.gd):
##   lives  : 5 hearts, one comes back every `minutes`; a lost or abandoned level costs one
##   boosters: unlocked one by one (Bus Dash "New booster unlocked!" screen)
##   daily gift: a 5-day cycle on top of Horus.liveops calendar (claim once per local day)
##   profile: nickname rules from the Figma "Change name" popup

const MAX_LIVES := 5
## Level index where each booster unlocks (level 1 is the tutorial).
const UNLOCK := {"undo": 1, "slot": 2, "hint": 3}
const BOOSTERS := ["undo", "slot", "hint"]
## Daily gift cycle (Figma Daily Gift: 30 coins, booster, 150 coins, booster, 300 coins).
const DAILY := [{coins = 30}, {undo = 1}, {coins = 150}, {hint = 1}, {coins = 300}]
const AVATARS := ["W", "P", "B", "Y", "L", "O"]
const FRAMES := [Color("#16acfb"), Color("#ff5d8f"), Color("#7be36a"), Color("#ffd23a"), Color("#b98cff"), Color("#ff9e3d")]
const FREE_FRAMES := 3
const FRAME_PRICE := 100


## Give back the lives earned since `lives_t` (seconds). Keeps the remainder of a partial period.
static func regen(s: Dictionary, now: float, minutes: float) -> void:
	var period := maxf(1.0, minutes * 60.0)
	var lives := int(s.get("lives", MAX_LIVES))
	if lives >= MAX_LIVES:
		s.lives = MAX_LIVES
		s.lives_t = now
		return
	var t0 := float(s.get("lives_t", now))
	if t0 > now:   # clock went backwards: restart the period instead of granting nothing forever
		t0 = now
	var gained := int(floor((now - t0) / period))
	if gained > 0:
		lives = mini(MAX_LIVES, lives + gained)
		t0 += gained * period
	s.lives = lives
	s.lives_t = now if lives >= MAX_LIVES else t0


## Seconds until the next heart (0 when full).
static func next_life_in(s: Dictionary, now: float, minutes: float) -> float:
	if int(s.get("lives", MAX_LIVES)) >= MAX_LIVES:
		return 0.0
	var period := maxf(1.0, minutes * 60.0)
	return maxf(0.0, period - (now - float(s.get("lives_t", now))))


static func lose_life(s: Dictionary, now: float) -> void:
	var lives := int(s.get("lives", MAX_LIVES))
	if lives >= MAX_LIVES:
		s.lives_t = now   # the refill clock starts when the first heart goes
	s.lives = maxi(0, lives - 1)


static func add_lives(s: Dictionary, n: int, now: float) -> void:
	s.lives = mini(MAX_LIVES, int(s.get("lives", MAX_LIVES)) + n)
	if int(s.lives) >= MAX_LIVES:
		s.lives_t = now


static func fmt_time(sec: float) -> String:
	var t := int(ceil(sec))
	return "%02d:%02d" % [t / 60, t % 60]


static func unlocked(kind: String, level_index: int) -> bool:
	return level_index >= int(UNLOCK.get(kind, 0))


## The booster that unlocks on this level ("" when none).
static func unlock_on(level_index: int) -> String:
	for k in BOOSTERS:
		if int(UNLOCK[k]) == level_index:
			return k
	return ""


## Nickname: 3-14 characters, English letters, digits, _ . - only (Figma "Change name").
static func valid_name(n: String) -> bool:
	if n.length() < 3 or n.length() > 14:
		return false
	for ch in n:
		var c := ch.unicode_at(0)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or ch in ["_", ".", "-"]
		if not ok:
			return false
	return true


static func default_name() -> String:
	return "Shepherd%04d" % (randi() % 10000)


## Apply a daily reward to the save. Returns the coins it gave (for analytics).
static func give_daily(s: Dictionary, reward: Dictionary) -> int:
	var coins := 0
	for k in reward:
		s[k] = int(s.get(k, 0)) + int(reward[k])
		if k == "coins":
			coins += int(reward[k])
	return coins
