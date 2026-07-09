class_name Player
extends CharacterBody3D
## Player 2.5D: corpo 3D no plano XZ, sprite billboard. Mira das skills via
## projeção do mouse no chão (Iso.mouse_ground_position). 16 px = 1 m.

const SPEED := 5.6            # m/s (era 90 px/s)
const ARRIVE_DISTANCE := 0.25  # m — perto o bastante do alvo para parar sem "vibrar"

const LIGHTNING_SCENE := preload("res://scenes/skills/projectiles/lightning_bolt.tscn")
const BUBBLE_SCENE := preload("res://scenes/skills/effects/bubble.tscn")
const PILLAR_SCENE := preload("res://scenes/skills/effects/fire_pillar.tscn")
const CAST_OFFSET := Vector3(0, 0.75, 0)  # altura do peito

# slots: 0=raio · 1=bolha · 2=pilar de fogo · 3=superataque
# teclas: mouse-mode = Q,W,E,R · wasd-mode = Q,E,C,R (W/A/S/D vira movimento)
const SKILL_COOLDOWN := [0.6, 5.0, 3.5, 15.0]
const SKILL_MANA := [8, 14, 10, 28]

# raio (Q)
const LIGHTNING_BOUNCES := 3
const LIGHTNING_BOUNCE_RANGE := 9.4

# bolha (W)
const BUBBLE_DURATION := 3.0
const BUBBLE_MAX_SECONDARY := 2
const BUBBLE_SECONDARY_RANGE := 7.5
const BUBBLE_RADIUS := 2.5

# pilar de fogo (E)
const PILLAR_DURATION := 2.5
const PILLAR_RADIUS := 5.0
const PILLAR_TICK_RATE := 0.2

# superataque (R)
const SUPER_EXPLOSION_RADIUS := 12.5
const SUPER_STUN_DURATION := 1.5

const MAX_MANA := 30
const MANA_REGEN := 4.0

const ENEMY_LAYER_MASK := 4  # layer 3 "enemies"

var _cooldowns := [0.0, 0.0, 0.0, 0.0]
var _mana := float(MAX_MANA)

# billboard HD: animação por código (bob de respirar/andar), sem spritesheet
const IDLE_BOB_SPEED := 2.6
const WALK_BOB_SPEED := 7.0
const IDLE_BOB_AMP := 0.025
const WALK_BOB_AMP := 0.05

var _anim_time := 0.0
var _base_spr_y := 0.0

@onready var _sprite: Sprite3D = %Sprite

var _target := Vector3.ZERO
var _moving := false
var _just_pressed := {}  # physical_keycode -> true (limpo a cada tick de física)

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox


func _ready() -> void:
	health.died.connect(_on_died)
	health.health_changed.connect(
		func(c: int, m: int) -> void: EventBus.player_health_changed.emit(c, m)
	)
	hurtbox.hit_received.connect(_on_hit_received)
	_base_spr_y = _sprite.position.y
	_emit_initial_status.call_deferred()  # deferido: garante que a HUD já conectou


func _emit_initial_status() -> void:
	EventBus.player_health_changed.emit(health.health, health.max_health)
	EventBus.player_mana_changed.emit(int(_mana), MAX_MANA)


func _on_hit_received(_hitbox: HitboxComponent) -> void:
	EventBus.player_damaged.emit(_hitbox.damage, health.health)
	# flash vermelho de dano (modulate no sprite — Node3D não tem modulate)
	_sprite.modulate = Color(2.5, 0.6, 0.6)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)


func _on_died() -> void:
	# morte por enquanto = recomeçar a cena (respawn instantâneo)
	get_tree().reload_current_scene.call_deferred()


## Buffer de "acabou de apertar" por tecla física — Input.is_key_just_pressed()
## NÃO existe na API do Godot (erro nº 3 do ERROS_GODOT.md).
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_just_pressed[event.physical_keycode] = true


func _key_just_pressed(key: Key) -> bool:
	return _just_pressed.has(key)


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
	_just_pressed.clear()


## Segurar o botão direito = seguir o cursor (estilo Diablo).
func _move_click() -> void:
	if Input.is_action_pressed("move_click"):
		_target = Iso.mouse_ground_position(self)
		_moving = true

	if _moving:
		var to_target := _target - global_position
		to_target.y = 0.0
		if to_target.length() <= ARRIVE_DISTANCE:
			_moving = false
			velocity = Vector3.ZERO
		else:
			velocity = to_target.normalized() * SPEED
			move_and_slide()


## WASD direto, sem click-to-move.
func _move_wasd() -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_key_pressed(KEY_S):
		dir.z += 1
	if Input.is_key_pressed(KEY_W):
		dir.z -= 1

	_moving = dir.length() > 0.0
	if _moving:
		velocity = dir.normalized() * SPEED
		move_and_slide()
	else:
		velocity = Vector3.ZERO


## Tecla da skill depende do esquema de controle ativo (número sempre funciona).
func _skill_key_pressed(slot: int) -> bool:
	if _key_just_pressed(KEY_1 + slot):
		return true
	var wasd := GameState.control_scheme == "wasd"
	match slot:
		0:
			return _key_just_pressed(KEY_Q)
		1:
			return _key_just_pressed(KEY_E if wasd else KEY_W)
		2:
			return _key_just_pressed(KEY_C if wasd else KEY_E)
		3:
			return _key_just_pressed(KEY_R)
	return false


func _update_animation(delta: float) -> void:
	var walking := _moving and velocity.length() > 0.1
	if absf(velocity.x) > 0.05:
		_sprite.flip_h = velocity.x < 0  # espelha pra encarar o lado do movimento
	_anim_time += delta
	var bob_speed := WALK_BOB_SPEED if walking else IDLE_BOB_SPEED
	var bob_amp := WALK_BOB_AMP if walking else IDLE_BOB_AMP
	_sprite.position.y = _base_spr_y + absf(sin(_anim_time * bob_speed)) * bob_amp


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
	_squash()
	match slot:
		0: _cast_lightning()
		1: _cast_bubble()
		2: _cast_pillar()
		3: _cast_super()


func _squash() -> void:
	# "tranco" ao conjurar (relativo à escala base do sprite)
	_sprite.scale = Vector3(1.12, 0.9, 1.0)
	create_tween().tween_property(_sprite, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _cast_lightning() -> void:
	var lightning: Node3D = LIGHTNING_SCENE.instantiate()
	lightning.position = global_position + CAST_OFFSET
	lightning.target = Iso.mouse_ground_position(self) + Vector3(0, CAST_OFFSET.y, 0)
	lightning.player = self
	get_tree().current_scene.add_child(lightning)


func _cast_bubble() -> void:
	var bubble: Node3D = BUBBLE_SCENE.instantiate()
	bubble.position = Iso.mouse_ground_position(self)
	bubble.player = self
	get_tree().current_scene.add_child(bubble)


func _cast_pillar() -> void:
	var pillar: Node3D = PILLAR_SCENE.instantiate()
	pillar.position = Iso.mouse_ground_position(self)
	pillar.player = self
	get_tree().current_scene.add_child(pillar)


func _cast_super() -> void:
	var target_pos := Iso.mouse_ground_position(self)
	global_position = target_pos

	# encontra inimigos na área usando PhysicsShapeQuery 3D
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = SUPER_EXPLOSION_RADIUS
	query.shape = sphere
	query.transform = Transform3D(Basis(), target_pos + Vector3(0, 0.75, 0))
	query.collision_mask = ENEMY_LAYER_MASK

	var results := space_state.intersect_shape(query)

	for result in results:
		var collider: Object = result.collider
		if collider is Node3D and collider.is_in_group("enemies"):
			var hitbox := HitboxComponent.new()
			hitbox.damage = 50
			hitbox.stun_duration = SUPER_STUN_DURATION
			if collider.has_node("Hurtbox"):
				collider.get_node("Hurtbox").take_hit(hitbox)  # aplica dano de verdade (emit puro pulava take_damage)
			hitbox.queue_free()

	# efeito visual
	_sprite.modulate = Color(1.5, 1.0, 2.0)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.3)
