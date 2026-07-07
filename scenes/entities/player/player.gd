class_name Player
extends CharacterBody2D

const SPEED := 90.0  # px/s (~5.6 tiles/s)
const ARRIVE_DISTANCE := 4.0  # px — perto o bastante do alvo para parar sem "vibrar"

const BOLT_SCENE := preload("res://scenes/entities/projectiles/magic_bolt.tscn")
const NOVA_SCENE := preload("res://scenes/entities/projectiles/arcane_nova.tscn")
const CAST_OFFSET := Vector2(0, -12)  # projéteis nascem no peito, não nos pés

# slots: 0=Q bolt · 1=W nova · 2=E dash · 3=R tempestade
const SKILL_COOLDOWN := [0.4, 4.5, 2.5, 12.0]
const SKILL_MANA := [5, 12, 6, 22]
const BARRAGE_COUNT := 12  # projéteis da Tempestade Arcana (R)

const MAX_MANA := 30
const MANA_REGEN := 4.0  # por segundo

# dash (E)
const DASH_SPEED := 760.0
const DASH_TIME := 0.13

var _cooldowns := [0.0, 0.0, 0.0, 0.0]
var _mana := float(MAX_MANA)
var _dash_time_left := 0.0
var _dash_dir := Vector2.ZERO

# animação: spritesheet 5 colunas (0=parado, 1-4=andando) x 3 linhas de direção
const ANIM_FPS := 8.0
const ROW_DOWN := 0
const ROW_UP := 1
const ROW_SIDE := 2

var _anim_time := 0.0
var _facing_row := ROW_DOWN

@onready var _sprite: Sprite2D = %Sprite

var _target := Vector2.ZERO
var _moving := false

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox


func _ready() -> void:
	health.died.connect(_on_died)
	health.health_changed.connect(
		func(c: int, m: int) -> void: EventBus.player_health_changed.emit(c, m)
	)
	hurtbox.hit_received.connect(_on_hit_received)
	_emit_initial_status.call_deferred()  # deferido: garante que a HUD já conectou


func _emit_initial_status() -> void:
	EventBus.player_health_changed.emit(health.health, health.max_health)
	EventBus.player_mana_changed.emit(int(_mana), MAX_MANA)


func _on_hit_received(_hitbox: HitboxComponent) -> void:
	EventBus.player_damaged.emit(_hitbox.damage, health.health)
	# flash vermelho de dano
	modulate = Color(2.5, 0.6, 0.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)


func _on_died() -> void:
	# morte por enquanto = recomeçar a cena (respawn instantâneo)
	get_tree().reload_current_scene.call_deferred()


func _physics_process(delta: float) -> void:
	for i in 4:
		if _cooldowns[i] > 0.0:
			_cooldowns[i] -= delta
	_regen_mana(delta)

	# dash em andamento sobrepõe o resto do movimento
	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _dash_dir * DASH_SPEED
		move_and_slide()
		if _dash_time_left <= 0.0:
			_end_dash()
		return

	for i in 4:
		if Input.is_action_just_pressed("skill_%d" % (i + 1)) and _can_cast(i):
			_cast(i)

	# segurar o botão direito = seguir o cursor (estilo Diablo)
	if Input.is_action_pressed("move_click"):
		_target = get_global_mouse_position()
		_moving = true

	if _moving:
		var to_target := _target - global_position
		if to_target.length() <= ARRIVE_DISTANCE:
			_moving = false
			velocity = Vector2.ZERO
		else:
			velocity = to_target.normalized() * SPEED
			move_and_slide()

	_update_animation(delta)


func _update_animation(delta: float) -> void:
	var walking := _moving and velocity.length() > 1.0
	if walking:
		# direção dominante decide a linha do spritesheet
		if absf(velocity.x) > absf(velocity.y):
			_facing_row = ROW_SIDE
			_sprite.flip_h = velocity.x < 0
		else:
			_facing_row = ROW_UP if velocity.y < 0 else ROW_DOWN
		_anim_time += delta
	else:
		_anim_time = 0.0
	var col := 1 + int(_anim_time * ANIM_FPS) % 4 if walking else 0
	_sprite.frame = _facing_row * 5 + col


func _regen_mana(delta: float) -> void:
	if _mana >= MAX_MANA:
		return
	var before := int(_mana)
	_mana = minf(_mana + MANA_REGEN * delta, float(MAX_MANA))
	if int(_mana) != before:
		EventBus.player_mana_changed.emit(int(_mana), MAX_MANA)


func _can_cast(slot: int) -> bool:
	return _cooldowns[slot] <= 0.0 and _mana >= SKILL_MANA[slot]


func _cast(slot: int) -> void:
	_cooldowns[slot] = SKILL_COOLDOWN[slot]
	_mana -= SKILL_MANA[slot]
	EventBus.player_mana_changed.emit(int(_mana), MAX_MANA)
	EventBus.skill_cooldown_started.emit(slot, SKILL_COOLDOWN[slot])
	EventBus.skill_cast.emit(slot, null)
	match slot:
		0: _cast_bolt()
		1: _cast_nova()
		2: _cast_dash()
		3: _cast_barrage()


func _cast_bolt() -> void:
	var origin := global_position + CAST_OFFSET
	var bolt: MagicBolt = BOLT_SCENE.instantiate()
	bolt.direction = (get_global_mouse_position() - origin).normalized()
	bolt.position = origin
	get_tree().current_scene.add_child(bolt)


func _cast_nova() -> void:
	var nova: Node2D = NOVA_SCENE.instantiate()
	nova.position = global_position + Vector2(0, -8)
	get_tree().current_scene.add_child(nova)


func _cast_dash() -> void:
	_dash_dir = (get_global_mouse_position() - global_position).normalized()
	if _dash_dir == Vector2.ZERO:
		_dash_dir = Vector2.RIGHT
	_dash_time_left = DASH_TIME
	_moving = false
	hurtbox.set_deferred("monitorable", false)  # i-frames durante o dash
	modulate = Color(0.7, 1.4, 1.6, 0.7)


func _end_dash() -> void:
	hurtbox.set_deferred("monitorable", true)
	modulate = Color.WHITE


func _cast_barrage() -> void:
	var origin := global_position + CAST_OFFSET
	for i in BARRAGE_COUNT:
		var dir := Vector2.RIGHT.rotated(TAU * i / BARRAGE_COUNT)
		var bolt: MagicBolt = BOLT_SCENE.instantiate()
		bolt.direction = dir
		bolt.position = origin
		get_tree().current_scene.add_child(bolt)
