class_name GhoulBoss
extends CharacterBody2D
## Boss: demônio grande e resistente. Persegue o player mantendo distância,
## causa dano por contato E atira projéteis. Muito HP.

const SPEED := 34.0
const STOP_DISTANCE := 90.0   # mantém distância para bombardear
const KNOCKBACK_DECAY := 500.0
const KNOCKBACK_RESIST := 0.25  # boss pesado: sofre pouco empurrão
const SHOOT_INTERVAL := 1.5
const STUN_TINT := Color(0.7, 0.9, 1.6)
const FLOAT_AMP := 3.0      # px de flutuação vertical
const FLOAT_SPEED := 3.2

const BOLT_SCENE := preload("res://scenes/entities/projectiles/enemy_bolt.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/fx/damage_number.tscn")

var _attack_count := 0

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var _sprite: Sprite2D = $Sprite

var _player: Node2D
var _knockback := Vector2.ZERO
var _shoot_timer := SHOOT_INTERVAL
var _stun_time := 0.0
var _anim_time := 0.0
var _base_spr_pos: Vector2
var _base_spr_scale: Vector2


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
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_timer = SHOOT_INTERVAL
			_attack_count += 1
			if _attack_count % 2 == 0:
				_shoot_trident(to_player.normalized())
			else:
				_shoot(to_player.normalized())

	velocity = chase + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()

	# flutuação contínua (respiração ameaçadora) — paira acima da base
	_anim_time += delta
	_sprite.position.y = _base_spr_pos.y - absf(sin(_anim_time * FLOAT_SPEED)) * FLOAT_AMP


func _shoot(dir: Vector2) -> void:
	_sprite.scale = _base_spr_scale * Vector2(1.1, 0.92)
	create_tween().tween_property(_sprite, "scale", _base_spr_scale, 0.25).set_trans(Tween.TRANS_BACK)
	var bolt: EnemyBolt = BOLT_SCENE.instantiate()
	bolt.direction = dir
	bolt.position = global_position + Vector2(0, -20)
	get_tree().current_scene.add_child(bolt)


func _shoot_trident(dir: Vector2) -> void:
	_sprite.scale = _base_spr_scale * Vector2(1.2, 0.85)
	create_tween().tween_property(_sprite, "scale", _base_spr_scale, 0.3).set_trans(Tween.TRANS_BACK)

	var angles = [-0.4, 0.0, 0.4]  # 3 bolas em leque
	for angle_offset in angles:
		var rotated_dir = dir.rotated(angle_offset)
		var bolt: EnemyBolt = BOLT_SCENE.instantiate()
		bolt.direction = rotated_dir
		bolt.position = global_position + Vector2(0, -20)
		get_tree().current_scene.add_child(bolt)


func _on_hit_received(hitbox: HitboxComponent) -> void:
	if hitbox.stun_duration > 0.0:
		_stun_time = hitbox.stun_duration
	if _stun_time > 0.0:
		modulate = STUN_TINT
	else:
		modulate = Color(3.0, 2.0, 2.0)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
	if hitbox.knockback_force > 0.0:
		_knockback = (global_position - hitbox.global_position).normalized() \
			* hitbox.knockback_force * KNOCKBACK_RESIST

	# mostra número de dano
	var dmg_num = DAMAGE_NUMBER_SCENE.instantiate()
	dmg_num.text = "-%d" % hitbox.damage
	dmg_num.position = global_position + Vector2(randf_range(-10, 10), -30)
	get_tree().current_scene.add_child(dmg_num)


func _on_died() -> void:
	EventBus.enemy_died.emit(null, global_position)
	queue_free.call_deferred()
