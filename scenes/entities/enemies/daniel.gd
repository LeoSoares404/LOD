class_name Daniel
extends CharacterBody3D
## Daniel: atacante ranged comum. Aproxima até ATTACK_RANGE, para, "vira de costas"
## e solta um "pum" (projétil de gás verde) na direção do player. Recua se o player
## colar demais. Não há sprite de costas — a virada é faturada com flip + o puff 💨.

const SPEED := 3.0
const ATTACK_RANGE := 8.0        # para e passa a atirar a partir desta distância
const RETREAT_RANGE := 5.0       # recua se o player chegar mais perto que isso
const SHOOT_INTERVAL := 1.8      # s entre um pum e o outro
const KNOCKBACK_DECAY := 37.5
const STUN_TINT := Color(0.6, 0.8, 1.6)   # azul enquanto atordoado
const IDLE_TINT := Color(0.7, 1.3, 0.6)   # esverdeado — o cara do gás
const SHOOT_OFFSET := Vector3(0, 0.6, 0)
const PUM_DAMAGE := 3
const PUM_TINT := Color(0.6, 1.5, 0.3, 1.0)  # baforada verde
const ANIM_FPS := 8.0

const BOLT_SCENE := preload("res://scenes/entities/projectiles/enemy_bolt.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/fx/damage_number.tscn")

var _knockback := Vector3.ZERO
var _stun_time := 0.0
var _slow_time := 0.0
var _slow_factor := 0.0
var _anim_time := 0.0
var _shoot_timer := SHOOT_INTERVAL
var _base_spr_scale: Vector3

@onready var _sprite: Sprite3D = $Sprite
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox

var _player: Node3D


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_base_spr_scale = _sprite.scale
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	if _slow_time > 0.0:
		_slow_time -= delta
	# atordoado: não persegue nem atira, só sofre o resíduo do empurrão
	if _stun_time > 0.0:
		_stun_time -= delta
		if _stun_time <= 0.0:
			_sprite.modulate = IDLE_TINT
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
		move_and_slide()
		return

	var move := Vector3.ZERO
	var walking := false
	if _player != null and is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		var dir := to_player.normalized() if dist > 0.001 else Vector3.FORWARD
		if dist > ATTACK_RANGE:
			move = dir * SPEED * _slow_mult()    # aproxima até a distância de tiro
			walking = true
		elif dist < RETREAT_RANGE:
			move = -dir * SPEED * _slow_mult()   # recua se o player colar
			walking = true
		if dist <= ATTACK_RANGE:                 # em posição: bombardeia no intervalo
			_shoot_timer -= delta
			if _shoot_timer <= 0.0:
				_shoot_timer = SHOOT_INTERVAL
				_shoot(dir)

	velocity = move + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()
	_animate(delta, walking)


## "Vira de costas" (faturado: flip + agachada), solta o puff 💨 e o pum verde no player.
func _shoot(dir: Vector3) -> void:
	_sprite.flip_h = dir.x > 0.0   # olha pro lado oposto da baforada = de costas pro player
	_sprite.scale = Vector3(_base_spr_scale.x, _base_spr_scale.y * 0.8, _base_spr_scale.z)
	create_tween().tween_property(_sprite, "scale", _base_spr_scale, 0.2).set_trans(Tween.TRANS_BACK)
	_puff(dir)

	var bolt: EnemyBolt = BOLT_SCENE.instantiate()
	bolt.direction = dir
	bolt.damage = PUM_DAMAGE
	bolt.position = global_position + SHOOT_OFFSET + dir * 0.3
	var spr: Sprite3D = bolt.get_node("Sprite")
	spr.modulate = PUM_TINT
	spr.scale *= 1.4  # nuvem de gás mais gorda que o bolt do boss
	var light: OmniLight3D = bolt.get_node("Light")
	light.light_color = Color(0.5, 1.0, 0.3)
	get_tree().current_scene.add_child(bolt)


## Baforada 💨 que cresce e some entre o Daniel e o player.
func _puff(dir: Vector3) -> void:
	var puff := Label3D.new()
	puff.text = "💨"
	puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	puff.no_depth_test = true
	puff.font_size = 44
	puff.pixel_size = 0.007
	puff.position = global_position + SHOOT_OFFSET + dir * 0.45
	get_tree().current_scene.add_child(puff)
	var tw := puff.create_tween()
	tw.set_parallel(true)
	tw.tween_property(puff, "scale", Vector3.ONE * 1.9, 0.4)
	tw.tween_property(puff, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(puff.queue_free)


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
		if _slow_time <= 0.0:
			_slow_factor = 0.0  # slow anterior expirou: recomeça a pilha
		_slow_time = hitbox.slow_duration  # renova a duração
		if hitbox.slow_stacks:
			_slow_factor = minf(_slow_factor + hitbox.slow_factor, 0.9)  # empilha (máx 90%)
		else:
			_slow_factor = hitbox.slow_factor  # renova, não acumula (rapiera)
	if _stun_time > 0.0:
		_sprite.modulate = STUN_TINT  # tom azul estável enquanto atordoado
	else:
		_sprite.modulate = Color(3.0, 3.0, 3.0)  # hit-flash branco
		create_tween().tween_property(_sprite, "modulate", IDLE_TINT, 0.15)
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
