class_name Player
extends CharacterBody2D

const SPEED := 90.0  # px/s (~5.6 tiles/s)
const ARRIVE_DISTANCE := 4.0  # px — perto o bastante do alvo para parar sem "vibrar"

const BOLT_SCENE := preload("res://scenes/entities/projectiles/magic_bolt.tscn")
const BOLT_COOLDOWN := 0.4  # s
const BOLT_MANA_COST := 5
const CAST_OFFSET := Vector2(0, -12)  # projétil nasce no peito, não nos pés

const MAX_MANA := 30
const MANA_REGEN := 4.0  # por segundo

var _bolt_cooldown := 0.0
var _mana := float(MAX_MANA)

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
	if _bolt_cooldown > 0.0:
		_bolt_cooldown -= delta
	_regen_mana(delta)
	if Input.is_action_just_pressed("skill_1") and _bolt_cooldown <= 0.0 and _mana >= BOLT_MANA_COST:
		_cast_bolt()

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


func _cast_bolt() -> void:
	_bolt_cooldown = BOLT_COOLDOWN
	_mana -= BOLT_MANA_COST
	EventBus.player_mana_changed.emit(int(_mana), MAX_MANA)
	EventBus.skill_cooldown_started.emit(0, BOLT_COOLDOWN)
	var origin := global_position + CAST_OFFSET
	var bolt: MagicBolt = BOLT_SCENE.instantiate()
	bolt.direction = (get_global_mouse_position() - origin).normalized()
	bolt.position = origin
	get_tree().current_scene.add_child(bolt)
	EventBus.skill_cast.emit(0, null)
