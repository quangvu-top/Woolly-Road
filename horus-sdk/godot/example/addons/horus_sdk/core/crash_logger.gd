# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
extends Logger
const MAX_REPORTS := 30
const SAME_EVERY_MS := 60000
var _sink: Callable
var _mutex := Mutex.new()
var _seen := {}
var _count := 0
func _init(sink: Callable) -> void:
	_sink = sink
func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING or error_type == ERROR_TYPE_SHADER:
		return
	var frames := 0
	for bt in script_backtraces:
		frames += bt.get_frame_count()
	if error_type != ERROR_TYPE_SCRIPT and frames == 0 and function != "push_error":
		return
	var msg := code
	if rationale != "":
		msg = rationale if code == "" else "%s: %s" % [code, rationale]
	var stack := PackedStringArray()
	for bt in script_backtraces:
		if not bt.is_empty():
			stack.append(bt.format())
	if stack.is_empty():
		stack.append("%s (%s:%d)" % [function, file, line])
	var key := "%s|%s|%d" % [msg, file, line]
	var now := Time.get_ticks_msec()
	_mutex.lock()
	var go := _count < MAX_REPORTS and (not _seen.has(key) or now - int(_seen[key]) >= SAME_EVERY_MS)
	if go:
		_seen[key] = now
		_count += 1
	_mutex.unlock()
	if go and _sink.is_valid():
		_sink.call_deferred(msg, "\n".join(stack))
