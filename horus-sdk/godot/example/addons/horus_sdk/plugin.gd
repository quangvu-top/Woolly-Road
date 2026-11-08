# Horus SDK for Godot 0.2.1 (Horus SDK 0.30.2, Godot 4.7.2) | (c) Horus Entertainment
@tool
extends EditorPlugin
func _enable_plugin() -> void:
	add_autoload_singleton("Horus", "res://addons/horus_sdk/horus.gd")
func _disable_plugin() -> void:
	remove_autoload_singleton("Horus")
