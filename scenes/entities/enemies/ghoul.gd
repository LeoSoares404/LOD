class_name Ghoul
extends CharacterBody3D
## Ghoul: persegue o player em linha reta no plano XZ e causa dano por contato
## (hitbox com tick). Perseguição direta por enquanto; NavigationAgent3D quando
## houver obstáculos que exijam desvio.

const SPEED := 3.4              # m/s (era 55 px/s)
const STOP_DISTANCE := 0.25     # m — não fica "empurrando" em cima do alvo
const KNOCKBACK_DECAY := 37.5   # m/s² — quão rápido o empurrão dissipa
const STUN_TINT := Color(0.6, 0.8, 1.6)  # azul brilhante enquanto atordoado

const DAMAGE_NUMBER_SCENE := preload("res://scenes/fx/damage_number.tscn")

const ANIM_FPS := 7.0

var _knockback := Vector3.ZERO
var _stun_time := 0.0
var _slow_time := 0.0
var _slow_factor := 0.0
var _anim_time := 0.0

@onready var _sprite: Sprite3D = $Sprite

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox

var _player: Node3D


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	if _slow_time > 0.0:
		_slow_time -= delta
	# atordoado: não persegue, só sofre o resíduo do empurrão
	if _stun_time > 0.0:
		_stun_time -= delta
		if _stun_time <= 0.0:
			_sprite.modulate = Color.WHITE
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
		move_and_slide()
		return

	var chase := Vector3.ZERO
	if _player != null and is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() > STOP_DISTANCE:
			chase = to_player.normalized() * SPEED * _slow_mult()
	velocity = chase + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()
	_animate(delta, chase.length() > 0.1)


func _animate(delta: float, walking: bool) -> void:
	if walking:
		_anim_time += delta
		_sprite.frame = 1 + int(_anim_time * ANIM_FPS) % 4
		if absf(velocity.x) > 0.05:
			_sprite.flip_h = velocity.x < 0
	else:
		_anim_time = 0.0
		_sprite.frame = 0


func _on_hit_received(hitbox: HitboxComponent) -> void:
	if hitbox.stun_duration > 0.0:
		_stun_time = hitbox.stun_duration
	if hitbox.slow_duration > 0.0:
		_slow_time = hitbox.slow_duration  # renova a duração (não acumula)
		_slow_factor = hitbox.slow_factor
	if _stun_time > 0.0:
		_sprite.modulate = STUN_TINT  # tom azul estável enquanto atordoado
	else:
		_sprite.modulate = Color(3.0, 3.0, 3.0)  # hit-flash branco
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if hitbox.knockback_force > 0.0 and hitbox.is_inside_tree():
		var away := global_position - hitbox.global_position
		away.y = 0.0
		_knockback = away.normalized() * hitbox.knockback_force

	# mostra número de dano (hits de dano 0, como slow puro da rapiera, não mostram)
	if hitbox.damage > 0:
		var dmg_num = DAMAGE_NUMBER_SCENE.instantiate()
		dmg_num.text = "-%d" % hitbox.damage
		dmg_num.position = global_position + Vector3(randf_range(-0.6, 0.6), 1.9, 0)
		get_tree().current_scene.add_child(dmg_num)


func _slow_mult() -> float:
	return 1.0 - _slow_factor if _slow_time > 0.0 else 1.0


func _on_died() -> void:
	EventBus.enemy_died.emit(null, global_position)
	queue_free.call_deferred()  # morte pode vir de callback de física
