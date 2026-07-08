class_name DashBoss
extends CharacterBody2D
## Boss 4 (melee): persegue devagar e, periodicamente, prevê onde o player vai
## estar, escancara o caminho em vermelho por um tempo de aviso e então
## dispara um dash reto e rápido naquela direção travada (não teleguiado —
## uma vez calculada, a direção não muda mesmo que o player desvie).

enum State { CHASE, TELEGRAPH, DASH, RECOVER }

const CHASE_SPEED := 40.0
const DASH_SPEED := 280.0
const DASH_DURATION := 1.0     # "1 segundo ele vai rapidamente para frente"
const TELEGRAPH_TIME := 0.7    # aviso do caminho em vermelho antes do dash
const RECOVER_TIME := 0.5
const DASH_COOLDOWN := 2.2     # tempo perseguindo até o próximo dash
const KNOCKBACK_DECAY := 500.0
const KNOCKBACK_RESIST := 0.25
const STUN_TINT := Color(0.7, 0.9, 1.6)
const TELEGRAPH_COLOR := Color(1.0, 0.15, 0.15, 0.6)
const FLOAT_AMP := 3.0
const FLOAT_SPEED := 3.2

const DAMAGE_NUMBER_SCENE := preload("res://scenes/fx/damage_number.tscn")

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var _sprite: Sprite2D = $Sprite

var _player: Node2D
var _knockback := Vector2.ZERO
var _stun_time := 0.0
var _anim_time := 0.0
var _base_spr_pos: Vector2
var _base_spr_scale: Vector2

var _state := State.CHASE
var _state_time := DASH_COOLDOWN
var _dash_dir := Vector2.RIGHT
var _telegraph_line: Line2D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_base_spr_pos = _sprite.position
	_base_spr_scale = _sprite.scale
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	if _stun_time > 0.0:
		_stun_time -= delta
		if _stun_time <= 0.0:
			modulate = Color.WHITE
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
		move_and_slide()
		return

	match _state:
		State.CHASE:
			_do_chase(delta)
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			move_and_slide()
			_state_time -= delta
			if _state_time <= 0.0:
				_start_dash()
		State.DASH:
			velocity = _dash_dir * DASH_SPEED
			move_and_slide()
			_state_time -= delta
			if _state_time <= 0.0:
				_end_dash()
		State.RECOVER:
			velocity = Vector2.ZERO
			move_and_slide()
			_state_time -= delta
			if _state_time <= 0.0:
				_state = State.CHASE
				_state_time = DASH_COOLDOWN

	# flutuação contínua — paira acima da base
	_anim_time += delta
	_sprite.position.y = _base_spr_pos.y - absf(sin(_anim_time * FLOAT_SPEED)) * FLOAT_AMP


func _do_chase(delta: float) -> void:
	var chase := Vector2.ZERO
	if _player != null and is_instance_valid(_player):
		chase = (_player.global_position - global_position)
		if chase.length() > 1.0:
			chase = chase.normalized() * CHASE_SPEED
	velocity = chase + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()

	_state_time -= delta
	if _state_time <= 0.0:
		_start_telegraph()


func _start_telegraph() -> void:
	if _player == null or not is_instance_valid(_player):
		_state_time = DASH_COOLDOWN
		return
	_state = State.TELEGRAPH
	_state_time = TELEGRAPH_TIME

	# prevê onde o player vai estar quando o dash começar — trava aqui,
	# não é re-calculado durante o dash.
	var predicted := _player.global_position + _player.velocity * TELEGRAPH_TIME
	_dash_dir = (predicted - global_position).normalized()
	if _dash_dir == Vector2.ZERO:
		_dash_dir = Vector2.RIGHT

	_sprite.scale = _base_spr_scale * Vector2(0.9, 1.12)  # se encolhe pro "impulso"
	_spawn_telegraph()


func _spawn_telegraph() -> void:
	var line := Line2D.new()
	line.width = 14.0
	line.default_color = TELEGRAPH_COLOR
	line.z_index = -1  # fica no chão, atrás dos personagens
	line.global_position = global_position
	line.add_point(Vector2.ZERO)
	line.add_point(_dash_dir * DASH_SPEED * DASH_DURATION)
	get_tree().current_scene.add_child(line)
	_telegraph_line = line

	var tw := create_tween().set_loops(3)
	tw.tween_property(line, "modulate:a", 0.25, TELEGRAPH_TIME / 6.0)
	tw.tween_property(line, "modulate:a", 1.0, TELEGRAPH_TIME / 6.0)


func _start_dash() -> void:
	_state = State.DASH
	_state_time = DASH_DURATION
	_sprite.scale = _base_spr_scale * Vector2(1.25, 0.85)  # esticado no impulso
	create_tween().tween_property(_sprite, "scale", _base_spr_scale, DASH_DURATION * 0.8)
	if is_instance_valid(_telegraph_line):
		_telegraph_line.queue_free()
		_telegraph_line = null


func _end_dash() -> void:
	_state = State.RECOVER
	_state_time = RECOVER_TIME
	velocity = Vector2.ZERO


func _on_hit_received(hitbox: HitboxComponent) -> void:
	if hitbox.stun_duration > 0.0:
		_stun_time = hitbox.stun_duration
		if is_instance_valid(_telegraph_line):
			_telegraph_line.queue_free()
			_telegraph_line = null
	if _stun_time > 0.0:
		modulate = STUN_TINT
	else:
		modulate = Color(3.0, 1.5, 1.5)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
	if hitbox.knockback_force > 0.0:
		_knockback = (global_position - hitbox.global_position).normalized() \
			* hitbox.knockback_force * KNOCKBACK_RESIST

	var dmg_num = DAMAGE_NUMBER_SCENE.instantiate()
	dmg_num.text = "-%d" % hitbox.damage
	dmg_num.position = global_position + Vector2(randf_range(-10, 10), -30)
	get_tree().current_scene.add_child(dmg_num)


func _on_died() -> void:
	if is_instance_valid(_telegraph_line):
		_telegraph_line.queue_free()
	EventBus.enemy_died.emit(null, global_position)
	queue_free.call_deferred()
