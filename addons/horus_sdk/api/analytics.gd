# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends RefCounted
const Json := preload("res://addons/horus_sdk/core/json.gd")
const BALANCE_EVERY := 2000
var _p
var store_path := "user://horus/analytics.json"
var _balances := {}
var _balance_gen := 0
var _balance_waiting := false
var _blocked := false
static var _not_name := RegEx.create_from_string("[^A-Za-z0-9_]+")
static var _edges := RegEx.create_from_string("^_+|_+$")
func _init(platform) -> void:
	_p = platform
static func prop_name(s: Variant) -> String:
	var t := _not_name.sub(Json.js_trim(Json.js_string(s)), "_", true)
	return _edges.sub(t, "", true).to_lower().left(24)
func _send(kind: String, a, b = null) -> void:
	if _blocked:
		return
	if kind == "log":
		_p._post("an.log", {"n": a} if b == null else {"n": a, "p": b})
	else:
		_p._post("an.user", {"props": a})
func log(name: String, params: Variant = null) -> void:
	_send("log", name, params)
func user(props: Dictionary) -> void:
	_send("user", props)
func _read() -> Dictionary:
	if not FileAccess.file_exists(store_path):
		return {}
	var f := FileAccess.open(store_path, FileAccess.READ)
	var d = Json.parse(f.get_as_text() if f else "", {})
	return d if d is Dictionary else {}
func _write(o: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(store_path.get_base_dir())
	var f := FileAccess.open(store_path, FileAccess.WRITE)
	if f:
		f.store_string(Json.stringify(o))
func result(won: bool) -> void:
	var s := _read()
	var win := Json.to_int32(s.get("win")) + 1 if won else 0
	var lose := 0 if won else Json.to_int32(s.get("lose")) + 1
	s.win = win
	s.lose = lose
	_write(s)
	user({"win_streak": win, "lose_streak": lose})
func balance(name: Variant, amount: Variant) -> void:
	var k := prop_name(prop_name(name).left(16) + "_balance")
	var v := Json.to_number(amount)
	if k == "" or k == "balance" or not is_finite(v):
		return
	_balances[k] = int(Json.js_round(v))
	if not _balance_waiting:
		_balance_waiting = true
		var gen := _balance_gen
		(Engine.get_main_loop() as SceneTree).create_timer(BALANCE_EVERY / 1000.0, true, false, true).timeout.connect(func():
			if gen == _balance_gen:
				_flush_balances())
func _flush_balances() -> void:
	_balance_gen += 1
	_balance_waiting = false
	if not _balances.is_empty():
		var b := _balances
		_balances = {}
		user(b)
func earn(currency: Variant, value: Variant, source: Variant = "") -> void:
	var v := Json.js_round(Json.to_number(value))
	if v > 0:
		var p := {"virtual_currency_name": Json.js_string(currency), "value": int(v)}
		if Json.truthy(source):
			p.source = Json.js_string(source)
		_send("log", "earn_virtual_currency", p)
func spend(currency: Variant, value: Variant, item: Variant = "") -> void:
	var v := Json.js_round(Json.to_number(value))
	if v > 0:
		var p := {"virtual_currency_name": Json.js_string(currency), "value": int(v)}
		if Json.truthy(item):
			p.item_name = Json.js_string(item)
		_send("log", "spend_virtual_currency", p)
func block(on: bool) -> void:
	_blocked = on
	if on:
		_balances = {}
		_balance_gen += 1
		_balance_waiting = false
	_p._post("an.block", {"on": on})
func flush() -> void:
	_flush_balances()
func _start(rc: Dictionary, connection = null) -> void:
	var cv = rc.get("config_version")
	var cvs := Json.js_string(cv) if cv != null else "0"
	user({"config_version": cvs if cvs != "" else "0"})
	user({"connection_type": connection if connection is String and connection != "" else "unknown"})
