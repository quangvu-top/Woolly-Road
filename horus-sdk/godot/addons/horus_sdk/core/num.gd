# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const BITS := 28
const BASE := 1 << BITS
const MASK := BASE - 1
const HIDDEN := 1 << 52
static var _bytes := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
static var _pow10 := _exact_powers()
static func _exact_powers() -> Array:
	var p := [1.0]
	for i in 22:
		p.append(p.back() * 10.0)
	return p
static func bits_of(f: float) -> int:
	_bytes.encode_double(0, f)
	return _bytes.decode_s64(0)
static func from_bits(n: int) -> float:
	_bytes.encode_s64(0, n)
	return _bytes.decode_double(0)
static func _big(n: int) -> Array:
	var a := []
	while n > 0:
		a.append(n & MASK)
		n >>= BITS
	return a
static func _mul_small(a: Array, k: int) -> Array:
	var out := []
	out.resize(a.size())
	var carry := 0
	for i in a.size():
		var t: int = a[i] * k + carry
		out[i] = t & MASK
		carry = t >> BITS
	while carry > 0:
		out.append(carry & MASK)
		carry >>= BITS
	return out
static func _mul10(a: Array) -> void:
	var carry := 0
	for i in a.size():
		var t: int = a[i] * 10 + carry
		a[i] = t & MASK
		carry = t >> BITS
	if carry > 0:
		a.append(carry)
static func _top(a: Array, lo: int) -> float:
	var v := 0.0
	for i in range(a.size() - 1, lo - 1, -1):
		v = v * BASE + a[i]
	return v
static func _times_pow10(a: Array, n: int) -> Array:
	while n >= 9:
		a = _mul_small(a, 1000000000)
		n -= 9
	if n > 0:
		a = _mul_small(a, int(_pow10[n]))
	return a
static func _shl(a: Array, n: int) -> Array:
	if a.is_empty():
		return []
	var out := []
	out.resize(n / BITS)
	out.fill(0)
	var b := n % BITS
	var carry := 0
	for x in a:
		var t: int = (x << b) | carry
		out.append(t & MASK)
		carry = t >> BITS
	if carry > 0:
		out.append(carry)
	return out
static func _shr1(a: Array) -> void:
	for i in a.size():
		var low: int = (a[i + 1] & 1) << (BITS - 1) if i + 1 < a.size() else 0
		a[i] = (a[i] >> 1) | low
	while not a.is_empty() and a.back() == 0:
		a.pop_back()
static func _add(a: Array, b: Array) -> Array:
	var n := maxi(a.size(), b.size())
	var out := []
	out.resize(n)
	var carry := 0
	for i in n:
		var t: int = (a[i] if i < a.size() else 0) + (b[i] if i < b.size() else 0) + carry
		out[i] = t & MASK
		carry = t >> BITS
	if carry > 0:
		out.append(carry)
	return out
static func _sub(a: Array, b: Array) -> void:
	var borrow := 0
	for i in a.size():
		var t: int = a[i] - (b[i] if i < b.size() else 0) - borrow
		borrow = 1 if t < 0 else 0
		a[i] = t + BASE if t < 0 else t
	while not a.is_empty() and a.back() == 0:
		a.pop_back()
static func _cmp(a: Array, b: Array) -> int:
	if a.size() != b.size():
		return 1 if a.size() > b.size() else -1
	for i in range(a.size() - 1, -1, -1):
		if a[i] != b[i]:
			return 1 if a[i] > b[i] else -1
	return 0
static func _bitlen(a: Array) -> int:
	if a.is_empty():
		return 0
	var top: int = a.back()
	var n := 0
	while top > 0:
		top >>= 1
		n += 1
	return (a.size() - 1) * BITS + n
static func _divmod(n: Array, d: Array) -> Array:
	var r := n.duplicate()
	var shift := _bitlen(n) - _bitlen(d)
	var q := 0
	if shift < 0:
		return [0, r]
	var ds := _shl(d, shift)
	for i in range(shift, -1, -1):
		if _cmp(r, ds) >= 0:
			_sub(r, ds)
			q |= 1 << i
		_shr1(ds)
	return [q, r]
static func shortest(f: float) -> Array:
	var bits := bits_of(f)
	var be := (bits >> 52) & 0x7ff
	var m := bits & (HIDDEN - 1)
	var e := -1074
	if be != 0:
		m |= HIDDEN
		e = be - 1075
	var even := (m & 1) == 0
	var r: Array
	var s: Array
	var mp: Array
	var mm: Array
	if e >= 0:
		if m != HIDDEN:
			r = _shl(_big(m), e + 1)
			s = _big(2)
			mp = _shl(_big(1), e)
			mm = mp.duplicate()
		else:
			r = _shl(_big(m), e + 2)
			s = _big(4)
			mp = _shl(_big(1), e + 1)
			mm = _shl(_big(1), e)
	elif be <= 1 or m != HIDDEN:
		r = _big(m * 2)
		s = _shl(_big(1), 1 - e)
		mp = _big(1)
		mm = _big(1)
	else:
		r = _big(m * 4)
		s = _shl(_big(1), 2 - e)
		mp = _big(2)
		mm = _big(1)
	var k := int(ceil(log(f) / log(10.0) - 1e-10))
	if k >= 0:
		s = _times_pow10(s, k)
	else:
		r = _times_pow10(r, -k)
		mp = _times_pow10(mp, -k)
		mm = _times_pow10(mm, -k)
	var hi := _cmp(_add(r, mp), s)
	if hi > 0 or (hi == 0 and even):
		s = _mul_small(s, 10)
		k += 1
	var digits := PackedStringArray()
	while true:
		_mul10(r)
		_mul10(mp)
		_mul10(mm)
		var top := maxi(s.size() - 3, 0)
		var d := clampi(int(_top(r, top) / _top(s, top)), 0, 9)
		if d > 0:
			var ds := _mul_small(s, d)
			if _cmp(r, ds) < 0:
				d -= 1
				ds = _mul_small(s, d)
			_sub(r, ds)
		while _cmp(r, s) >= 0:
			_sub(r, s)
			d += 1
		var lo := _cmp(r, mm)
		var low := lo < 0 or (lo == 0 and even)
		var up := _cmp(_add(r, mp), s)
		var high := up > 0 or (up == 0 and even)
		if not low and not high:
			digits.append(str(d))
			continue
		if low and high:
			var c := _cmp(_shl(r, 1), s)
			if c > 0 or (c == 0 and d % 2 == 1):
				d += 1
		elif high:
			d += 1
		digits.append(str(d))
		break
	return ["".join(digits), k]
static func _short_fast(f: float) -> Array:
	if f < 1e-7 or f >= 1e15:
		return []
	var e10 := int(floor(log(f) / log(10.0)))
	for sc in range(-e10 - 2, 17 - e10):
		if absi(sc) > 22:
			continue
		var d := roundf(f * _pow10[sc] if sc >= 0 else f / _pow10[-sc])
		if d < 1.0:
			continue
		if d >= 1e15:
			break
		if (d / _pow10[sc] if sc >= 0 else d * _pow10[-sc]) == f:
			var ds := str(int(d))
			return [ds.rstrip("0"), ds.length() - sc]
	return []
static func text(f: float) -> String:
	if f == 0.0:
		return "0"
	var neg := f < 0.0
	var a := absf(f)
	if a == floorf(a) and a <= 9007199254740992.0:
		return ("-" if neg else "") + str(int(a))
	var sh := _short_fast(a)
	if sh.is_empty():
		sh = shortest(a)
	var digits: String = sh[0]
	var n: int = sh[1]
	var k := digits.length()
	var out := ""
	if k <= n and n <= 21:
		out = digits + "0".repeat(n - k)
	elif 0 < n and n <= 21:
		out = digits.substr(0, n) + "." + digits.substr(n)
	elif -6 < n and n <= 0:
		out = "0." + "0".repeat(-n) + digits
	else:
		var x := n - 1
		out = digits[0] + ("." + digits.substr(1) if k > 1 else "") + "e" + ("+" if x >= 0 else "-") + str(absi(x))
	return ("-" + out) if neg else out
static func read(t: String) -> float:
	var n := t.length()
	var i := 0
	var neg := false
	if i < n and (t[i] == "-" or t[i] == "+"):
		neg = t[i] == "-"
		i += 1
	var digs := PackedStringArray()
	var any := false
	var shift := 0
	while i < n and t[i] >= "0" and t[i] <= "9":
		digs.append(t[i])
		any = true
		i += 1
	if i < n and t[i] == ".":
		i += 1
		while i < n and t[i] >= "0" and t[i] <= "9":
			digs.append(t[i])
			shift -= 1
			any = true
			i += 1
	if not any:
		return NAN
	var ex := 0
	if i < n and (t[i] == "e" or t[i] == "E"):
		i += 1
		var eneg := false
		if i < n and (t[i] == "-" or t[i] == "+"):
			eneg = t[i] == "-"
			i += 1
		var eany := false
		while i < n and t[i] >= "0" and t[i] <= "9":
			ex = mini(ex * 10 + t[i].to_int(), 100000000)
			eany = true
			i += 1
		if not eany:
			return NAN
		if eneg:
			ex = -ex
	if i != n:
		return NAN
	var d := "".join(digs).lstrip("0")
	var sign := -1.0 if neg else 1.0
	if d == "":
		return sign * 0.0
	var trimmed := d.rstrip("0")
	shift += d.length() - trimmed.length()
	d = trimmed
	var e10 := ex + shift
	if d.length() + e10 > 310:
		return sign * INF
	if d.length() + e10 < -326:
		return sign * 0.0
	if d.length() <= 15 and absi(e10) <= 22:
		var v := float(d.to_int())
		return sign * (v * _pow10[e10] if e10 >= 0 else v / _pow10[-e10])
	return sign * _read_near(d, e10)
static func _read_near(d: String, e10: int) -> float:
	var g := ("%se%d" % [d, e10]).to_float()
	if not (g > 0.0 and is_finite(g)):
		return _read_big(d, e10)
	var D := _digits(d)
	for _step in 4:
		var bits := bits_of(g)
		var be := (bits >> 52) & 0x7ff
		var m := bits & (HIDDEN - 1)
		var e := -1074
		if be != 0:
			m |= HIDDEN
			e = be - 1075
		var odd := (m & 1) == 1
		var hi := _cmp_scaled(D, e10, 2 * m + 1, e - 1)
		if hi > 0 or (hi == 0 and odd):
			g = from_bits(bits + 1)
			if is_inf(g):
				return g
			continue
		var lo := _cmp_scaled(D, e10, 4 * m - 1, e - 2) if m == HIDDEN and be > 1 else _cmp_scaled(D, e10, 2 * m - 1, e - 1)
		if lo < 0 or (lo == 0 and odd):
			g = from_bits(bits - 1)
			continue
		return g
	return _read_big(d, e10)
static func _cmp_scaled(D: Array, e10: int, M: int, k: int) -> int:
	var left := D
	var right := _big(M)
	if e10 >= 0:
		left = _times_pow10(left, e10)
	else:
		right = _times_pow10(right, -e10)
	if k >= 0:
		right = _shl(right, k)
	else:
		left = _shl(left, -k)
	return _cmp(left, right)
static func _digits(d: String) -> Array:
	var D := []
	var at := 0
	while at < d.length():
		var chunk := d.substr(at, 9)
		if not D.is_empty():
			D = _mul_small(D, int(_pow10[chunk.length()]))
		D = _add(D, _big(chunk.to_int()))
		at += 9
	return D
static func _read_big(d: String, e10: int) -> float:
	var D := _digits(d)
	var num := D
	var den := _big(1)
	if e10 >= 0:
		num = _times_pow10(D, e10)
	else:
		den = _times_pow10(den, -e10)
	var b := _bitlen(num) - _bitlen(den) - 53
	var q := 0
	var rem := []
	var dd := den
	for _try in 3:
		b = maxi(b, -1074)
		var nn := num
		dd = den
		if b >= 0:
			dd = _shl(den, b)
		else:
			nn = _shl(num, -b)
		var qr := _divmod(nn, dd)
		q = qr[0]
		rem = qr[1]
		if q >= (1 << 53):
			b += 1
		elif q < HIDDEN and b > -1074:
			b -= 1
		else:
			break
	var c := _cmp(_shl(rem, 1), dd)
	if c > 0 or (c == 0 and (q & 1) == 1):
		q += 1
	if q == (1 << 53):
		q = HIDDEN
		b += 1
	if b > 971:
		return INF
	if q >= HIDDEN:
		return from_bits(((b + 1075) << 52) | (q - HIDDEN))
	return from_bits(q)
