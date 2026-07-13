class_name EnemyBolt
extends HitboxComponent
## Projétil do boss: voa em linha reta na direção dada e some ao acertar o
## player, parede ou expirar. Mesma base de dano da HitboxComponent.

const SPEED := 8.1   # m/s (era 130 px/s)
const LIFETIME := 3.0
const HELL_FIRE_DAMAGE := 2   # no inferno, TODO tiro ranged (daniel + boss) pega fogo

var direction := Vector3.RIGHT

var _age := 0.0


func _ready() -> void:
	if GameState.hell_active:
		fire_damage = HELL_FIRE_DAMAGE
	super()
	area_entered.connect(func(_a: Area3D) -> void: _vanish())
	body_entered.connect(func(_b: Node3D) -> void: _vanish())


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_age += delta
	if _age > LIFETIME:
		queue_free()


func _vanish() -> void:
	queue_free.call_deferred()
