class_name EnemyBolt
extends HitboxComponent
## Projétil do boss: voa em linha reta na direção dada e some ao acertar o
## player, parede ou expirar. Mesma base de dano da HitboxComponent.

const SPEED := 130.0
const LIFETIME := 3.0

var direction := Vector2.RIGHT

var _age := 0.0


func _ready() -> void:
	super()
	rotation = direction.angle()
	area_entered.connect(func(_a: Area2D) -> void: _vanish())
	body_entered.connect(func(_b: Node2D) -> void: _vanish())


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_age += delta
	if _age > LIFETIME:
		queue_free()


func _vanish() -> void:
	queue_free.call_deferred()
