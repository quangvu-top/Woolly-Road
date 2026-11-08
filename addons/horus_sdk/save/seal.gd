# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const SEAL := "_seal"
const _M := 0xFFFFFFFF
static var _tail := RegEx.create_from_string("(,?)\"_seal\":\"([0-9a-f]{28})\"}\\z")
static func _mul(a: int, b: int) -> int:
	return ((((a * (b >> 16)) & 0xFFFF) << 16) + a * (b & 0xFFFF)) & _M
static func _h53(s: String, seed: int) -> String:
	var h1 := (0xdeadbeef ^ seed) & _M
	var h2 := (0x41c6ce57 ^ seed) & _M
	var b := s.to_utf16_buffer()
	var i := 0
	var n := b.size()
	while i < n:
		var c := b[i] | (b[i + 1] << 8)
		h1 = _mul(h1 ^ c, 2654435761)
		h2 = _mul(h2 ^ c, 1597334677)
		i += 2
	h1 = _mul(h1 ^ (h1 >> 16), 2246822507) ^ _mul(h2 ^ (h2 >> 13), 3266489909)
	h2 = _mul(h2 ^ (h2 >> 16), 2246822507) ^ _mul(h1 ^ (h1 >> 13), 3266489909)
	return "%014x" % ((h2 & 2097151) * 4294967296 + h1)
static func seal_of(json: String, key: String) -> String:
	return _h53("%s\n%s" % [key, json], 1) + _h53("%s\n%s" % [json, key], 7)
static func add_seal(json: String, key: String) -> String:
	var s := seal_of(json, key)
	if json == "{}":
		return "{\"%s\":\"%s\"}" % [SEAL, s]
	return "%s,\"%s\":\"%s\"}" % [json.substr(0, json.length() - 1), SEAL, s]
static func check_seal(raw: Variant, key: String) -> String:
	if not (raw is String):
		return "none"
	var m := _tail.search(raw)
	if m == null:
		return "broken" if raw.contains("\"%s\"" % SEAL) else "none"
	var at := m.get_start(0)
	if m.get_string(1) == "" and raw.substr(0, at) != "{":
		return "broken"
	var json: String = raw.substr(0, at) + "}" if m.get_string(1) != "" else "{}"
	return "ok" if seal_of(json, key) == m.get_string(2) else "broken"
