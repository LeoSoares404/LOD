class_name Ghoul
extends CharacterBody2D
## Ghoul: persegue o player em linha reta e causa dano por contato (hitbox
## com tick). Perseguição direta por enquanto; NavigationAgent2D quando houver
## obstáculos que exijam desvio.

const SPEED := 55.0
const STOP_DISTANCE := 4.0  # px — não fica "empurrando" em cima do alvo
const KNOCKBACK_DECAY := 600.0  # px/s² — quão rápido o empurrão dissipa

var _knockback := Vector2.ZERO

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox

var _player: Node2D


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	var chase := Vector2.ZERO
	if _player != null and is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		if to_player.length() > STOP_DISTANCE:
			chase = to_player.normalized() * SPEED
	velocity = chase + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()


func _on_hit_received(hitbox: HitboxComponent) -> void:
	# hit-flash: estoura branco (HDR) e volta ao normal
	modulate = Color(3.0, 3.0, 3.0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
	if hitbox.knockback_force > 0.0:
		_knockback = (global_position - hitbox.global_position).normalized() * hitbox.knockback_force


func _on_died() -> void:
	EventBus.enemy_died.emit(null, global_position)
	queue_free.call_deferred()  # morte pode vir de callback de física
