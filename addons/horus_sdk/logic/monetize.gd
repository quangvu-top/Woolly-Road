# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const _SELF = preload("monetize.gd")
const JS_VERSION := "1.1.0"
const INTER_DEFAULTS := {
	"interOnX2Skip": 1,
	"interFromRun": 4,
	"interEvery": 2,
	"interCooldown": 120,
	"sessionWarmup": 90,
	"rewardedGrace": 45,
	"rvWaitMs": 3000,
}
const SHORT_DEFAULTS := {"afterBuys": 1, "freeAds": 1, "gemStep": 1, "adsForGems": 1, "maxSteps": 0, "pin": 1, "fromRun": 2}
const _H := 3600000.0
const _PAIRS := "([A-Za-z0-9_]+):([^\\n\\r\\x{2028}\\x{2029}]*?)(?=,[A-Za-z0-9_]+:|\\z)"
static func parse_pairs(q = null) -> Array:
	var out := []
	for m in _re(_PAIRS).search_all(_str(q) if _truthy(q) else ""):
		out.append([m.get_string(1), m.get_string(2)])
	return out
static func apply_config(groups: Dictionary, rc = {}, query = null, o: Dictionary = {}) -> Array:
	var set := []
	var all: Array = _or(o.get("all"), [])
	var mn = o.get("min")
	var put := func(g, k, v) -> void:
		if _set_key(groups[g], k, v, mn):
			set.append([g, k, groups[g][k]])
	if rc is Dictionary:
		for key in rc:
			var ks := _str(key)
			var i := ks.find("_")
			if i <= 0:
				continue
			var g := ks.substr(0, i)
			if _truthy(groups.get(g)):
				put.call(g, ks.substr(i + 1), rc[key])
	for g in groups.keys():
		var s = _query_get(query, g)
		if not _truthy(s):
			continue
		if _includes(all, g) and _eq(s, "all"):
			for k in groups[g].keys():
				put.call(g, k, 1)
			continue
		for pair in parse_pairs(s):
			put.call(g, _trim(pair[0]), pair[1])
	return set
static func _set_key(o, k, v, mn) -> bool:
	if not (o is Dictionary) or not o.has(k) or _eq(v, "") or v == null:
		return false
	var d = o[k]
	match typeof(d):
		TYPE_INT, TYPE_FLOAT:
			var n := _num(v)
			if not is_finite(n) or (mn != null and n < _num(mn)):
				return false
			o[k] = _n(n)
			return true
		TYPE_BOOL:
			var s := _str(v).to_lower()
			if s == "1" or s == "true":
				o[k] = true
			elif s == "0" or s == "false":
				o[k] = false
			else:
				return false
			return true
		TYPE_STRING, TYPE_STRING_NAME:
			o[k] = _str(v)
			return true
	return false
static func _query_get(query, name: String):
	if query == null:
		return null
	if query is Dictionary:
		return query.get(name)
	if query is String:
		var q: String = query.trim_prefix("?")
		for part in q.split("&", false):
			var eq := part.find("=")
			var k := part if eq < 0 else part.substr(0, eq)
			if k.replace("+", " ").uri_decode() == name:
				return "" if eq < 0 else part.substr(eq + 1).replace("+", " ").uri_decode()
		return null
	if query is Object:
		return query.get(name)
	return null
static func pacing_state() -> Dictionary:
	return {"inter": 0, "interRun": 0, "lastInter": 0, "lastRewarded": 0, "watched": 0}
static func inter_due(state, rules, ctx: Dictionary) -> Dictionary:
	var R := INTER_DEFAULTS.duplicate()
	if rules is Dictionary:
		R.merge(rules, true)
	var t := _num(ctx.get("now"))
	var A: Dictionary = state if state is Dictionary else {}
	var cool := _num(_qq(ctx.get("cooldown"), R.get("interCooldown")))
	var warm := _num(_qq(ctx.get("warmup"), R.get("sessionWarmup")))
	var runs := _num(ctx.get("runs"))
	var why := ""
	if _truthy(ctx.get("noAds")):
		why = "no_ads"
	elif _truthy(ctx.get("block")):
		why = "blocked"
	elif _truthy(R.get("interOnX2Skip")) and not _truthy(ctx.get("x2Skipped")):
		why = "x2_taken"
	elif runs < _num(R.get("interFromRun")):
		why = "early"
	elif runs - _f0(A.get("interRun")) < _num(R.get("interEvery")):
		why = "every"
	elif not (_num(ctx.get("sinceStart")) >= warm):
		why = "warmup"
	elif not (t - _f0(A.get("lastInter")) > cool * 1000.0):
		why = "cooldown"
	elif not (t - _f0(A.get("lastRewarded")) > _num(R.get("rewardedGrace")) * 1000.0):
		why = "rewarded"
	return {"due": why == "", "why": why}
static func note_inter(state: Dictionary, runs = null, now = null) -> void:
	state["lastInter"] = now
	state["interRun"] = runs
	state["inter"] = _n(_f0(state.get("inter")) + 1.0)
static func note_rewarded(state: Dictionary, now = null) -> void:
	state["lastRewarded"] = now
	state["watched"] = _n(_f0(state.get("watched")) + 1.0)
static func wait_rewarded(ads = null, o: Dictionary = {}) -> String:
	var wait_ms := _num(_qq(o.get("waitMs"), INTER_DEFAULTS.rvWaitMs))
	var poll := _num(_qq(o.get("poll"), 100))
	var gone: Callable = _qq(o.get("gone"), func(): return false)
	var clock: Callable = _qq(o.get("clock"), func(): return Time.get_ticks_msec())
	if _ads_ready(ads):
		return "ready"
	if not (wait_ms > 0):
		return "timeout"
	var load_fn := _fn(ads, "load")
	if load_fn.is_valid():
		_inv(load_fn, ["rv"])
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "timeout"
	var t0 := _num(clock.call())
	while true:
		await tree.create_timer(maxf(0.0, poll) / 1000.0).timeout
		var r := _ads_ready(ads)
		var g := _truthy(gone.call())
		if not r and not g and _num(clock.call()) - t0 < wait_ms:
			continue
		return "gone" if g else ("ready" if r else "timeout")
	return "timeout"
static func _ads_ready(ads) -> bool:
	var f := _fn(ads, "ready")
	if not f.is_valid():
		return false
	return _truthy(_prop(f.call(), "rv"))
static func short_step(n = null, cfg = null) -> Dictionary:
	var c := SHORT_DEFAULTS.duplicate()
	if cfg is Dictionary:
		c.merge(cfg, true)
	var x := _num(n)
	if x <= 0:
		return {"gems": 0, "ads": _n(_max(1.0, _num(c.get("freeAds"))))}
	return {"gems": _n(x * _num(c.get("gemStep"))), "ads": _n(x * _num(c.get("gemStep"))) if _truthy(c.get("adsForGems")) else 0}
static func create_short_ladder(cfg = null) -> ShortLadder:
	var l := ShortLadder.new()
	l.cfg = cfg if cfg is Dictionary else SHORT_DEFAULTS
	return l
class ShortLadder extends RefCounted:
	var cfg = {}
	var state := {"buys": 0, "step": 0, "prog": 0, "first": null}
	func _c() -> Dictionary:
		var c: Dictionary = SHORT_DEFAULTS.duplicate()
		if cfg is Dictionary:
			c.merge(cfg, true)
		return c
	func reset() -> void:
		state.buys = 0
		state.step = 0
		state.prog = 0
		state.first = null
	func view(runs = 0) -> Dictionary:
		var c := _c()
		var st: Dictionary = _SELF.short_step(state.step, c)
		var max_steps := _SELF._num(c.get("maxSteps"))
		var open: bool = _SELF._num(state.buys) >= _SELF._num(c.get("afterBuys")) \
				and _SELF._f0(runs) >= _SELF._f0(c.get("fromRun")) \
				and not (max_steps > 0 and _SELF._num(state.step) >= max_steps)
		return {"open": open, "step": state.step, "gems": st.gems, "ads": st.ads, "prog": state.prog}
	func pinned() -> bool:
		var c := _c()
		return _SELF._truthy(c.get("pin")) and (_SELF._truthy(state.first) or _SELF._num(c.get("afterBuys")) > 0)
	func focus(last_tapped, can_up: Callable = Callable()):
		var id = state.first if pinned() else last_tapped
		if _SELF._truthy(id) and (not can_up.is_valid() or _SELF._truthy(_SELF._inv(can_up, [id]))):
			return id
		return null
	func bought(id, how) -> void:
		if _SELF._eq(how, "coin"):
			state.buys = _SELF._n(_SELF._num(state.buys) + 1.0)
			if not _SELF._truthy(state.first):
				state.first = id
			return
		if _SELF._eq(how, "gem") or _SELF._eq(how, "ad"):
			state.step = _SELF._n(_SELF._num(state.step) + 1.0)
			state.prog = 0
			if not _SELF._truthy(state.first):
				state.first = id
	func ad_watched(runs = 0) -> Dictionary:
		var s := view(runs)
		state.prog = _SELF._n(_SELF._num(state.prog) + 1.0)
		return {"done": _SELF._num(state.prog) >= _SELF._num(s.ads), "prog": state.prog, "ads": s.ads}
static func offer_state(save: Dictionary) -> Dictionary:
	if not _truthy(save.get("offers")):
		save["offers"] = {}
	var o: Dictionary = save.offers
	if not _truthy(o.get("o")):
		o["o"] = {}
	if o.get("last") == null:
		o["last"] = -999
	return o
static func _one(st: Dictionary, id) -> Dictionary:
	var k = _key(id)
	if not _truthy(st.o.get(k)):
		st.o[k] = {"shown": 0, "at": 0, "until": 0, "bought": 0, "boughtAt": 0, "expired": 0, "day": "", "dayN": 0, "key": ""}
	return st.o[k]
static func is_open(st: Dictionary, def = null, now = null) -> bool:
	var o = st.o.get(_key(_prop(def, "id")))
	if not _truthy(o):
		return false
	if _truthy(_prop(def, "once")) and _truthy(o.get("bought")):
		return false
	return _num(o.get("until")) > _num(now)
static func open_offers(st: Dictionary, defs: Array, now = null) -> Array:
	var out := []
	for d in defs:
		if is_open(st, d, now):
			out.append({"id": _prop(d, "id"), "until": st.o[_key(_prop(d, "id"))].get("until")})
	return _sorted(out, func(a, b): return _num(a.until) - _num(b.until))
static func expired(st: Dictionary, defs: Array, now = null) -> Array:
	var out := []
	for d in defs:
		var o = st.o.get(_key(_prop(d, "id")))
		if not _truthy(o) or not _truthy(o.get("until")) or _num(o.get("until")) > _num(now) \
				or (_truthy(o.get("bought")) and _truthy(_prop(d, "once"))):
			continue
		if _eq(o.get("closedAt"), o.get("until")):
			continue
		o["closedAt"] = o.get("until")
		o["expired"] = _n(_num(o.get("expired")) + 1.0)
		out.append({"id": _prop(d, "id"), "shown": o.get("shown")})
	return out
static func due(st: Dictionary, defs: Array, cfg: Dictionary, ctx: Dictionary):
	if not _truthy(cfg.get("on")):
		return null
	if _num(_qq(ctx.get("playS1"), INF)) < _f0(cfg.get("minSecs")):
		return null
	if _num(ctx.get("runs")) - _num(st.get("last")) < _f0(cfg.get("gapRuns")):
		return null
	for d in defs:
		var on := _fn(d, "on")
		if on.is_valid() and not _truthy(_inv(on, [cfg])):
			continue
		var o := _one(st, _prop(d, "id"))
		if _truthy(_prop(d, "once")) and _truthy(o.get("bought")):
			continue
		if _num(o.get("until")) > _num(ctx.get("now")):
			continue
		var trig = _inv(_fn(d, "when"), [ctx, o, cfg])
		if _truthy(trig):
			return {"id": _prop(d, "id"), "trigger": trig}
	return null
static func shown(st: Dictionary, def, cfg: Dictionary, ctx: Dictionary):
	var o := _one(st, _prop(def, "id"))
	o["shown"] = _n(_num(o.get("shown")) + 1.0)
	o["at"] = ctx.get("now")
	st["last"] = ctx.get("runs")
	if not _eq(o.get("day"), ctx.get("day")):
		o["day"] = ctx.get("day")
		o["dayN"] = 0
	o["dayN"] = _n(_num(o.get("dayN")) + 1.0)
	var hours := _fn(def, "hours")
	var h := _num(_inv(hours, [cfg])) if hours.is_valid() else 0.0
	if h > 0 and not (_num(o.get("until")) > _num(ctx.get("now"))):
		o["until"] = _n(_num(ctx.get("now")) + h * _H)
	if ctx.get("key") != null:
		o["key"] = _str(ctx.get("key"))
	return o.get("shown")
static func bought(st: Dictionary, def, ctx: Dictionary) -> void:
	var o := _one(st, _prop(def, "id"))
	o["bought"] = _n(_num(o.get("bought")) + 1.0)
	o["boughtAt"] = ctx.get("now")
	if not _truthy(_prop(def, "once")):
		o["until"] = 0
static func offer_get(st: Dictionary, id = null) -> Dictionary:
	return _one(st, id)
static var _res := {}
static func _re(p: String) -> RegEx:
	if not _res.has(p):
		_res[p] = RegEx.create_from_string(p)
	return _res[p]
static func _truthy(v) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT:
			return v != 0
		TYPE_FLOAT:
			return v != 0.0 and not is_nan(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return not String(v).is_empty()
	return true
static func _or(a, b):
	return a if _truthy(a) else b
static func _qq(a, b):
	return b if a == null else a
static func _num(v) -> float:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			return float(v)
		TYPE_BOOL:
			return 1.0 if v else 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			return _str_to_num(String(v))
		TYPE_ARRAY:
			return _str_to_num(_str(v))
	return NAN
static func _f0(v) -> float:
	return _num(v) if _truthy(v) else 0.0
static func _str_to_num(s: String) -> float:
	s = _trim(s)
	if s.is_empty():
		return 0.0
	if _re("^[+-]?(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$").search(s):
		return s.to_float()
	if s == "Infinity" or s == "+Infinity":
		return INF
	if s == "-Infinity":
		return -INF
	var m := _re("^0([xX][0-9a-fA-F]+|[oO][0-7]+|[bB][01]+)$").search(s)
	if m:
		var base: float = {"x": 16.0, "o": 8.0, "b": 2.0}[s[1].to_lower()]
		var x := 0.0
		for ch in s.substr(2):
			x = x * base + float("0123456789abcdef".find(ch.to_lower()))
		return x
	return NAN
static func _trim(s: String) -> String:
	return _re("^[\\s\\x{a0}\\x{1680}\\x{2000}-\\x{200a}\\x{2028}\\x{2029}\\x{202f}\\x{205f}\\x{3000}\\x{feff}]+|[\\s\\x{a0}\\x{1680}\\x{2000}-\\x{200a}\\x{2028}\\x{2029}\\x{202f}\\x{205f}\\x{3000}\\x{feff}]+$").sub(s, "", true)
static func _n(x):
	if typeof(x) == TYPE_FLOAT and x == floorf(x) and absf(x) <= 9007199254740992.0:
		return int(x)
	return x
static func _str(v) -> String:
	match typeof(v):
		TYPE_NIL:
			return "undefined"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return _num_str(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v)
		TYPE_ARRAY:
			var parts := []
			for x in v:
				parts.append("" if x == null else _str(x))
			return ",".join(parts)
	return "[object Object]"
static func _add(a, b):
	var ta := typeof(a)
	var tb := typeof(b)
	for t in [ta, tb]:
		if t == TYPE_STRING or t == TYPE_STRING_NAME or t == TYPE_ARRAY or t == TYPE_DICTIONARY or t == TYPE_OBJECT:
			return _str(a) + _str(b)
	return _n(_num(a) + _num(b))
static func _num_str(x: float) -> String:
	if is_nan(x):
		return "NaN"
	if is_inf(x):
		return "Infinity" if x > 0 else "-Infinity"
	if x == 0.0:
		return "0"
	if x == floorf(x) and absf(x) < 9007199254740992.0:
		return str(int(x))
	var s := var_to_str(absf(x))
	var e := 0
	var i := s.find("e")
	if i >= 0:
		e = int(s.substr(i + 1))
		s = s.substr(0, i)
	var dot := s.find(".")
	var ip := s if dot < 0 else s.substr(0, dot)
	var digits := ip + ("" if dot < 0 else s.substr(dot + 1))
	var n := ip.length() + e
	var lead := 0
	while lead < digits.length() - 1 and digits[lead] == "0":
		lead += 1
	digits = digits.substr(lead)
	n -= lead
	while digits.length() > 1 and digits.ends_with("0"):
		digits = digits.substr(0, digits.length() - 1)
	var k := digits.length()
	var out := ""
	if k <= n and n <= 21:
		out = digits + "0".repeat(n - k)
	elif 0 < n and n <= 21:
		out = digits.substr(0, n) + "." + digits.substr(n)
	elif -6 < n and n <= 0:
		out = "0." + "0".repeat(-n) + digits
	else:
		out = digits[0] + ("." + digits.substr(1) if k > 1 else "") + "e" + ("+" if n - 1 >= 0 else "-") + str(absi(n - 1))
	return ("-" if x < 0 else "") + out
static func _to_fixed0(x: float) -> String:
	if is_nan(x):
		return "NaN"
	if absf(x) >= 1e21:
		return _num_str(x)
	var neg := x < 0
	var a := absf(x)
	var r := floorf(a)
	if a - r >= 0.5:
		r += 1.0
	return ("-" if neg else "") + _num_str(r)
static func _round(x: float) -> float:
	var r := floorf(x)
	return r + 1.0 if x - r >= 0.5 else r
static func _max(a: float, b: float) -> float:
	if is_nan(a) or is_nan(b):
		return NAN
	return a if a > b else b
static func _min(a: float, b: float) -> float:
	if is_nan(a) or is_nan(b):
		return NAN
	return a if a < b else b
static func _mod(a, b) -> float:
	return fmod(float(a), float(b))
static func _eq(a, b) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return a == b
	if (ta == TYPE_STRING or ta == TYPE_STRING_NAME) and (tb == TYPE_STRING or tb == TYPE_STRING_NAME):
		return String(a) == String(b)
	if ta != tb:
		return false
	if ta == TYPE_ARRAY or ta == TYPE_DICTIONARY or ta == TYPE_OBJECT:
		return is_same(a, b)
	return a == b
static func _index_of(arr: Array, v) -> int:
	for i in arr.size():
		if _eq(arr[i], v):
			return i
	return -1
static func _sorted(arr: Array, cmp: Callable) -> Array:
	var a := arr.duplicate()
	var n := a.size()
	if n < 2:
		return a
	var c := func(x, y) -> float:
		var v := float(cmp.call(x, y))
		return 0.0 if is_nan(v) else v
	if n < 64:
		var run := 2
		var desc: bool = c.call(a[1], a[0]) < 0.0
		while run < n:
			var o: float = c.call(a[run], a[run - 1])
			if (desc and o >= 0.0) or (not desc and o < 0.0):
				break
			run += 1
		if desc:
			var head := a.slice(0, run)
			head.reverse()
			for i in run:
				a[i] = head[i]
		for start in range(run, n):
			var left := 0
			var right := start
			var pivot = a[start]
			while left < right:
				var mid := left + ((right - left) >> 1)
				if c.call(pivot, a[mid]) < 0.0:
					right = mid
				else:
					left = mid + 1
			var p := start
			while p > left:
				a[p] = a[p - 1]
				p -= 1
			a[left] = pivot
		return a
	var b := a.duplicate()
	var width := 1
	while width < n:
		var i := 0
		while i < n:
			var mid := mini(i + width, n)
			var hi := mini(i + 2 * width, n)
			var l := i
			var r := mid
			var k := i
			while l < mid and r < hi:
				if c.call(a[r], a[l]) < 0.0:
					b[k] = a[r]
					r += 1
				else:
					b[k] = a[l]
					l += 1
				k += 1
			while l < mid:
				b[k] = a[l]
				l += 1
				k += 1
			while r < hi:
				b[k] = a[r]
				r += 1
				k += 1
			i += 2 * width
		var tmp := a
		a = b
		b = tmp
		width *= 2
	return a
static func _includes(arr: Array, v) -> bool:
	for x in arr:
		if _eq(x, v) or (typeof(x) == TYPE_FLOAT and typeof(v) == TYPE_FLOAT and is_nan(x) and is_nan(v)):
			return true
	return false
static func _is_fin(v) -> bool:
	return (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v))
static func _key(k):
	if typeof(k) == TYPE_STRING:
		return k
	return String(k) if typeof(k) == TYPE_STRING_NAME else _str(k)
static func _prop(o, k):
	if o is Dictionary:
		return o.get(k)
	if o is Object and o != null:
		return o.get(k)
	return null
static func _fn(o, k: String) -> Callable:
	if o is Dictionary:
		var f = o.get(k)
		return f if f is Callable else Callable()
	if o is Object and o != null and o.has_method(k):
		return Callable(o, k)
	return Callable()
static func _slice16(s: String, n: int) -> String:
	var units := 0
	for i in s.length():
		units += 2 if s.unicode_at(i) > 0xFFFF else 1
		if units > n:
			return s.substr(0, i)
	return s
static func _inv(f: Callable, args: Array = []):
	var n := f.get_argument_count()
	return f.callv(args.slice(0, n) if args.size() > n else args)
