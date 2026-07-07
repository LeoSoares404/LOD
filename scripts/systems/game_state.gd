extends Node
## Estado global da run (autoload "GameState").

var current_wave: int = 0


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
