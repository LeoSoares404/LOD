class_name DashBoss
extends CharacterBody3D
## Boss 4 (melee): persegue devagar e, periodicamente, prevê onde o player vai
## estar, escancara o caminho em vermelho por um tempo de aviso e então
## dispara um dash reto e rápido naquela direção travada (não teleguiado —
## uma vez calculada, a direção não muda mesmo que o player desvie).

enum State { CHASE, TELEGRAPH, DASH, RECOVER }

const CHASE_SPEED := 2.5       # m/s (era 40 px/s)
const DASH_SPEED := 17.5       # m/s (era 280 px/s)
const DASH_DURATION := 1.0     # "1 segundo ele vai rapidamente para frente"
const TELEGRAPH_TIME := 0.7    # aviso do caminho em vermelho antes do dash
const RECOVER_TIME := 0.5
const DASH_COOLDOWN := 2.2     # tempo perseguindo até o próximo dash
const KNOCKBACK_DECAY := 31.0
const KNOCKBACK_RESIST := 0.25
const STUN_TINT := Color(0.7, 0.9, 1.6)
const TELEGRAPH_COLOR := Color(1.0, 0.15, 0.15, 0.6)
const TELEGRAPH_WIDTH := 0.9   # m (era 14 px)
const FLOAT_AMP := 0.19
const FLOAT_SPEED := 3.2

const DAMAGE_NUMBER_SCENE := preload("res://scenes/fx/damage_number.tscn")

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var _sprite: Sprite3D = $Sprite

var _player: Node3D
var _knockback := Vector3.ZERO
var _stun_time := 0.0
var _anim_time := 0.0
var _base_spr_pos: Vector3
var _base_spr_scale: Vector3

var _state := State.CHASE
var _state_time := DASH_COOLDOWN
var _dash_dir := Vector3.RIGHT
var _telegraph: MeshInstance3D = null


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
			_sprite.modulate = Color.WHITE
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
		move_and_slide()
		return

	match _state:
		State.CHASE:
			_do_chase(delta)
		State.TELEGRAPH:
			velocity = Vector3.ZERO
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
			velocity = Vector3.ZERO
			move_and_slide()
			_state_time -= delta
			if _state_time <= 0.0:
				_state = State.CHASE
				_state_time = DASH_COOLDOWN

	# flutuação contínua — paira acima da base
	_anim_time += delta
	_sprite.position.y = _base_spr_pos.y + absf(sin(_anim_time * FLOAT_SPEED)) * FLOAT_AMP


func _do_chase(delta: float) -> void:
	var chase := Vector3.ZERO
	if _player != null and is_instance_valid(_player):
		chase = _player.global_position - global_position
		chase.y = 0.0
		if chase.length() > 0.1:
			chase = chase.normalized() * CHASE_SPEED
	velocity = chase + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
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
	var predicted: Vector3 = _player.global_position + _player.velocity * TELEGRAPH_TIME
	_dash_dir = predicted - global_position
	_dash_dir.y = 0.0
	_dash_dir = _dash_dir.normalized()
	if _dash_dir == Vector3.ZERO:
		_dash_dir = Vector3.RIGHT

	_sprite.scale = _base_spr_scale * Vector3(0.9, 1.12, 1.0)  # se encolhe pro "impulso"
	_spawn_telegraph()


## Faixa vermelha rente ao chão mostrando o caminho do dash (ex-Line2D).
func _spawn_telegraph() -> void:
	var length := DASH_SPEED * DASH_DURATION
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(TELEGRAPH_WIDTH, 0.02, length)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = TELEGRAPH_COLOR
	mesh.material_override = mat
	get_tree().current_scene.add_child(mesh)
	mesh.global_position = global_position + _dash_dir * (length / 2.0) + Vector3(0, 0.03, 0)
	mesh.look_at(mesh.global_position + _dash_dir)  # -Z do box aponta na direção do dash
	_telegraph = mesh

	var tw := create_tween().set_loops(3)
	tw.tween_property(mat, "albedo_color:a", 0.25, TELEGRAPH_TIME / 6.0)
	tw.tween_property(mat, "albedo_color:a", TELEGRAPH_COLOR.a, TELEGRAPH_TIME / 6.0)


func _start_dash() -> void:
	_state = State.DASH
	_state_time = DASH_DURATION
	_sprite.scale = _base_spr_scale * Vector3(1.25, 0.85, 1.0)  # esticado no impulso
	create_tween().tween_property(_sprite, "scale", _base_spr_scale, DASH_DURATION * 0.8)
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
		_telegraph = null


func _end_dash() -> void:
	_state = State.RECOVER
	_state_time = RECOVER_TIME
	velocity = Vector3.ZERO


func _on_hit_received(hitbox: HitboxComponent) -> void:
	if hitbox.stun_duration > 0.0:
		_stun_time = hitbox.stun_duration
		if is_instance_valid(_telegraph):
			_telegraph.queue_free()
			_telegraph = null
	if _stun_time > 0.0:
		_sprite.modulate = STUN_TINT
	else:
		_sprite.modulate = Color(3.0, 1.5, 1.5)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if hitbox.knockback_force > 0.0 and hitbox.is_inside_tree():
		var away := global_position - hitbox.global_position
		away.y = 0.0
		_knockback = away.normalized() * hitbox.knockback_force * KNOCKBACK_RESIST

	var dmg_num = DAMAGE_NUMBER_SCENE.instantiate()
	dmg_num.text = "-%d" % hitbox.damage
	dmg_num.position = global_position + Vector3(randf_range(-0.6, 0.6), 7.2, 0)
	get_tree().current_scene.add_child(dmg_num)


func _on_died() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	EventBus.enemy_died.emit(null, global_position)
	queue_free.call_deferred()
