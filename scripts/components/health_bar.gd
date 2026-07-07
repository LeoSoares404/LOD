class_name HealthBar
extends Node2D
## Barra de vida flutuante minimalista. Aparece só quando a vida não está cheia.

@export var health: HealthComponent
@export var width := 16.0
@export var height := 2.0

var _ratio := 1.0


func _ready() -> void:
	visible = false
	health.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, max_health: int) -> void:
	_ratio = float(current) / float(max_health)
	visible = _ratio < 1.0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-width / 2, -height / 2, width, height), Color(0.05, 0.08, 0.09, 0.85))
	draw_rect(Rect2(-width / 2, -height / 2, width * _ratio, height), Color(0.78, 0.16, 0.18))
