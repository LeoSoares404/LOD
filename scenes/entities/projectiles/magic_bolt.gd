class_name MagicBolt
extends HitboxComponent
## Projétil mágico: herda o dano/knockback da HitboxComponent e adiciona
## voo em linha reta. Some ao acertar hurtbox, parede ou expirar.

const SPEED := 220.0
const LIFETIME := 1.2  # s (~264 px de alcance)

var direction := Vector2.RIGHT

var _age := 0.0


func _ready() -> void:
	super()
	rotation = direction.angle()
	# a base (HitboxComponent) já aplicou o dano no area_entered; aqui só some
	area_entered.connect(func(_area: Area2D) -> void: _vanish())
	body_entered.connect(func(_body: Node2D) -> void: _vanish())  # parede


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_age += delta
	if _age > LIFETIME:
		queue_free()


func _vanish() -> void:
	queue_free.call_deferred()
