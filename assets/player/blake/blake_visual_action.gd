extends "res://Modular-Character-Controller-for-Godot-bce61c2ab0c317a32512daea65519e597cda72e7/addons/modular_character_controller/scripts/action_node.gd"

# Reuse the downloaded action system for presentation; combat stays on the player.
func _on_play(params: Dictionary = {}) -> void:
	get_parent().get_parent().play_clip(params["clip"], params.get("speed", 1.0))
