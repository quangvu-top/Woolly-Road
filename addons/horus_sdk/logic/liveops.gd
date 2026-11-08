# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const _SELF = preload("liveops.gd")
const JS_VERSION := "1.1.0"
const HOUR := 3600000.0
const DAY := 86400000.0
static var clock: Clock = Clock.new()
static var time_zone: Callable = Callable()
static var _sys_at := -1e18
static var _sys_min := 0.0
class Clock extends RefCounted:
	var shift = 0
	var base: Callable = Callable()
	func now():
		var b = base.call() if base.is_valid() else floorf(Time.get_unix_time_from_system() * 1000.0)
		return _SELF._n(_SELF._num(b) + _SELF._f0(shift))
static func create_clock(o: Dictionary = {}) -> Clock:
	var c := Clock.new()
	c.shift = _n(_f0(_num(o.get("shift"))))
	if o.get("base") is Callable:
		c.base = o.base
	return c
static func fixed_zone(minutes: float) -> Callable:
	return func(_t): return minutes
static func _now():
	return clock.now()
static func _t(t):
	return clock.now() if t == null else t
static func _t_of(o):
	var v = o.get("now") if o is Dictionary else null
	return clock.now() if v == null else v
static func day_key(t = null) -> String:
	var p := _parts(_t(t))
	if p.is_empty():
		return "NaN-NaN-NaN"
	return "%s-%s-%s" % [_num_str(p[0]), _pad2(p[1]), _pad2(p[2])]
static func day_start(key = null):
	var parts := _str(key).split("-")
	var y := _str_to_num(parts[0])
	var m := _str_to_num(parts[1]) if parts.size() > 1 else NAN
	var d := _str_to_num(parts[2]) if parts.size() > 2 else NAN
	return _n(_new_date(y, m - 1.0, d))
static func day_diff(a = null, b = null):
	return _n(_round((_num(day_start(b)) - _num(day_start(a))) / DAY))
static func ms_to_midnight(t = null):
	var tt := _num(_t(t))
	var tv := _clip(tt)
	if is_nan(tv):
		return NAN
	var lt := tv + _zone_ms(tv)
	return _n(_clip(_utc(floorf(lt / DAY) * DAY + DAY)) - tt)
static func at_day(t = null, n = null, m = null):
	var p := _parts(t)
	if p.is_empty():
		return NAN
	return _n(_new_date(p[0], p[1] - 1.0, p[2] + _num(n), 0.0, _num(m)))
static func minute_of(t = null):
	var p := _parts(t)
	return NAN if p.is_empty() else _n(p[3] * 60.0 + p[4])
static func next_hour(t = null):
	var tv := _clip(_num(t))
	if is_nan(tv):
		return NAN
	var lt := tv + _zone_ms(tv)
	var day := floorf(lt / DAY)
	var hour := floorf((lt - day * DAY) / HOUR)
	return _n(_clip(_utc(day * DAY + hour * HOUR + HOUR)))
static func local_ms(y = null, m = null, d = null, h = 0, mi = 0, s = 0):
	return _n(_make(_num(y), _num(m) - 1.0, _num(d), _num(h), _num(mi), _num(s), 0.0))
static func local_parts(t = null) -> Dictionary:
	var p := _parts(_t(t))
	if p.is_empty():
		return {}
	return {"year": _n(p[0]), "month": _n(p[1]), "day": _n(p[2]), "hour": _n(p[3]), "minute": _n(p[4]), "second": _n(p[5]),
		"ms": _n(p[6]), "weekday": _n(p[7])}
static func fmt_left(ms = null, units: Dictionary = {}) -> String:
	var uh = _qq(units.get("h"), "h")
	var um = _qq(units.get("m"), "m")
	var s := _max(0.0, ceilf(_num(ms) / 1000.0))
	var h := floorf(s / 3600.0)
	var m := floorf(_mod(s, 3600.0) / 60.0)
	if h > 0:
		return "%s%s %s%s" % [_num_str(h), _str(uh), _pad2(m), _str(um)]
	return "%s:%s" % [_num_str(m), _pad2(_mod(s, 60.0))]
static func fmt_dur(ms = null, units: Dictionary = {}) -> String:
	var U := {"s": "s", "min": "min", "h": "h", "d": "d"}
	U.merge(units, true)
	var s := _round(_num(ms) / 1000.0)
	if s < 60:
		return "%s %s" % [_num_str(s), _str(U.s)]
	var m := _round(s / 60.0)
	if m < 60:
		return "%s %s" % [_num_str(m), _str(U.min)]
	var h := floorf(m / 60.0)
	if h >= 48:
		var d := floorf(h / 24.0)
		if _truthy(_mod(h, 24.0)):
			return "%s %s %s %s" % [_num_str(d), _str(U.d), _num_str(_mod(h, 24.0)), _str(U.h)]
		return "%s %s" % [_num_str(d), _str(U.d)]
	if _truthy(_mod(m, 60.0)):
		return "%s %s %s %s" % [_num_str(h), _str(U.h), _num_str(_mod(m, 60.0)), _str(U.min)]
	return "%s %s" % [_num_str(h), _str(U.h)]
static func shop_round(c = null):
	var x := _num(c)
	var step := 5.0 if x < 100 else 10.0 if x < 1000 else 50.0 if x < 1e4 else 500.0 if x < 1e5 else 5000.0 if x < 1e6 else 50000.0
	return _n(_max(step, _round(x / step) * step))
static func _pad2(n) -> String:
	var s := _str(n)
	return s if s.length() >= 2 else "0".repeat(2 - s.length()) + s
static func _clip(t: float) -> float:
	if not is_finite(t) or absf(t) > 8.64e15:
		return NAN
	return _trunc(t) + 0.0
static func _trunc(x: float) -> float:
	return floorf(x) if x >= 0 else ceilf(x)
static func _zone_ms(t: float) -> float:
	var m = time_zone.call(t) if time_zone.is_valid() else _system_zone()
	return _num(m) * 60000.0
static func _system_zone() -> float:
	var now_s := Time.get_unix_time_from_system()
	if absf(now_s - _sys_at) < 1.0:
		return _sys_min
	var local := float(Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system(false)))
	_sys_min = roundf((local - floorf(now_s)) / 60.0)
	_sys_at = now_s
	return _sys_min
static func _utc(lt: float) -> float:
	if not is_finite(lt):
		return NAN
	var o1 := _zone_ms(lt - DAY)
	var o2 := _zone_ms(lt + DAY)
	if o1 == o2:
		return lt - o1
	var u1 := lt - o1
	var u2 := lt - o2
	var ok1 := _zone_ms(u1) == o1
	var ok2 := _zone_ms(u2) == o2
	if ok1 and ok2:
		return minf(u1, u2)
	return u2 if ok2 else u1
static func _parts(t) -> Array:
	var tv := _clip(_num(t))
	if is_nan(tv):
		return []
	var lt := tv + _zone_ms(tv)
	var days := floorf(lt / DAY)
	var ms := lt - days * DAY
	var c := _civil(days)
	return [c[0], c[1], c[2], floorf(ms / HOUR), floorf(fmod(ms, HOUR) / 60000.0), floorf(fmod(ms, 60000.0) / 1000.0),
		fmod(ms, 1000.0), fmod(fmod(days + 4.0, 7.0) + 7.0, 7.0)]
static func _new_date(y: float, mon: float, d: float, h := 0.0, mi := 0.0) -> float:
	if is_finite(y) and _trunc(y) >= 0 and _trunc(y) <= 99:
		y = 1900.0 + _trunc(y)
	return _make(y, mon, d, h, mi, 0.0, 0.0)
static func _make(y: float, mon: float, d: float, h: float, mi: float, s: float, ms: float) -> float:
	for v in [y, mon, d, h, mi, s, ms]:
		if not is_finite(v):
			return NAN
	y = _trunc(y)
	mon = _trunc(mon)
	var ym := y + floorf(mon / 12.0)
	var mn := fmod(fmod(mon, 12.0) + 12.0, 12.0)
	if absf(ym) > 400000.0:
		return NAN
	var day := _days_from_civil(ym, mn + 1.0, 1.0) + _trunc(d) - 1.0
	var time := _trunc(h) * HOUR + _trunc(mi) * 60000.0 + _trunc(s) * 1000.0 + _trunc(ms)
	return _clip(_utc(day * DAY + time))
static func _days_from_civil(y: float, m: float, d: float) -> float:
	if m <= 2:
		y -= 1.0
	var era := floorf(y / 400.0)
	var yoe := y - era * 400.0
	var mp := fmod(m + 9.0, 12.0)
	var doy := floorf((153.0 * mp + 2.0) / 5.0) + d - 1.0
	var doe := yoe * 365.0 + floorf(yoe / 4.0) - floorf(yoe / 100.0) + doy
	return era * 146097.0 + doe - 719468.0
static func _civil(z: float) -> Array:
	z += 719468.0
	var era := floorf(z / 146097.0)
	var doe := z - era * 146097.0
	var yoe := floorf((doe - floorf(doe / 1460.0) + floorf(doe / 36524.0) - floorf(doe / 146096.0)) / 365.0)
	var doy := doe - (365.0 * yoe + floorf(yoe / 4.0) - floorf(yoe / 100.0))
	var mp := floorf((5.0 * doy + 2.0) / 153.0)
	var d := doy - floorf((153.0 * mp + 2.0) / 5.0) + 1.0
	var m := mp + 3.0 if mp < 10.0 else mp - 9.0
	return [yoe + era * 400.0 + (1.0 if m <= 2.0 else 0.0), m, d]
static func _date_parse(v) -> float:
	var tk := _date_tokens(_str(v))
	var at := [0]
	var peek := func() -> Array: return tk[mini(at[0], tk.size() - 1)]
	var next := func() -> Array:
		var t: Array = tk[mini(at[0], tk.size() - 1)]
		at[0] += 1
		return t
	var skip := func(c: String) -> bool:
		var t: Array = peek.call()
		if t[0] == "sym" and t[1] == c:
			at[0] += 1
			return true
		return false
	var num2 := func(t: Array, n: int) -> bool: return t[0] == "num" and t[2] == n
	var none := 0x7fffffff
	var day := []
	var named_month := none
	var iso := false
	var time := []
	var hour_offset := none
	var tz := {"sign": none, "hour": none, "minute": none}
	var unhandled: Array = []
	var t0: Array = peek.call()
	if t0[0] == "sym" and (t0[1] == "+" or t0[1] == "-"):
		var sign_t: Array = next.call()
		if not num2.call(peek.call(), 6):
			unhandled = sign_t
		else:
			var y: int = next.call()[1]
			if sign_t[1] == "-" and y == 0:
				unhandled = sign_t
			else:
				day.append(-y if sign_t[1] == "-" else y)
	elif num2.call(t0, 4):
		day.append(next.call()[1])
	else:
		unhandled = next.call()
	if unhandled.is_empty():
		if skip.call("-"):
			var t: Array = peek.call()
			if not num2.call(t, 2) or t[1] < 1 or t[1] > 12:
				unhandled = next.call()
			else:
				day.append(next.call()[1])
				if skip.call("-"):
					t = peek.call()
					if not num2.call(t, 2) or t[1] < 1 or t[1] > 31:
						unhandled = next.call()
					else:
						day.append(next.call()[1])
	if unhandled.is_empty():
		var t: Array = peek.call()
		if not (t[0] == "kw" and t[1] == "tsep"):
			if t[0] != "end":
				unhandled = next.call()
		else:
			next.call()
			t = peek.call()
			if not num2.call(t, 2) or t[1] > 24:
				return NAN
			var h24: bool = t[1] == 24
			time.append(next.call()[1])
			if not skip.call(":"):
				return NAN
			t = peek.call()
			if not num2.call(t, 2) or t[1] > 59 or (h24 and t[1] > 0):
				return NAN
			time.append(next.call()[1])
			if skip.call(":"):
				t = peek.call()
				if not num2.call(t, 2) or t[1] > 59 or (h24 and t[1] > 0):
					return NAN
				time.append(next.call()[1])
				if skip.call("."):
					t = peek.call()
					if t[0] != "num" or (h24 and t[1] > 0):
						return NAN
					time.append(_ms_digits(next.call()))
			t = peek.call()
			if t[0] == "kw" and t[1] == "tz" and t[3] == 1 and t[2] == 0:
				next.call()
				tz = {"sign": 1, "hour": 0, "minute": 0}
			elif t[0] == "sym" and (t[1] == "+" or t[1] == "-"):
				tz.sign = 1 if next.call()[1] == "+" else -1
				t = peek.call()
				if num2.call(t, 4):
					var hm: int = next.call()[1]
					if hm / 100 > 23 or hm % 100 > 59:
						return NAN
					tz.hour = hm / 100
					tz.minute = hm % 100
				else:
					if not num2.call(t, 2) or t[1] > 23:
						return NAN
					tz.hour = next.call()[1]
					if not skip.call(":"):
						return NAN
					t = peek.call()
					if not num2.call(t, 2) or t[1] > 59:
						return NAN
					tz.minute = next.call()[1]
			if peek.call()[0] != "end":
				return NAN
		if unhandled.is_empty():
			if tz.hour == none and time.is_empty():
				tz = {"sign": 1, "hour": 0, "minute": 0}
			iso = true
			unhandled = ["end"]
	var read_number := not day.is_empty()
	var token := unhandled
	while token[0] != "end":
		if token[0] == "num":
			read_number = true
			var n: int = token[1]
			if skip.call(":"):
				if skip.call(":"):
					if not time.is_empty():
						return NAN
					time.append_array([n, 0])
				else:
					if time.size() >= 4:
						return NAN
					time.append(n)
					if peek.call()[0] == "sym" and peek.call()[1] == ".":
						next.call()
			elif skip.call(".") and _time_expects(time, n):
				time.append(n)
				if peek.call()[0] != "num":
					return NAN
				var ms := _ms_digits(next.call())
				if time.size() >= 4:
					return NAN
				time.append(ms)
				while time.size() < 4:
					time.append(0)
			elif tz.hour != none and tz.minute == none and n >= 0 and n <= 59:
				tz.minute = n
			elif _time_expects(time, n):
				time.append(n)
				while time.size() < 4:
					time.append(0)
				var p: Array = peek.call()
				if not (p[0] == "end" or p[0] == "ws" or (p[0] == "kw" and p[1] == "tz" and p[3] == 1 and p[2] == 0) or (p[0] == "sym" and (p[1] == "+" or p[1] == "-"))):
					return NAN
			else:
				if day.size() >= 3:
					return NAN
				day.append(n)
				skip.call("-")
		elif token[0] == "kw":
			if token[1] == "ampm" and not time.is_empty():
				hour_offset = token[2]
			elif token[1] == "month":
				named_month = token[2]
				skip.call("-")
			elif token[1] == "tz" and read_number:
				tz = {"sign": -1 if token[2] < 0 else 1, "hour": absi(token[2]), "minute": 0}
			else:
				if read_number or peek.call()[0] == "num":
					return NAN
		elif token[0] == "sym" and (token[1] == "+" or token[1] == "-") and ((tz.hour == 0 and tz.minute == 0) or not time.is_empty()):
			tz.sign = 1 if token[1] == "+" else -1
			var n := 0
			var length := 0
			if peek.call()[0] == "num":
				var t: Array = next.call()
				n = t[1]
				length = t[2]
			read_number = true
			if peek.call()[0] == "sym" and peek.call()[1] == ":":
				tz.hour = n
				tz.minute = none
			elif length == 1 or length == 2:
				tz.hour = n
				tz.minute = 0
			elif length == 3 or length == 4:
				tz.hour = n / 100
				tz.minute = n % 100
			else:
				return NAN
		elif (token[0] == "sym" and (token[1] == "+" or token[1] == "-" or token[1] == ")")) and read_number:
			return NAN
		token = next.call()
	if day.is_empty():
		return NAN
	while day.size() < 3:
		day.append(1)
	var y := 0
	var mo := none
	var d := none
	if named_month == none:
		if iso or not (day[0] >= 1 and day[0] <= 31):
			y = day[0]
			mo = day[1]
			d = day[2]
		else:
			mo = day[0]
			d = day[1]
			y = day[2]
	else:
		mo = named_month
		if not (day[0] >= 1 and day[0] <= 31):
			y = day[0]
			d = day[1]
		else:
			d = day[0]
			y = day[1]
	if not iso:
		if y >= 0 and y <= 49:
			y += 2000
		elif y >= 50 and y <= 99:
			y += 1900
	if absi(y) >= 1 << 30 or mo < 1 or mo > 12 or d < 1 or d > 31:
		return NAN
	while time.size() < 4:
		time.append(0)
	var h: int = time[0]
	if hour_offset != none:
		if h < 0 or h > 12:
			return NAN
		h = h % 12 + hour_offset
	if h > 23 or time[1] > 59 or time[2] > 59 or time[3] > 999:
		if h != 24 or time[1] != 0 or time[2] != 0 or time[3] != 0:
			return NAN
	var date: float = (_days_from_civil(y, mo, 1) + d - 1) * DAY + h * HOUR + time[1] * 60000.0 + time[2] * 1000.0 + time[3]
	if tz.sign == none:
		if absf(date) > 8.64e15 + 864e6:
			return NAN
		return _clip(_utc(date))
	var off := float((0 if tz.hour == none else tz.hour) * 3600 + (0 if tz.minute == none else tz.minute) * 60)
	date -= (off if tz.sign > 0 else -off) * 1000.0
	return NAN if absf(date) > 8.64e15 else _clip(date)
static func _time_expects(time: Array, n: int) -> bool:
	return (time.size() == 1 and n <= 59) or (time.size() == 2 and n <= 59) or (time.size() == 3 and n <= 999)
static func _ms_digits(t: Array) -> int:
	var n: int = t[1]
	var length: int = t[2]
	if length == 1:
		return n * 100
	if length == 2:
		return n * 10
	length = mini(length, 9)
	while length > 3:
		n /= 10
		length -= 1
	return n
const _DATE_WORDS := {"jan": ["month", 1], "feb": ["month", 2], "mar": ["month", 3], "apr": ["month", 4], "may": ["month", 5],
		"jun": ["month", 6], "jul": ["month", 7], "aug": ["month", 8], "sep": ["month", 9], "oct": ["month", 10], "nov": ["month", 11],
		"dec": ["month", 12], "am": ["ampm", 0], "pm": ["ampm", 12], "ut": ["tz", 0], "utc": ["tz", 0], "z": ["tz", 0], "gmt": ["tz", 0],
		"cdt": ["tz", -5], "cst": ["tz", -6], "edt": ["tz", -4], "est": ["tz", -5], "mdt": ["tz", -6], "mst": ["tz", -7],
		"pdt": ["tz", -7], "pst": ["tz", -8], "t": ["tsep", 0]}
static func _date_tokens(s: String) -> Array:
	var out := []
	var i := 0
	var n := s.length()
	var ws := _re("[\\s\\x{a0}\\x{1680}\\x{2000}-\\x{200a}\\x{2028}\\x{2029}\\x{202f}\\x{205f}\\x{3000}\\x{feff}]")
	while i < n:
		var c := s.unicode_at(i)
		if c >= 48 and c <= 57:
			var start := i
			var v := 0
			var digits := 0
			while i < n and s.unicode_at(i) == 48:
				i += 1
			while i < n and s.unicode_at(i) >= 48 and s.unicode_at(i) <= 57:
				if digits < 9:
					v = v * 10 + s.unicode_at(i) - 48
				digits += 1
				i += 1
			out.append(["num", v, i - start])
		elif s[i] in [":", "-", "+", ".", ")"]:
			out.append(["sym", s[i]])
			i += 1
		elif c >= 65 and not ws.search(s[i]):
			var word := ""
			var length := 0
			while i < n and s.unicode_at(i) >= 65 and not ws.search(s[i]):
				if word.length() < 3:
					var ch := s.unicode_at(i)
					word += String.chr(ch | 0x20) if (ch >= 65 and ch <= 90) else s[i]
				length += 2 if s.unicode_at(i) > 0xFFFF else 1
				i += 1
			var k = _DATE_WORDS.get(word)
			if k != null and (length <= 3 or k[0] == "month"):
				out.append(["kw", k[0], k[1], length])
			else:
				out.append(["kw", "", 0, length])
		elif ws.search(s[i]):
			out.append(["ws"])
			i += 1
		elif s[i] == "(":
			var depth := 0
			while true:
				if s[i] == ")":
					depth -= 1
				elif s[i] == "(":
					depth += 1
				i += 1
				if depth <= 0 or i >= n:
					break
			out.append(["unk"])
		else:
			out.append(["unk"])
			i += 1
	out.append(["end"])
	return out
static func assign_ab(ab: Dictionary, experiments = null, rnd: Callable = Callable()) -> Array:
	var out := []
	if not rnd.is_valid():
		rnd = func(): return randf()
	if not (experiments is Dictionary):
		return out
	for k in experiments:
		var e = experiments[k]
		var vs: Array = _or(_prop(e, "variants"), [])
		if vs.is_empty() or _includes(vs, ab.get(k)):
			continue
		var weights = _prop(e, "weights")
		var w := []
		var total := 0.0
		for i in vs.size():
			var wi = weights[i] if weights is Array and i < weights.size() else null
			var x := _num(_qq(wi, 1))
			x = _max(0.0, x if _truthy(x) else 0.0)
			w.append(x)
			total += x
		var r := _num(rnd.call()) * total
		var pick = null
		for i in vs.size():
			r -= w[i]
			if r < 0:
				pick = vs[i]
				break
		ab[k] = pick if _truthy(pick) else vs[0]
		out.append(k)
	return out
static func create_meta() -> Dictionary:
	return {"installAt": 0, "installDay": "", "sessions": 0, "sessionStart": 0, "lastSeen": 0, "days": [], "sessionRuns": 0, "back24": 0, "hours": []}
static func boot_meta(m: Dictionary, t = null) -> Dictionary:
	t = _t(t)
	if not _truthy(m.get("installAt")):
		m["installAt"] = t
		m["installDay"] = day_key(t)
	if not _truthy(m.get("installDay")):
		m["installDay"] = day_key(m.installAt)
	if not (m.get("days") is Array):
		m["days"] = []
	if not (m.get("hours") is Array):
		m["hours"] = []
	return m
static func day_index(m: Dictionary, t = null):
	t = _t(t)
	return day_diff(_or(m.get("installDay"), day_key(_or(m.get("installAt"), t))), day_key(t))
static func note_session_start(m: Dictionary, t = null, keep = 14) -> void:
	t = _t(t)
	if not (m.get("hours") is Array):
		m["hours"] = []
	var h: Array = m.hours
	h.append([day_index(m, t), minute_of(t)])
	while h.size() > _num(_qq(keep, 14)) and not h.is_empty():
		h.pop_front()
static func resume_session(m: Dictionary, o: Dictionary = {}) -> Dictionary:
	var t = _t_of(o)
	var gap := _num(_qq(o.get("sessionGap"), 30 * 60e3))
	var keep_days := _num(_qq(o.get("keepDays"), 60))
	var keep_hours = _qq(o.get("keepHours"), 14)
	boot_meta(m, t)
	var away = _n(_max(0.0, _num(t) - _num(m.get("lastSeen")))) if _truthy(m.get("sessions")) and _truthy(m.get("lastSeen")) else 0
	var fresh: bool = not _truthy(m.get("sessions")) or _num(away) >= gap
	var prev = null
	if fresh and _truthy(m.get("sessions")):
		prev = {"sess": m.sessions, "len": _n(_max(0.0, _num(m.get("lastSeen")) - _num(m.get("sessionStart")))), "runs": _or(m.get("sessionRuns"), 0)}
	if fresh:
		m["sessions"] = _n(_f0(m.get("sessions")) + 1.0)
		m["sessionStart"] = t
		m["sessionRuns"] = 0
	m["lastSeen"] = t
	var day = day_index(m, t)
	var new_day := false
	if _num(day) >= 0 and not _includes(m.days, day):
		m.days.append(day)
		new_day = true
		while m.days.size() > keep_days and not m.days.is_empty():
			m.days.pop_front()
	var h := (_num(t) - _num(m.get("installAt"))) / HOUR
	if h >= 24 and h < 48:
		m["back24"] = 1
	if fresh and _num(keep_hours) > 0:
		note_session_start(m, t, keep_hours)
	return {"away": away, "fresh": fresh, "day": day, "newDay": new_day, "prev": prev}
static func pause_session(m: Dictionary, t = null) -> Dictionary:
	t = _t(t)
	m["lastSeen"] = t
	return {"len": _n(_max(0.0, _num(t) - _num(_or(m.get("sessionStart"), t)))), "runs": _or(m.get("sessionRuns"), 0)}
static func _off_cfg(c) -> Dictionary:
	var out := {"capH": 8, "minAway": 5 * 60e3, "showH": 0.25}
	if c is Dictionary:
		out.merge(c, true)
	var rate := _num(_prop(c, "rate"))
	out["rate"] = _max(0.0, rate if _truthy(rate) else 0.0)
	return out
static func create_offline() -> Dictionary:
	return {"pending": 0, "hours": 0}
static func offline_cap(cfg = null):
	var c := _off_cfg(cfg)
	return _n(_num(c.rate) * _num(c.capH))
static func accrue_offline(s: Dictionary, away = null, cfg = null):
	var c := _off_cfg(cfg)
	var a := _num(away)
	if not (a >= _num(c.minAway)):
		return 0
	var rate := _num(c.rate)
	var cap_h := _num(c.capH)
	var hrs := _min(cap_h, a / HOUR)
	var add := _max(0.0, _min(rate * cap_h - _f0(s.get("pending")), floorf(rate * hrs)))
	s["pending"] = _n(_f0(s.get("pending")) + add)
	s["hours"] = _n(_min(cap_h, _f0(s.get("hours")) + hrs))
	return _n(add)
static func offline_ready(s: Dictionary, cfg = null) -> bool:
	var c := _off_cfg(cfg)
	var p := _num(s.get("pending"))
	return p > 0 and p >= _num(c.rate) * _num(c.showH)
static func offline_at(s: Dictionary, last_seen = null, t = null, cfg = null):
	var c := _off_cfg(cfg)
	var tt := _num(t)
	var hrs := _max(0.0, _min(_num(c.capH), (tt - _num(_or(last_seen, t))) / HOUR))
	return _n(_min(_num(c.rate) * _num(c.capH), _f0(s.get("pending")) + floorf(_num(c.rate) * hrs)))
static func claim_offline(s: Dictionary, mult = 1) -> Dictionary:
	var coins := _round(_f0(s.get("pending")) * _num(_qq(mult, 1)))
	var hours = _or(s.get("hours"), 0)
	s["pending"] = 0
	s["hours"] = 0
	return {"coins": _n(coins), "hours": hours}
static func create_calendar() -> Dictionary:
	return {"day": 0, "last": "", "claims": 0}
static func _reward_list(rewards, days) -> Array:
	if rewards is Callable:
		var n := _num(7 if days == null else days)
		n = 0.0 if not (n > 0) else minf(_trunc(n), 1e6)
		var out := []
		for i in int(n):
			out.append(_inv(rewards, [i]))
		return out
	if rewards is Array:
		return rewards.duplicate()
	if rewards is String:
		var chars := []
		for ch in rewards:
			chars.append(ch)
		return chars
	return []
static func _at(list: Array, i):
	var x := _num(i)
	if not is_finite(x) or x != floorf(x) or x < 0 or x >= list.size():
		return null
	return list[int(x)]
static func calendar_info(s: Dictionary, rewards = null, o: Dictionary = {}) -> Dictionary:
	var t = _t_of(o)
	var claimable := not _eq(s.get("last"), day_key(t))
	return {"day": s.get("day"), "claimable": claimable, "rewards": _reward_list(rewards, o.get("days")), "claims": s.get("claims"),
		"nextIn": 0 if claimable else ms_to_midnight(t)}
static func claim_calendar(s: Dictionary, rewards = null, o: Dictionary = {}):
	var t = _t_of(o)
	if _eq(s.get("last"), day_key(t)):
		return null
	var list := _reward_list(rewards, o.get("days"))
	var n := float(list.size()) if list.size() > 0 else 7.0
	var index := _mod(_num(s.get("day")), n)
	s["last"] = day_key(t)
	s["day"] = _n(_mod(index + 1.0, n))
	s["claims"] = _n(_f0(s.get("claims")) + 1.0)
	return {"day": _n(index + 1.0), "index": _n(index), "reward": _at(list, index)}
static func create_chest() -> Dictionary:
	return {"readyAt": 0, "opens": 0, "adDate": "", "adOpens": 0}
static func chest_info(s: Dictionary, cfg: Dictionary = {}, o: Dictionary = {}) -> Dictionary:
	var t := _num(_t_of(o))
	var today := day_key(t)
	var ads := _num(_qq(cfg.get("adOpens"), 3))
	if not _eq(s.get("adDate"), today):
		s["adDate"] = today
		s["adOpens"] = 0
	var ready_at := _f0(s.get("readyAt"))
	return {"ready": t >= ready_at, "left": _n(_max(0.0, ready_at - t)), "adLeft": _n(_max(0.0, ads - _num(s.get("adOpens")))),
		"readyAt": _or(s.get("readyAt"), 0)}
static func open_chest(s: Dictionary, cfg: Dictionary = {}, o: Dictionary = {}):
	var t = _t_of(o)
	var info := chest_info(s, cfg, {"now": t})
	var via_ad := _truthy(o.get("viaAd"))
	if (_num(info.adLeft) <= 0) if via_ad else not info.ready:
		return null
	s["opens"] = _n(_f0(s.get("opens")) + 1.0)
	if via_ad:
		s["adOpens"] = _n(_num(s.get("adOpens")) + 1.0)
	else:
		s["readyAt"] = _n(_num(t) + _num(_qq(cfg.get("every"), 4.0 * HOUR)))
	var r = _qq(o.get("reward"), cfg.get("reward"))
	if r is Callable:
		return r.call()
	return true if r == null else r
static func gift_due(g: Dictionary, t = null, cfg: Dictionary = {}) -> bool:
	t = _t(t)
	var days = _qq(cfg.get("days"), 7)
	var every := _num(_qq(cfg.get("every"), 30))
	if not _truthy(days) or _truthy(g.get("waiting")):
		return false
	var last = _or(g.get("lastSeen"), t)
	return _num(day_diff(day_key(last), day_key(t))) >= _num(days) and _num(t) - _f0(g.get("givenAt")) >= every * DAY
static func seeded_random(s = null) -> Callable:
	var h := 2166136261
	if s is String or s is StringName:
		for u in _utf16(String(s)):
			h = _imul(h ^ u, 16777619)
	var st := [h]
	return func() -> float:
		var x: int = st[0]
		x = _imul(x ^ (x >> 15), 2246822507)
		x = _imul(x ^ (x >> 13), 3266489909)
		x = x ^ (x >> 16)
		st[0] = x
		return float(x) / 4294967296.0
static func _imul(a: int, b: int) -> int:
	a &= 0xFFFFFFFF
	b &= 0xFFFFFFFF
	return (a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF
static func _utf16(s: String) -> Array:
	var out := []
	for i in s.length():
		var c := s.unicode_at(i)
		if c > 0xFFFF:
			c -= 0x10000
			out.append(0xD800 + (c >> 10))
			out.append(0xDC00 + (c & 0x3FF))
		else:
			out.append(c)
	return out
static func create_missions() -> Dictionary:
	return {"date": "", "list": [], "bonus": 0}
static func ensure_missions(s: Dictionary, defs = null, ctx = {}, o: Dictionary = {}):
	var today := day_key(_qq(o.get("now"), _now()))
	if _eq(s.get("date"), today) and s.get("list") is Array and not s.list.is_empty():
		return null
	var carried_list := []
	var carried := 0.0
	for m in _or(s.get("list"), []):
		if _truthy(_prop(m, "done")) and not _truthy(_prop(m, "claimed")):
			carried_list.append(m)
			carried += _f0(_prop(m, "gems"))
	var rnd := seeded_random(today + ":" + _str(_qq(o.get("seed"), "")))
	var D: Dictionary = defs if defs is Dictionary else {}
	var c: Dictionary = ctx if ctx is Dictionary else {}
	var tiers := []
	for k in D:
		var tier = _qq(_prop(D[k], "tier"), 0)
		if not _includes(tiers, tier):
			tiers.append(tier)
	tiers = _sorted(tiers, func(a, b): return _num(a) - _num(b))
	var list := []
	for tier in tiers:
		var ks := []
		for k in D:
			var needs = _prop(D[k], "needs")
			if _eq(_qq(_prop(D[k], "tier"), 0), tier) and (not _truthy(needs) or _truthy(c.get(_key(needs)))):
				ks.append(k)
		var r: float = rnd.call()
		if ks.is_empty():
			continue
		var id = ks[int(floorf(r * ks.size()))]
		var M = D[id]
		var nf := _fn(M, "n")
		var n = _inv(nf, [c]) if nf.is_valid() else 1
		var tf := _fn(M, "text")
		var m := {"id": id, "n": n, "prog": 0, "gems": _or(_prop(M, "gems"), 0), "done": 0, "claimed": 0, "text": _inv(tf, [n, c]) if tf.is_valid() else id}
		if M is Dictionary and M.has("reward"):
			m["reward"] = M.reward
		list.append(m)
	s["date"] = today
	s["bonus"] = 0
	s["list"] = list
	return {"carried": _n(carried), "carriedList": carried_list, "list": list}
static func mission_progress(s: Dictionary, kind = null, amount = 1, defs = {}) -> Array:
	var done := []
	var a := _num(_qq(amount, 1))
	if not (a > 0):
		return done
	var keeps_max := _truthy(_prop(defs.get(_key(kind)) if defs is Dictionary else null, "max"))
	for m in _or(s.get("list"), []):
		if not _eq(m.get("id"), kind) or _truthy(m.get("done")):
			continue
		m["prog"] = _n(_max(_num(m.get("prog")), _num(amount))) if keeps_max else _add(m.get("prog"), _qq(amount, 1))
		if _num(m.prog) >= _num(m.get("n")):
			m["prog"] = m.get("n")
			m["done"] = 1
			done.append(m)
	return done
static func missions_info(s: Dictionary, o: Dictionary = {}) -> Dictionary:
	var list: Array = _or(s.get("list"), [])
	var all := not list.is_empty()
	for m in list:
		if not _truthy(m.get("claimed")):
			all = false
	var ready := 0
	for m in list:
		if _truthy(m.get("done")) and not _truthy(m.get("claimed")):
			ready += 1
	if all and not _truthy(s.get("bonus")):
		ready += 1
	return {"list": list, "ready": ready, "allClaimed": all, "bonus": s.get("bonus"), "refreshIn": ms_to_midnight(_qq(o.get("now"), _now()))}
static func claim_mission(s: Dictionary, i = null):
	var m = _at(s.list, i) if s.get("list") is Array else null
	if not _truthy(m) or not _truthy(m.get("done")) or _truthy(m.get("claimed")):
		return null
	m["claimed"] = 1
	return {"id": m.get("id"), "gems": m.get("gems"), "reward": m.get("reward")}
static func claim_mission_bonus(s: Dictionary) -> bool:
	if _truthy(s.get("bonus")) or not (s.get("list") is Array) or s.list.is_empty():
		return false
	for m in s.list:
		if not _truthy(m.get("claimed")):
			return false
	s["bonus"] = 1
	return true
const NOTIFY_DEFAULTS := {
	"window": "9-21",
	"bounds": "7-23",
	"learn": 3,
	"keep": 14,
	"lead": 30,
	"fallback": 19 * 60,
	"merge": 3,
	"cap": 2,
	"comeback": "2,3,7,14",
	"quiet": 3,
	"respond": 0,
	"off": "",
}
static func _span(s, d: Array) -> Array:
	var m := _re("^([0-9]{1,2})-([0-9]{1,2})\\z").search(_str(s) if _truthy(s) else "")
	var a: Array = [m.get_string(1).to_float(), m.get_string(2).to_float()] if m else d
	return a if a[0] < a[1] and a[1] <= 24 else d
static func _list(v) -> Array:
	var items: Array = v if v is Array else Array(_str(_qq(v, "")).split(","))
	var out := []
	for x in items:
		var s := _trim(_str(x))
		if s != "":
			out.append(s)
	return out
static func _has_hour(hours, h) -> bool:
	var x := _num(h)
	if not is_finite(x) or x != floorf(x):
		return false
	if hours is Dictionary:
		return hours.has(int(x)) or hours.has(x)
	if hours is Array:
		return _includes(hours, x)
	return false
static func _hour_list(hours) -> Array:
	return hours.keys() if hours is Dictionary else (hours.duplicate() if hours is Array else [])
static func play_window(starts = null, cfg = {}, fixed = false) -> Dictionary:
	var C := NOTIFY_DEFAULTS.duplicate()
	if cfg is Dictionary:
		C.merge(cfg, true)
	var w := _span(C.get("window"), [9, 21])
	var b := _span(C.get("bounds"), [7, 23])
	var w0 := int(w[0])
	var w1 := int(w[1])
	var b0 := float(b[0])
	var b1 := float(b[1])
	var st := []
	if starts is Array:
		for x in starts:
			if x is Array and x.size() > 1 and _is_fin(x[1]):
				st.append(x)
	var days := []
	for x in st:
		if not _includes(days, x[0]):
			days.append(x[0])
	if _truthy(fixed) or st.size() < _num(C.get("learn")) or days.size() < 2:
		var hs := {}
		for i in range(w0, w1):
			hs[i] = true
		return {"hours": hs, "main": C.get("fallback"), "learned": false}
	var count := []
	count.resize(24)
	count.fill(0)
	for x in st:
		var i := _mod(floorf(_num(x[1]) / 60.0), 24.0)
		if i >= 0 and i < 24:
			count[int(i)] += 1
	var inside := func(h) -> bool: return h >= b0 and h < b1
	var pick := func(need: int) -> Dictionary:
		var hs := {}
		for h in 24:
			if count[h] >= need:
				for x in [h, (h + 23) % 24]:
					if inside.call(x):
						hs[x] = true
		return hs
	var hours: Dictionary = pick.call(2 if st.size() >= 6 else 1)
	if hours.is_empty():
		hours = pick.call(1)
	var busiest := func(ok: Callable) -> int:
		var t := -1
		for h in 24:
			if count[h] > 0 and ok.call(h) and (t < 0 or count[h] >= count[t]):
				t = h
		return t
	var top: int = busiest.call(inside)
	if top < 0:
		top = busiest.call(func(_h): return true)
	var in_top := []
	for x in st:
		if floorf(_num(x[1]) / 60.0) == top:
			in_top.append(_num(x[1]))
	in_top = _sorted(in_top, func(a, b): return a - b)
	var mid := int(floorf((in_top.size() - 1) / 2.0))
	var main: float = (in_top[mid] if mid >= 0 and mid < in_top.size() else top * 60.0) - _num(C.get("lead"))
	if hours.is_empty():
		var to_end := _mod(top - (b1 - 1) + 24, 24)
		var to_start := _mod(b0 - top + 24, 24)
		var h := b1 - 1 if to_end <= to_start else b0
		hours[int(h)] = true
		main = h * 60 + (0.0 if h == b0 else 30.0)
	main = _max(b0 * 60, _min(b1 * 60 - 1, main))
	if not _has_hour(hours, floorf(main / 60.0)):
		var hs := _sorted(hours.keys(), func(a, b): return a - b)
		var h = hs.back()
		for x in hs:
			if x * 60 > main:
				h = x
				break
		main = h * 60.0 if h * 60 > main else h * 60.0 + 59
	return {"hours": hours, "main": _n(main), "learned": true}
static func first_allowed(win: Dictionary, t = null):
	var x = t
	for i in 72:
		var p := _parts(x)
		if _has_hour(win.get("hours"), p[3] if not p.is_empty() else NAN):
			return x
		x = next_hour(x)
	return t
static func window_text(win: Dictionary) -> Dictionary:
	var hh := func(m) -> String: return "%s:%s" % [_pad2(floorf(_num(m) / 60.0)), _pad2(_mod(_num(m), 60.0))]
	var hs := _sorted(_hour_list(win.get("hours")), func(a, b): return _num(a) - _num(b))
	var out := []
	for h in hs:
		var r = out.back() if not out.is_empty() else null
		if r != null and _eq(r[1], h):
			r[1] = _n(_num(h) + 1)
		else:
			out.append([h, _n(_num(h) + 1)])
	var parts := []
	for r in out:
		parts.append("%s-%s" % [_str(r[0]), _str(r[1])])
	return {"main": hh.call(win.get("main")), "hours": ", ".join(parts), "learned": win.get("learned")}
static func create_notify() -> Dictionary:
	return {"plan": [], "ignored": 0}
static func note_return(s: Dictionary, t = null, tapped = "", o: Dictionary = {}) -> void:
	t = _num(_t(t))
	var plan: Array = s.plan if s.get("plan") is Array else []
	var due := []
	for p in plan:
		if _num(_prop(p, "at")) <= t:
			due.append(p)
	var respond := _num(o.get("respond"))
	if not _truthy(respond):
		respond = 0.0
	var responded := false
	if respond > 0:
		for p in due:
			if t - _num(_prop(p, "at")) <= respond * 60e3:
				responded = true
	if _truthy(tapped) or responded:
		s["ignored"] = 0
	elif not _eq(o.get("enabled"), false):
		s["ignored"] = _n(_f0(s.get("ignored")) + due.size())
	s["plan"] = []
static func plan_notifications(o: Dictionary = {}) -> Dictionary:
	var t := _num(_qq(o.get("now"), _now()))
	var C := NOTIFY_DEFAULTS.duplicate()
	if o.get("config") is Dictionary:
		C.merge(o.config, true)
	var win := play_window(o.get("starts"), C, _truthy(o.get("fixed")))
	var off := _list(_qq(o.get("off"), C.get("off")))
	var quiet: bool = _f0(o.get("ignored")) >= _num(C.get("quiet"))
	var cap := 1.0 if quiet else _max(1.0, _num(_qq(o.get("cap"), C.get("cap"))))
	var comeback_days := []
	for x in _str(_qq(o.get("comeback"), C.get("comeback"))).split(","):
		var n := _str_to_num(x)
		if is_finite(n) and n >= 2:
			comeback_days.append(n)
	var prefix := _str(_qq(o.get("comebackPrefix"), "comeback"))
	var written: Array = o.comebackKinds if o.get("comebackKinds") is Array and not o.comebackKinds.is_empty() else [2, 3, 7, 14]
	var prio: Array = _or(o.get("priority"), [])
	var rank := func(k) -> float:
		var i := _index_of(prio, k)
		return float(prio.size()) if i < 0 else float(i)
	var dropped := []
	var cand := []
	var add := func(c, at) -> void:
		var kind = _prop(c, "kind")
		if _includes(off, kind):
			dropped.append({"kind": kind, "at": at, "why": "off"})
		elif quiet and _truthy(_prop(c, "optional")):
			dropped.append({"kind": kind, "at": at, "why": "quiet"})
		else:
			cand.append({"kind": kind, "at": at})
	var habit := func(n):
		var x := _num(at_day(t, n, win.main))
		return _n(x) if x - t >= HOUR else null
	for c in _or(o.get("candidates"), []):
		if not _truthy(c) or not _truthy(_prop(c, "kind")):
			continue
		var c_at = _prop(c, "at")
		if c_at != null:
			if _is_fin(c_at):
				add.call(c, first_allowed(win, c_at))
			continue
		var at = null
		var d = _prop(c, "day")
		for n in (d if d is Array else ([] if d == null else [d])):
			at = habit.call(n)
			if at != null:
				break
		if at != null:
			add.call(c, at)
	cand = _sorted(cand, func(a, b): return _num(a.at) - _num(b.at))
	var groups := []
	var merge_ms := _num(C.get("merge")) * HOUR
	for c in cand:
		var g = groups.back() if not groups.is_empty() else null
		if g != null and _num(c.at) - _num(g.at) < merge_ms:
			g.at = _n(_max(_num(g.at), _num(c.at)))
			g.kinds.append(c.kind)
		else:
			groups.append({"at": c.at, "kinds": [c.kind]})
	for g in groups:
		g.kinds = _sorted(g.kinds, func(a, b): return rank.call(a) - rank.call(b))
	var out := []
	var per_day := {}
	var today := day_key(t)
	var by_rank := func(a, b) -> float:
		var r: float = rank.call(a.kinds[0]) - rank.call(b.kinds[0])
		return r if _truthy(r) else _num(a.at) - _num(b.at)
	for g in _sorted(groups, by_rank):
		var d := _num(day_diff(today, day_key(g.at)))
		if d >= 2:
			dropped.append({"kind": g.kinds[0], "at": g.at, "why": "late"})
			continue
		var dk := _num_str(d)
		if _f0(per_day.get(dk)) >= cap:
			dropped.append({"kind": g.kinds[0], "at": g.at, "why": "cap"})
			continue
		per_day[dk] = _f0(per_day.get(dk)) + 1
		out.append({"kind": g.kinds[0], "kinds": g.kinds, "at": g.at})
	var near := func(n: float):
		var a = written[0]
		for i in range(1, written.size()):
			if absf(_num(written[i]) - n) < absf(_num(a) - n):
				a = written[i]
		return a
	for n in comeback_days:
		var kind := "%s_%s" % [prefix, _str(near.call(n))]
		var at = at_day(t, n, win.main)
		if _includes(off, kind):
			dropped.append({"kind": kind, "at": at, "why": "off"})
			continue
		out.append({"kind": kind, "kinds": [kind], "at": at, "away": _n(n)})
	out = _sorted(out, func(a, b): return _num(a.at) - _num(b.at))
	var screen = o.get("screen")
	var channel = o.get("channel")
	var text = o.get("text")
	var number = o.get("number")
	for n in out:
		var tx = _inv(text, [n]) if text is Callable else null
		n["title"] = _qq(_prop(tx, "title"), "")
		n["body"] = _qq(_prop(tx, "body"), "")
		n["screen"] = _inv(screen, [n.kind]) if screen is Callable else _qq(_prop(screen, _key(n.kind)), "menu")
		n["channel"] = _inv(channel, [n.kind]) if channel is Callable else ("comeback" if _str(n.kind).begins_with(prefix) else "rewards")
		if number is Callable:
			var v := _num(_inv(number, [n.at, n]))
			n["number"] = _n(_max(1.0, v if _truthy(v) else 0.0))
	return {"list": out, "dropped": dropped, "win": win, "quiet": quiet}
static func _plan_list(plan) -> Array:
	if plan is Dictionary and _truthy(plan.get("list")):
		return plan.list
	return plan if plan is Array else []
static func to_reminders(plan = null) -> Array:
	var out := []
	for n in _plan_list(plan):
		var r := {"id": n.get("kind"), "at": n.get("at"), "title": n.get("title"), "body": n.get("body"), "screen": n.get("screen"), "channel": n.get("channel")}
		if n.get("number") != null:
			r["number"] = n.number
		out.append(r)
	return out
static func plan_record(plan = null) -> Array:
	var out := []
	for n in _plan_list(plan):
		out.append({"k": n.get("kind"), "at": n.get("at")})
	return out
static func apply_config(target: Dictionary, rc = {}, prefix = "", query = "") -> Dictionary:
	var pre := _str(_qq(prefix, ""))
	var set := func(k, v) -> void:
		if not target.has(k) or _eq(v, "") or v == null:
			return
		var cur = target[k]
		match typeof(cur):
			TYPE_INT, TYPE_FLOAT:
				var n := _num(v)
				if is_finite(n) and n >= 0:
					target[k] = _n(n)
			TYPE_BOOL:
				var s := _trim(_str(v)).to_lower()
				if s == "1" or s == "true":
					target[k] = true
				elif s == "0" or s == "false":
					target[k] = false
			_:
				target[k] = _str(v)
	if rc is Dictionary:
		for k in rc:
			var ks := _str(k)
			if ks.begins_with(pre):
				set.call(ks.substr(pre.length()), rc[k])
	for m in _re("([A-Za-z0-9_]+):([^\\n\\r\\x{2028}\\x{2029}]*?)(?=,[A-Za-z0-9_]+:|\\z)").search_all(_str(query) if _truthy(query) else ""):
		set.call(m.get_string(1), m.get_string(2))
	return target
static func clean_params(p = null) -> Dictionary:
	var out := {}
	if not (p is Dictionary):
		return out
	for k in p:
		var v = p[k]
		match typeof(v):
			TYPE_NIL:
				pass
			TYPE_INT, TYPE_FLOAT:
				out[k] = _n(_round(float(v) * 100.0) / 100.0)
			TYPE_BOOL:
				out[k] = 1 if v else 0
			_:
				out[k] = _slice16(_str(v), 100)
	return out
static func create_analytics(o: Dictionary = {}) -> Analytics:
	var a := Analytics.new()
	a._o = o
	var st = o.get("state")
	a.state = st if st is Dictionary else {}
	if not (a.state.get("log") is Array):
		a.state["log"] = []
	if not (a.state.get("counts") is Dictionary):
		a.state["counts"] = {}
	if not (a.state.get("ftue") is Dictionary):
		a.state["ftue"] = {}
	a._max = _qq(o.get("max"), 80)
	a._steps = _or(o.get("steps"), [])
	return a
class Analytics extends RefCounted:
	var state: Dictionary = {}
	var log: Array:
		get:
			return state.log
	var counts: Dictionary:
		get:
			return state.counts
	var _o: Dictionary = {}
	var _max = 80
	var _steps: Array = []
	var _subs: Array = []
	func _now():
		var f = _o.get("now")
		return f.call() if f is Callable else _SELF.clock.now()
	func track(name, params = {}) -> Dictionary:
		var ctx = {}
		var ctx_fn = _o.get("ctx")
		if ctx_fn is Callable:
			ctx = ctx_fn.call()
			if not (ctx is Dictionary):
				ctx = {}
		var merged: Dictionary = ctx.duplicate()
		if _SELF._truthy(_o.get("build")):
			merged["build"] = _o.build
		if params is Dictionary:
			merged.merge(params, true)
		var p := _SELF.clean_params(merged)
		state.log.append({"n": name, "t": _now(), "p": p})
		var mx := _SELF._num(_max)
		if state.log.size() > mx:
			for i in int(clampf(state.log.size() - mx, 0, state.log.size())):
				state.log.pop_front()
		var key = _SELF._key(name)
		state.counts[key] = _SELF._n(_SELF._f0(state.counts.get(key)) + 1.0)
		var sink_log := _SELF._fn(_o.get("sink"), "log")
		if sink_log.is_valid():
			_SELF._inv(sink_log, [name, p])
		var debug = _o.get("debug")
		if debug is Callable:
			_SELF._inv(debug, [name, p])
		elif _SELF._truthy(debug):
			print("[an] ", name, " ", JSON.stringify(p))
		var i := 0
		while i < _subs.size():
			_SELF._inv(_subs[i], [name, p])
			i += 1
		return p
	func on_track(fn: Callable) -> Callable:
		_subs.append(fn)
		return func() -> void:
			var i := _subs.find(fn)
			if i >= 0:
				_subs.remove_at(i)
	func ftue(step) -> bool:
		var key = _SELF._key(step)
		if state.ftue.get(key) != null:
			return false
		var ia = _o.get("installAt")
		var install := _SELF._f0(ia.call() if ia is Callable else ia)
		var sec := _SELF._max(0.0, (_SELF._num(_now()) - install) / 1000.0)
		state.ftue[key] = _SELF._n(_SELF._round(sec))
		track("ftue_step", {"step": step, "step_i": _SELF._index_of(_steps, step), "sec": sec})
		return true
	func set_user_props(props) -> void:
		var f := _SELF._fn(_o.get("sink"), "user")
		if f.is_valid():
			_SELF._inv(f, [props])
static func create_codes() -> Dictionary:
	return {"used": []}
static func norm_code(s = null) -> String:
	return _re("[^A-Z0-9]").sub(_upper(_str(_qq(s, ""))), "", true).substr(0, 32)
const _UPPER_SPECIAL := {"ß": "SS", "ŉ": "ʼN", "ǰ": "J̌", "ẖ": "H̱", "ẗ": "T̈", "ẘ": "W̊", "ẙ": "Y̊", "ẚ": "Aʾ",
		"ﬀ": "FF", "ﬁ": "FI", "ﬂ": "FL", "ﬃ": "FFI", "ﬄ": "FFL", "ﬅ": "ST", "ﬆ": "ST"}
static func _upper(s: String) -> String:
	var out := ""
	for ch in s:
		out += _UPPER_SPECIAL.get(ch, ch)
	return out.to_upper()
static func _when(v) -> float:
	if v == null or _eq(v, ""):
		return NAN
	if v is int or v is float:
		return float(v)
	return _date_parse(v)
static func code_table(table = null) -> Dictionary:
	var t = table
	if t is String:
		if _trim(t) == "":
			t = {}
		else:
			var j := JSON.new()
			t = j.data if j.parse(t) == OK else {}
	var out := {}
	if not (t is Dictionary):
		return out
	for k in t:
		var c := norm_code(k)
		if c != "" and _truthy(t[k]) and (t[k] is Dictionary or t[k] is Array):
			out[c] = t[k]
	return out
static func redeem_code(s: Dictionary, input = null, table = null, o: Dictionary = {}) -> Dictionary:
	var code := norm_code(input)
	if code == "":
		return {"ok": false, "code": code, "why": "empty"}
	if not (s.get("used") is Array):
		s["used"] = []
	var e = code_table(table).get(code)
	if e == null:
		return {"ok": false, "code": code, "why": "unknown"}
	if _includes(s.used, code):
		return {"ok": false, "code": code, "why": "used"}
	var t := _num(_qq(o.get("now"), _now()))
	var from := _when(_prop(e, "from"))
	var to := _when(_prop(e, "to"))
	if is_finite(from) and t < from:
		return {"ok": false, "code": code, "why": "early"}
	if is_finite(to) and t >= to:
		return {"ok": false, "code": code, "why": "expired"}
	var caps: Dictionary = _or(o.get("caps"), {})
	var never: Array = _qq(o.get("never"), ["gems"])
	var reward := {}
	var keys: Array = e.keys() if e is Dictionary else range(e.size())
	for k in keys:
		var ks: String = _key(k)
		if ks == "from" or ks == "to" or _includes(never, ks) or not caps.has(ks):
			continue
		var n := floorf(_min(_num(e[k]), _num(caps[ks])))
		if is_finite(n) and n > 0:
			reward[ks] = _n(n)
	if reward.is_empty():
		return {"ok": false, "code": code, "why": "nothing"}
	s.used.append(code)
	var keep := _num(_qq(o.get("keep"), 200))
	if s.used.size() > keep:
		for i in int(clampf(s.used.size() - keep, 0, s.used.size())):
			s.used.pop_front()
	return {"ok": true, "code": code, "reward": reward}
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
