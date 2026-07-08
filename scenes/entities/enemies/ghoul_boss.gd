class_name GhoulBoss
extends CharacterBody3D
## Boss: demônio grande e resistente. Persegue o player mantendo distância,
## causa dano por contato E atira projéteis. Muito HP.
## Padrão de ataque cíclico: tiro reto → tiro de previsão de movimento → tridente.

const SPEED := 2.1              # m/s (era 34 px/s)
const STOP_DISTANCE := 5.6      # mantém distância para bombardear
const KNOCKBACK_DECAY := 31.0
const KNOCKBACK_RESIST := 0.25  # boss pesado: sofre pouco empurrão
const SHOOT_INTERVAL := 1.5
const STUN_TINT := Color(0.7, 0.9, 1.6)
const FLOAT_AMP := 0.19         # m de flutuação vertical
const FLOAT_SPEED := 3.2
const SHOOT_OFFSET := Vector3(0, 1.25, 0)

const BOLT_SCENE := preload("res://scenes/entities/projectiles/enemy_bolt.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/fx/damage_number.tscn")

var _attack_count := 0

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var _sprite: Sprite3D = $Sprite

var _player: Node3D
var _knockback := Vector3.ZERO
var _shoot_timer := SHOOT_INTERVAL
var _stun_time := 0.0
var _anim_time := 0.0
var _base_spr_pos: Vector3
var _base_spr_scale: Vector3


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_base_spr_pos = _sprite.position
	_base_spr_scale = _sprite.scale
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	# atordoado: não persegue nem atira
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
			chase = to_player.normalized() * SPEED
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_timer = SHOOT_INTERVAL
			_attack_count += 1
			match _attack_count % 3:
				1:
					_shoot(to_player.normalized())
				2:
					_shoot_predictive()
				_:
					_shoot_trident(to_player.normalized())

	velocity = chase + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()

	# flutuação contínua (respiração ameaçadora) — paira acima da base
	_anim_time += delta
	_sprite.position.y = _base_spr_pos.y + absf(sin(_anim_time * FLOAT_SPEED)) * FLOAT_AMP


func _squash(amount: Vector2, time: float) -> void:
	_sprite.scale = _base_spr_scale * Vector3(amount.x, amount.y, 1.0)
	create_tween().tween_property(_sprite, "scale", _base_spr_scale, time).set_trans(Tween.TRANS_BACK)


func _shoot(dir: Vector3) -> void:
	_squash(Vector2(1.1, 0.92), 0.25)
	var bolt: EnemyBolt = BOLT_SCENE.instantiate()
	bolt.direction = dir
	bolt.position = global_position + SHOOT_OFFSET
	get_tree().current_scene.add_child(bolt)


## Mira onde o player deve estar quando o projétil chegar, com base na
## velocidade atual dele — só funciona bem porque o bolt tem velocidade
## constante, então dá pra calcular o tempo de voo direto.
func _shoot_predictive() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_squash(Vector2(1.15, 0.88), 0.28)

	var origin := global_position + SHOOT_OFFSET
	var lead_time := Iso.flat_distance(origin, _player.global_position) / EnemyBolt.SPEED
	var predicted_pos: Vector3 = _player.global_position + _player.velocity * lead_time
	var dir := origin.direction_to(predicted_pos)
	dir.y = 0.0
	dir = dir.normalized()

	var bolt: EnemyBolt = BOLT_SCENE.instantiate()
	bolt.direction = dir
	bolt.position = origin
	get_tree().current_scene.add_child(bolt)


func _shoot_trident(dir: Vector3) -> void:
	_squash(Vector2(1.2, 0.85), 0.3)

	var angles = [-0.4, 0.0, 0.4]  # 3 bolas em leque
	for angle_offset in angles:
		var rotated_dir: Vector3 = dir.rotated(Vector3.UP, angle_offset)
		var bolt: EnemyBolt = BOLT_SCENE.instantiate()
		bolt.direction = rotated_dir
		bolt.position = global_position + SHOOT_OFFSET
		get_tree().current_scene.add_child(bolt)


func _on_hit_received(hitbox: HitboxComponent) -> void:
	if hitbox.stun_duration > 0.0:
		_stun_time = hitbox.stun_duration
	if _stun_time > 0.0:
		_sprite.modulate = STUN_TINT
	else:
		_sprite.modulate = Color(3.0, 2.0, 2.0)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if hitbox.knockback_force > 0.0 and hitbox.is_inside_tree():
		var away := global_position - hitbox.global_position
		away.y = 0.0
		_knockback = away.normalized() * hitbox.knockback_force * KNOCKBACK_RESIST

	# mostra número de dano
	var dmg_num = DAMAGE_NUMBER_SCENE.instantiate()
	dmg_num.text = "-%d" % hitbox.damage
	dmg_num.position = global_position + Vector3(randf_range(-0.6, 0.6), 7.2, 0)
	get_tree().current_scene.add_child(dmg_num)


func _on_died() -> void:
	EventBus.enemy_died.emit(null, global_position)
	queue_free.call_deferred()
