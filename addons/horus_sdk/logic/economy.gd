# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const JS_VERSION := "1.0.0"
const ROUNDING := {
	"shop": [[100, 1], [1000, 5], [1e4, 50], [1e5, 500], [1e6, 5000], [INF, 50000]],
	"even": [[1000, "floor-even"], [1e4, 50], [1e5, 500], [INF, 5000]],
}
const PROFILES := ["noads", "some", "ads"]
static func round_price(c = null, table = null):
	if table == null:
		table = ROUNDING.shop
	var x := _num(c)
	for row in table:
		if x >= _num(row[0]):
			continue
		var step = row[1]
		if _eq(step, "floor-even"):
			return _n(floorf(x / 2.0 + 1e-9) * 2.0)
		return _n(_round(x / _num(step)) * _num(step))
	return _n(_round(x))
static func price_curve(o: Dictionary) -> Callable:
	var base := _num(o.get("base"))
	var growth := _num(o.get("growth"))
	var r = o.get("round")
	if r is Callable:
		return func(lvl): return _inv(r, [base * _pow(growth, _num(lvl))])
	var table = ROUNDING.shop if r == null else r
	return func(lvl): return round_price(base * _pow(growth, _num(lvl)), table)
static func growth_for(from = null, to = null, levels = null) -> float:
	return _pow(_num(to) / _num(from), 1.0 / _num(levels))
static func best_buy(cands: Array, o: Dictionary = {}):
	var coins = _qq(o.get("coins"), INF)
	var any = _qq(o.get("any"), false)
	var order: Array = _qq(o.get("order"), [])
	var key: Callable = _qq(o.get("key"), func(c): return c.get("lv"))
	var big_gain = _qq(o.get("bigGain"), 25)
	var ok := []
	for c in cands:
		if _truthy(any) or _num(c.get("cost")) <= _num(coins):
			ok.append(c)
	if ok.is_empty():
		return null
	var hills := []
	for c in ok:
		var p = _or(c.get("pred"), "")
		if typeof(p) == TYPE_STRING or typeof(p) == TYPE_STRING_NAME:
			p = String(p)
			if p == "hill" or (p.begins_with("+") and _str_to_num(p.substr(1)) >= _num(big_gain)):
				hills.append(c)
	if not hills.is_empty():
		return _sorted(hills, func(a, b): return _num(a.get("cost")) - _num(b.get("cost")))[0]
	var rank := func(id) -> float:
		var i := _index_of(order, id)
		return float(order.size()) if i < 0 else float(i)
	var by_key := func(a, b) -> float:
		var d := _num(_inv(key, [a])) - _num(_inv(key, [b]))
		return d if _truthy(d) else rank.call(a.get("id")) - rank.call(b.get("id"))
	return _sorted(ok, by_key)[0]
static func simulate_economy(o: Dictionary) -> Dictionary:
	var out := {}
	for p in _or(o.get("profiles"), PROFILES):
		out[p] = play_profile(o, p)
	return out
static func play_profile(o: Dictionary, profile = null) -> Dictionary:
	var T := {"ad": 5, "inter": 4, "between": 12, "runCap": 100}
	var time = o.get("time")
	if time is Dictionary:
		T.merge(time, true)
	var upgrades: Array = o.get("upgrades", [])
	var max_fn: Callable = o.get("max") if _truthy(o.get("max")) else func(_id, _map): return INF
	var clear_gems: Callable = o.get("clearGems") if _truthy(o.get("clearGems")) else func(_map): return 0
	var max_runs := _num(_qq(o.get("maxRuns"), 80))
	var ladder = o.get("ladder") if _truthy(o.get("ladder")) else null
	var inter = o.get("inter") if _truthy(o.get("inter")) else null
	var boost = o.get("boost") if _truthy(o.get("boost")) else null
	var boosted: Callable = o.get("boosted") if _truthy(o.get("boosted")) else func(u, k, _map):
		var x: Dictionary = u.duplicate()
		for id in upgrades:
			x[id] = _n(_f0(x.get(id)) + _num(k))
		return x
	var run: Callable = o.get("run")
	var pay_fn: Callable = o.get("pay")
	var pick: Callable = o.get("pick")
	var length = o.get("length")
	var start = o.get("start") if o.get("start") is Dictionary else {}
	var coins := _num(_qq(start.get("coins"), 0))
	var gems := _num(_qq(start.get("gems"), 0))
	var g_runs := 0
	var rv := 0.0
	var inters := 0
	var gem_ups := 0
	var ad_ups := 0
	var boost_runs := 0
	var seed := [1]
	var rnd := func() -> float:
		seed[0] = (seed[0] * 16807) % 2147483647
		return seed[0] / 2147483647.0
	var half := func() -> bool: return _eq(profile, "ads") or (_eq(profile, "some") and rnd.call() < 0.5)
	var maps := []
	var li := 0
	while li < _num(o.get("maps")):
		var upg := {}
		for id in upgrades:
			upg[id] = 0
		var best := 0.0
		var runs := 0
		var dry := 0
		var t := 0.0
		var ds := []
		var per := []
		var fmt := func() -> String:
			var parts := []
			for id in upgrades:
				var v = upg.get(id)
				parts.append("" if v == null else _str(v))
			return "/".join(parts)
		while true:
			var r: Dictionary
			if boost != null and g_runs + 1 > _num(boost.get("fromRun")) and half.call():
				var k = _inv(boost.pick, [rnd])
				r = _inv(run, [li, _inv(boosted, [upg, k, li]), {"runs": g_runs, "boost": k}])
				boost_runs += 1
				rv += 1
				t += _num(T.ad)
			else:
				r = _inv(run, [li, upg, {"runs": g_runs}])
			var len_ = _inv(length, [li]) if _truthy(length) else r.get("dist")
			var dist = len_ if _truthy(r.get("fin")) else r.get("dist")
			var rr := r.duplicate()
			rr["dist"] = dist
			var pay := _num(_inv(pay_fn, [li, rr, {"best": _n(best), "upg": upg}]))
			g_runs += 1
			runs += 1
			var m := 1
			if g_runs == 1:
				m = 2
			elif half.call():
				m = 2
				rv += 1
				t += _num(T.ad)
			if inter != null and m == 1 and g_runs >= _num(inter.get("fromRun")) \
					and _mod(g_runs, _num(inter.get("every"))) == 0.0 and li >= _num(_qq(inter.get("fromMap"), 0)):
				inters += 1
				t += _num(T.inter)
			coins += pay * m
			best = _max(best, _num(dist))
			t += _min(_num(r.get("t")), _num(T.runCap)) + _num(T.between)
			ds.append(_n(_round((_num(dist) / _num(_or(len_, 1))) * 100.0)))
			if _truthy(r.get("fin")):
				gems += _num(_inv(clear_gems, [li]))
				per.append(0)
				maps.append({"runs": runs, "dry": dry, "t": _n(t), "ds": ds, "per": per, "upg": fmt.call(), "left": _n(_round(coins))})
				break
			var nb := 0
			var first = null
			while true:
				var x = _inv(pick, [li, upg, _n(coins), false, {"runs": g_runs}])
				if not _truthy(x) or _num(x.get("c")) > coins:
					break
				coins -= _num(x.get("c"))
				upg[x.get("id")] = _n(_num(upg.get(x.get("id"))) + 1)
				nb += 1
				if not _truthy(first):
					first = x.get("id")
			if ladder != null and nb >= _num(_qq(ladder.get("afterBuys"), 1)) and g_runs >= _f0(ladder.get("fromRun")):
				var max_steps := _num(ladder.get("maxSteps"))
				var step := 0
				while not (max_steps > 0 and step >= max_steps):
					var x = null
					if _truthy(_qq(ladder.get("pin"), 1)):
						if _truthy(first) and _num(upg.get(first)) < _num(_inv(max_fn, [first, li])):
							x = {"id": first}
					else:
						x = _inv(pick, [li, upg, _n(coins), true, {"runs": g_runs}])
					if not _truthy(x):
						break
					var st: Dictionary = _inv(ladder.step, [step])
					var sg := _num(st.get("gems"))
					var sa = st.get("ads")
					if sg > 0 and gems >= sg:
						gems -= sg
						upg[x.get("id")] = _n(_num(upg.get(x.get("id"))) + 1)
						nb += 1
						gem_ups += 1
						step += 1
						continue
					var want := false
					if _eq(profile, "ads"):
						want = _num(sa) <= _num(_qq(ladder.get("maxAds"), 3))
					elif _eq(profile, "some"):
						want = _num(sa) <= 1 and rnd.call() < 0.5
					if not _truthy(sa) or not want:
						break
					upg[x.get("id")] = _n(_num(upg.get(x.get("id"))) + 1)
					nb += 1
					ad_ups += 1
					rv += _num(sa)
					t += _num(T.ad) * _num(sa)
					step += 1
			if nb == 0:
				dry += 1
			per.append(nb)
			if runs > max_runs:
				maps.append({"runs": runs, "dry": dry, "t": _n(t), "ds": ds, "per": per, "upg": fmt.call(), "stuck": true})
				break
		li += 1
	var all_runs := 0.0
	var all_t := 0.0
	for x in maps:
		all_runs += _num(x.runs)
		all_t += _num(x.t)
	return {"maps": maps, "runs": _n(all_runs), "minutes": _n(all_t / 60.0), "gems": _n(gems), "rv": _n(rv), "inter": inters,
		"gemUps": gem_ups, "adUps": ad_ups, "boostRuns": boost_runs}
static func economy_report(res: Dictionary) -> String:
	var lines := []
	for p in res:
		var r: Dictionary = res[p]
		var maps := []
		for x in r.maps:
			maps.append("%sr%s" % [_str(x.get("runs")), "!" if _truthy(x.get("stuck")) else ""])
		lines.append("%s %s  = %s runs ~%s min | rewarded %s (ad-ups %s), pop-ups %s, gem-ups %s, boosted runs %s, gems left %s" % [
			_str(p).rpad(6), " | ".join(maps), _str(r.get("runs")), _to_fixed0(_num(r.get("minutes"))), _str(r.get("rv")),
			_str(r.get("adUps")), _str(r.get("inter")), _str(r.get("gemUps")), _str(r.get("boostRuns")), _str(r.get("gems"))])
	return "\n".join(lines)
static var _pb := _pow_buf()
static var _PW := {
	"dp_h1": _hexf("3FE2B80340000000"),
	"dp_l1": _hexf("3E4CFDEB43CFD006"),
	"L1": _hexf("3FE3333333333303"),
	"L2": _hexf("3FDB6DB6DB6FABFF"),
	"L3": _hexf("3FD55555518F264D"),
	"L4": _hexf("3FD17460A91D4101"),
	"L5": _hexf("3FCD864A93C9DB65"),
	"L6": _hexf("3FCA7E284A454EEF"),
	"P1": _hexf("3FC555555555553E"),
	"P2": _hexf("BF66C16C16BEBD93"),
	"P3": _hexf("3F11566AAF25DE2C"),
	"P4": _hexf("BEBBBD41C5D26BF1"),
	"P5": _hexf("3E66376972BEA4D0"),
	"lg2": _hexf("3FE62E42FEFA39EF"),
	"lg2_h": _hexf("3FE62E4300000000"),
	"lg2_l": _hexf("BE205C610CA86C39"),
	"ovt": _hexf("3C971547652B82FE"),
	"cp": _hexf("3FEEC709DC3A03FD"),
	"cp_h": _hexf("3FEEC709E0000000"),
	"cp_l": _hexf("BE3E2FE0145B01F5"),
	"ivln2": _hexf("3FF71547652B82FE"),
	"ivln2_h": _hexf("3FF7154760000000"),
	"ivln2_l": _hexf("3E54AE0BF85DDF44"),
}
static func _hexf(h: String) -> float:
	var b := h.hex_decode()
	b.reverse()
	return b.decode_double(0)
static func _pow_buf() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(8)
	return b
static func _hi(x: float) -> int:
	_pb.encode_double(0, x)
	return _pb.decode_s64(0) >> 32
static func _lo(x: float) -> int:
	_pb.encode_double(0, x)
	return _pb.decode_s64(0) & 0xffffffff
static func _mk(hi: int, lo: int) -> float:
	_pb.encode_s64(0, (hi << 32) | (lo & 0xffffffff))
	return _pb.decode_double(0)
static func _scalbn(z: float, n: int) -> float:
	if n < -1022:
		return z * _mk((1023 - 1000) << 20, 0) * _mk((n + 1000 + 1023) << 20, 0)
	return z * _mk((n + 1023) << 20, 0)
static func _pow(x: float, y: float) -> float:
	var bp: Array[float] = [1.0, 1.5]
	var dp_h: Array[float] = [0.0, _PW.dp_h1]
	var dp_l: Array[float] = [0.0, _PW.dp_l1]
	const two53 := 9007199254740992.0
	const huge := 1.0e300
	const tiny := 1.0e-300
	var L1: float = _PW.L1
	var L2: float = _PW.L2
	var L3: float = _PW.L3
	var L4: float = _PW.L4
	var L5: float = _PW.L5
	var L6: float = _PW.L6
	var P1: float = _PW.P1
	var P2: float = _PW.P2
	var P3: float = _PW.P3
	var P4: float = _PW.P4
	var P5: float = _PW.P5
	var lg2: float = _PW.lg2
	var lg2_h: float = _PW.lg2_h
	var lg2_l: float = _PW.lg2_l
	var ovt: float = _PW.ovt
	var cp: float = _PW.cp
	var cp_h: float = _PW.cp_h
	var cp_l: float = _PW.cp_l
	var ivln2: float = _PW.ivln2
	var ivln2_h: float = _PW.ivln2_h
	var ivln2_l: float = _PW.ivln2_l
	var hx := _hi(x)
	var lx := _lo(x)
	var hy := _hi(y)
	var ly := _lo(y)
	var ix := hx & 0x7fffffff
	var iy := hy & 0x7fffffff
	if (iy | ly) == 0:
		return 1.0
	if ix > 0x7ff00000 or (ix == 0x7ff00000 and lx != 0) or iy > 0x7ff00000 or (iy == 0x7ff00000 and ly != 0):
		return x + y
	var yisint := 0
	var j := 0
	var k := 0
	if hx < 0:
		if iy >= 0x43400000:
			yisint = 2
		elif iy >= 0x3ff00000:
			k = (iy >> 20) - 0x3ff
			if k > 20:
				j = ly >> (52 - k)
				if (j << (52 - k)) == ly:
					yisint = 2 - (j & 1)
			elif ly == 0:
				j = iy >> (20 - k)
				if (j << (20 - k)) == iy:
					yisint = 2 - (j & 1)
	if ly == 0:
		if iy == 0x7ff00000:
			if ((ix - 0x3ff00000) | lx) == 0:
				return NAN
			elif ix >= 0x3ff00000:
				return y if hy >= 0 else 0.0
			else:
				return -y if hy < 0 else 0.0
		if iy == 0x3ff00000:
			return 1.0 / x if hy < 0 else x
		if hy == 0x40000000:
			return x * x
		if hy == 0x3fe00000 and hx >= 0:
			return sqrt(x)
	var ax := absf(x)
	var z: float
	if lx == 0 and (ix == 0x7ff00000 or ix == 0 or ix == 0x3ff00000):
		z = ax
		if hy < 0:
			z = 1.0 / z
		if hx < 0:
			if ((ix - 0x3ff00000) | yisint) == 0:
				z = NAN
			elif yisint == 1:
				z = -z
		return z
	var n := (hx >> 31) + 1
	if (n | yisint) == 0:
		return NAN
	var s := 1.0
	if (n | (yisint - 1)) == 0:
		s = -1.0
	var t: float
	var t1: float
	var t2: float
	var u: float
	var v: float
	var w: float
	if iy > 0x41e00000:
		if iy > 0x43f00000:
			if ix <= 0x3fefffff:
				return huge * huge if hy < 0 else tiny * tiny
			if ix >= 0x3ff00000:
				return huge * huge if hy > 0 else tiny * tiny
		if ix < 0x3fefffff:
			return s * huge * huge if hy < 0 else s * tiny * tiny
		if ix > 0x3ff00000:
			return s * huge * huge if hy > 0 else s * tiny * tiny
		t = ax - 1.0
		w = (t * t) * (0.5 - t * (0.3333333333333333333333 - t * 0.25))
		u = ivln2_h * t
		v = t * ivln2_l - w * ivln2
		t1 = _mk(_hi(u + v), 0)
		t2 = v - (t1 - u)
	else:
		n = 0
		if ix < 0x00100000:
			ax *= two53
			n -= 53
			ix = _hi(ax)
		n += (ix >> 20) - 0x3ff
		j = ix & 0x000fffff
		ix = j | 0x3ff00000
		if j <= 0x3988E:
			k = 0
		elif j < 0xBB67A:
			k = 1
		else:
			k = 0
			n += 1
			ix -= 0x00100000
		ax = _mk(ix, _lo(ax))
		u = ax - bp[k]
		v = 1.0 / (ax + bp[k])
		var ss := u * v
		var s_h := _mk(_hi(ss), 0)
		var t_h := _mk(((ix >> 1) | 0x20000000) + 0x00080000 + (k << 18), 0)
		var t_l := ax - (t_h - bp[k])
		var s_l := v * ((u - s_h * t_h) - s_h * t_l)
		var s2 := ss * ss
		var r := s2 * s2 * (L1 + s2 * (L2 + s2 * (L3 + s2 * (L4 + s2 * (L5 + s2 * L6)))))
		r += s_l * (s_h + ss)
		s2 = s_h * s_h
		t_h = _mk(_hi(3.0 + s2 + r), 0)
		t_l = r - ((t_h - 3.0) - s2)
		u = s_h * t_h
		v = s_l * t_h + t_l * ss
		var p_h0 := _mk(_hi(u + v), 0)
		var p_l0 := v - (p_h0 - u)
		var z_h := cp_h * p_h0
		var z_l := cp_l * p_h0 + p_l0 * cp + dp_l[k]
		t = float(n)
		t1 = _mk(_hi(((z_h + z_l) + dp_h[k]) + t), 0)
		t2 = z_l - (((t1 - t) - dp_h[k]) - z_h)
	var y1 := _mk(hy, 0)
	var p_l := (y - y1) * t1 + y * t2
	var p_h := y1 * t1
	z = p_l + p_h
	j = _hi(z)
	var i := _lo(z)
	if j >= 0x40900000:
		if ((j - 0x40900000) | i) != 0:
			return s * huge * huge
		if p_l + ovt > z - p_h:
			return s * huge * huge
	elif (j & 0x7fffffff) >= 0x4090cc00:
		if ((j - (0xc090cc00 - 0x100000000)) | i) != 0:
			return s * tiny * tiny
		if p_l <= z - p_h:
			return s * tiny * tiny
	i = j & 0x7fffffff
	k = (i >> 20) - 0x3ff
	n = 0
	if i > 0x3fe00000:
		n = j + (0x00100000 >> (k + 1))
		k = ((n & 0x7fffffff) >> 20) - 0x3ff
		t = _mk(n & ~(0x000fffff >> k), 0)
		n = ((n & 0x000fffff) | 0x00100000) >> (20 - k)
		if j < 0:
			n = -n
		p_h -= t
	t = _mk(_hi(p_l + p_h), 0)
	u = t * lg2_h
	v = (p_l - (t - p_h)) * lg2 + t * lg2_l
	z = u + v
	w = v - (z - u)
	t = z * z
	t1 = z - t * (P1 + t * (P2 + t * (P3 + t * (P4 + t * P5))))
	var rr := (z * t1) / ((t1 - 2.0) - (w + z * w))
	z = 1.0 - (rr - z)
	j = _hi(z) + (n << 20)
	if (j >> 20) <= 0:
		z = _scalbn(z, n)
	else:
		z = _mk(j, _lo(z))
	return s * z
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
