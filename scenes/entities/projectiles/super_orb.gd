class_name SuperOrb
extends Area3D
## Bola de energia do superataque: viaja até o alvo e explode ao tocar,
## causando dano apenas na explosão (não no projétil em si).

const SPEED := 20.0  # m/s
const LIFETIME := 5.0
const EXPLOSION_SCENE := preload("res://scenes/entities/projectiles/meteor_explosion.tscn")

var target: Vector3
var damage := 50
var stun_duration := 1.5

var _age := 0.0


func _ready() -> void:
	area_entered.connect(func(_a: Area3D) -> void: _explode())
	body_entered.connect(func(_b: Node3D) -> void: _explode())


func _physics_process(delta: float) -> void:
	var direction = (target - global_position).normalized()
	position += direction * SPEED * delta

	_age += delta
	if _age > LIFETIME:
		queue_free()


func _explode() -> void:
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.damage = damage
	explosion.stun_duration = stun_duration
	explosion.position = global_position
	get_tree().current_scene.add_child(explosion)
	queue_free()
