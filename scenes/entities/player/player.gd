class_name Player
extends CharacterBody2D

const SPEED := 90.0  # px/s (~5.6 tiles/s)
const ARRIVE_DISTANCE := 4.0  # px — perto o bastante do alvo para parar sem "vibrar"

const LIGHTNING_SCENE := preload("res://scenes/skills/projectiles/lightning_bolt.tscn")
const BUBBLE_SCENE := preload("res://scenes/skills/effects/bubble.tscn")
const PILLAR_SCENE := preload("res://scenes/skills/effects/fire_pillar.tscn")
const CAST_OFFSET := Vector2(0, -12)

# slots: 0=raio · 1=bolha · 2=pilar de fogo · 3=superataque
# teclas: mouse-mode = Q,W,E,R · wasd-mode = Q,E,C,R (W/A/S/D vira movimento)
const SKILL_COOLDOWN := [0.6, 5.0, 3.5, 15.0]
const SKILL_MANA := [8, 14, 10, 28]

# raio (Q)
const LIGHTNING_BOUNCES := 3
const LIGHTNING_BOUNCE_RANGE := 150.0

# bolha (W)
const BUBBLE_DURATION := 3.0
const BUBBLE_MAX_SECONDARY := 2
const BUBBLE_SECONDARY_RANGE := 120.0

# pilar de fogo (E)
const PILLAR_DURATION := 2.5
const PILLAR_RADIUS := 80.0
const PILLAR_TICK_RATE := 0.2

# superataque (R)
const SUPER_EXPLOSION_RADIUS := 200.0
const SUPER_STUN_DURATION := 1.5

const MAX_MANA := 30
const MANA_REGEN := 4.0

var _cooldowns := [0.0, 0.0, 0.0, 0.0]
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
	for i in 4:
		if _cooldowns[i] > 0.0:
			_cooldowns[i] -= delta
	_regen_mana(delta)

	for i in 4:
		if _skill_key_pressed(i) and _can_cast(i):
			_cast(i)

	if GameState.control_scheme == "wasd":
		_move_wasd()
	else:
		_move_click()

	_update_animation(delta)


## Segurar o botão direito = seguir o cursor (estilo Diablo).
func _move_click() -> void:
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


## WASD direto, sem click-to-move.
func _move_wasd() -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_key_pressed(KEY_S):
		dir.y += 1
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1

	_moving = dir.length() > 0.0
	if _moving:
		velocity = dir.normalized() * SPEED
		move_and_slide()
	else:
		velocity = Vector2.ZERO


## Tecla da skill depende do esquema de controle ativo (número sempre funciona).
func _skill_key_pressed(slot: int) -> bool:
	if Input.is_key_just_pressed(KEY_1 + slot):
		return true
	var wasd := GameState.control_scheme == "wasd"
	match slot:
		0:
			return Input.is_key_just_pressed(KEY_Q)
		1:
			return Input.is_key_just_pressed(KEY_E if wasd else KEY_W)
		2:
			return Input.is_key_just_pressed(KEY_C if wasd else KEY_E)
		3:
			return Input.is_key_just_pressed(KEY_R)
	return false


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
		0: _cast_lightning()
		1: _cast_bubble()
		2: _cast_pillar()
		3: _cast_super()


func _cast_lightning() -> void:
	var origin := global_position + CAST_OFFSET
	var lightning: Node2D = LIGHTNING_SCENE.instantiate()
	lightning.position = origin
	lightning.target = get_global_mouse_position()
	lightning.player = self
	get_tree().current_scene.add_child(lightning)


func _cast_bubble() -> void:
	var bubble: Node2D = BUBBLE_SCENE.instantiate()
	bubble.position = get_global_mouse_position()
	bubble.player = self
	get_tree().current_scene.add_child(bubble)


func _cast_pillar() -> void:
	var pillar: Node2D = PILLAR_SCENE.instantiate()
	pillar.position = get_global_mouse_position()
	pillar.player = self
	get_tree().current_scene.add_child(pillar)


func _cast_super() -> void:
	var target_pos := get_global_mouse_position()
	global_position = target_pos

	# encontra inimigos na área usando PhysicsShapeQuery
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = CircleShape2D.new()
	query.shape.radius = SUPER_EXPLOSION_RADIUS
	query.transform = Transform2D.IDENTITY.translated(target_pos)

	var results = space_state.intersect_shape(query)

	for result in results:
		if result.collider is Ghoul:
			var hitbox = HitboxComponent.new()
			hitbox.damage = 50
			hitbox.stun_duration = SUPER_STUN_DURATION
			if result.collider.has_node("Hurtbox"):
				result.collider.get_node("Hurtbox").hit_received.emit(hitbox)

	# efeito visual
	var tween := create_tween()
	modulate = Color(1.5, 1.0, 2.0)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
