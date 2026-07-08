class_name Meteor
extends Node2D
## Um meteoro: marca de aviso no chão + rastro caindo do céu; no impacto instancia
## a explosão (dano em área) e some. `start_delay` escalona as quedas na chuva.

const WARN_TIME := 0.55
const EXPLOSION_SCENE := preload("res://scenes/entities/projectiles/meteor_explosion.tscn")
const GLOW := preload("res://assets/sprites/props/glow_gradient.tres")

@export var start_delay := 0.0

var _warn: Sprite2D
var _streak: Sprite2D


func _ready() -> void:
	visible = false
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	visible = true
	_begin()


func _begin() -> void:
	# marca de aviso elíptica no chão (perspectiva)
	_warn = Sprite2D.new()
	_warn.texture = GLOW
	_warn.modulate = Color(2.2, 0.4, 0.2, 0.2)
	_warn.scale = Vector2(0.34, 0.2)
	add_child(_warn)
	var pulse := create_tween().set_loops(2)  # finito: cobre ~WARN_TIME (evita loop infinito)
	pulse.tween_property(_warn, "modulate:a", 0.85, 0.14).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_warn, "modulate:a", 0.3, 0.14).set_trans(Tween.TRANS_SINE)

	# meteoro caindo do alto
	_streak = Sprite2D.new()
	_streak.texture = GLOW
	_streak.modulate = Color(3.0, 1.5, 0.5)
	_streak.scale = Vector2(0.16, 0.34)
	_streak.position = Vector2(-38, -170)
	add_child(_streak)
	create_tween().tween_property(_streak, "position", Vector2(0, -6), WARN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	get_tree().create_timer(WARN_TIME).timeout.connect(_impact)


func _impact() -> void:
	if is_instance_valid(_warn):
		_warn.queue_free()
	if is_instance_valid(_streak):
		_streak.queue_free()
	add_child(EXPLOSION_SCENE.instantiate())
	get_tree().create_timer(0.5).timeout.connect(func() -> void: queue_free())
