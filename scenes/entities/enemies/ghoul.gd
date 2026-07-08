class_name Ghoul
extends CharacterBody2D
## Ghoul: persegue o player em linha reta e causa dano por contato (hitbox
## com tick). Perseguição direta por enquanto; NavigationAgent2D quando houver
## obstáculos que exijam desvio.

const SPEED := 55.0
const STOP_DISTANCE := 4.0  # px — não fica "empurrando" em cima do alvo
const KNOCKBACK_DECAY := 600.0  # px/s² — quão rápido o empurrão dissipa
const STUN_TINT := Color(0.6, 0.8, 1.6)  # azul brilhante enquanto atordoado

var _knockback := Vector2.ZERO
var _stun_time := 0.0

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox

var _player: Node2D


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	# atordoado: não persegue, só sofre o resíduo do empurrão
	if _stun_time > 0.0:
		_stun_time -= delta
		if _stun_time <= 0.0:
			modulate = Color.WHITE
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
		move_and_slide()
		return

	var chase := Vector2.ZERO
	if _player != null and is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		if to_player.length() > STOP_DISTANCE:
			chase = to_player.normalized() * SPEED
	velocity = chase + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()


func _on_hit_received(hitbox: HitboxComponent) -> void:
	if hitbox.stun_duration > 0.0:
		_stun_time = hitbox.stun_duration
	if _stun_time > 0.0:
		modulate = STUN_TINT  # tom azul estável enquanto atordoado
	else:
		modulate = Color(3.0, 3.0, 3.0)  # hit-flash branco
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
	if hitbox.knockback_force > 0.0:
		_knockback = (global_position - hitbox.global_position).normalized() * hitbox.knockback_force


func _on_died() -> void:
	EventBus.enemy_died.emit(null, global_position)
	queue_free.call_deferred()  # morte pode vir de callback de física
