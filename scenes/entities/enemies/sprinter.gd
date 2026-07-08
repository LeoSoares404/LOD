class_name Sprinter
extends CharacterBody2D
## Sprinter: igual ao Ghoul (persegue em linha reta, dano por contato) mas
## bem mais rápido e com pouquíssima vida — pressiona o player a se mexer
## em vez de tankar.

const SPEED := 135.0
const STOP_DISTANCE := 4.0  # px — não fica "empurrando" em cima do alvo
const KNOCKBACK_DECAY := 600.0  # px/s² — quão rápido o empurrão dissipa
const STUN_TINT := Color(0.6, 0.8, 1.6)  # azul brilhante enquanto atordoado
const IDLE_TINT := Color(1.4, 0.7, 0.7)  # tom avermelhado — diferencia do Ghoul sem sprite novo

const DAMAGE_NUMBER_SCENE := preload("res://scenes/fx/damage_number.tscn")

const ANIM_FPS := 10.0  # anima mais rápido que o ghoul, combina com a velocidade

var _knockback := Vector2.ZERO
var _stun_time := 0.0
var _anim_time := 0.0

@onready var _sprite: Sprite2D = $Sprite

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
			modulate = IDLE_TINT
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
	_animate(delta, chase.length() > 1.0)


func _animate(delta: float, walking: bool) -> void:
	if walking:
		_anim_time += delta
		@warning_ignore("integer_division")
		_sprite.frame = 1 + int(_anim_time * ANIM_FPS) % 4
		if absf(velocity.x) > 0.5:
			_sprite.flip_h = velocity.x < 0
	else:
		_anim_time = 0.0
		_sprite.frame = 0


func _on_hit_received(hitbox: HitboxComponent) -> void:
	if hitbox.stun_duration > 0.0:
		_stun_time = hitbox.stun_duration
	if _stun_time > 0.0:
		modulate = STUN_TINT  # tom azul estável enquanto atordoado
	else:
		modulate = Color(3.0, 3.0, 3.0)  # hit-flash branco
		create_tween().tween_property(self, "modulate", IDLE_TINT, 0.15)
	if hitbox.knockback_force > 0.0:
		_knockback = (global_position - hitbox.global_position).normalized() * hitbox.knockback_force

	# mostra número de dano
	var dmg_num = DAMAGE_NUMBER_SCENE.instantiate()
	dmg_num.text = "-%d" % hitbox.damage
	dmg_num.position = global_position + Vector2(randf_range(-10, 10), -30)
	get_tree().current_scene.add_child(dmg_num)


func _on_died() -> void:
	EventBus.enemy_died.emit(null, global_position)
	queue_free.call_deferred()  # morte pode vir de callback de física
