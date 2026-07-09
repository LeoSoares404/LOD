class_name MagicBolt
extends HitboxComponent
## Projétil do auto-attack: herda o dano/knockback da HitboxComponent e adiciona
## voo em linha reta no plano XZ. Some ao acertar hurtbox, parede ou expirar.
## Duas caras: orbe arcano (mago, padrão da cena) ou flecha rasante (arqueiro).

const SPEED := 13.75  # m/s (era 220 px/s)
const ARROW_SPEED := 20.0  # flecha do arqueiro voa mais rápido que o orbe
const LIFETIME := 1.2  # s (~16,5 m de alcance)

var direction := Vector3.RIGHT
## Definido pelo Player ANTES do add_child (o _ready lê pra montar o visual).
var is_arrow := false

var _speed := SPEED
var _age := 0.0


func _ready() -> void:
	super()
	# a base (HitboxComponent) já aplicou o dano no area_entered; aqui só some
	area_entered.connect(func(_area: Area3D) -> void: _vanish())
	body_entered.connect(func(_body: Node3D) -> void: _vanish())  # parede
	if is_arrow:
		_become_arrow()


## Flecha: risco dourado fino, deitado no chão e apontado na direção do voo —
## bem diferente do orbe roxo redondo e billboard do mago.
func _become_arrow() -> void:
	_speed = ARROW_SPEED
	var spr: Sprite3D = $Sprite
	spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# euler YXZ do Godot: o X (-90°) deita o sprite, o Y depois gira no chão
	spr.rotation = Vector3(-PI / 2.0, atan2(-direction.x, -direction.z), 0.0)
	spr.scale = Vector3(0.022, 0.115, 1.0)  # fina e comprida
	spr.modulate = Color(3.0, 2.4, 0.9, 1.0)
	var light: OmniLight3D = $Light
	light.light_color = Color(1.0, 0.85, 0.45)
	light.omni_range = 2.5


func _physics_process(delta: float) -> void:
	position += direction * _speed * delta
	_age += delta
	if _age > LIFETIME:
		queue_free()


func _vanish() -> void:
	queue_free.call_deferred()
