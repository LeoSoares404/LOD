extends Node
## Estado global da run (autoload "GameState").

var current_wave: int = 0
var control_scheme: String = "mouse"  # "mouse" (click-to-move) ou "wasd" — trocado no menu de Configurações


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
