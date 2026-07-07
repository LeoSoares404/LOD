class_name Player
extends CharacterBody2D

const SPEED := 90.0  # px/s (~5.6 tiles/s)
const ARRIVE_DISTANCE := 4.0  # px — perto o bastante do alvo para parar sem "vibrar"

const BOLT_SCENE := preload("res://scenes/entities/projectiles/magic_bolt.tscn")
const BOLT_COOLDOWN := 0.4  # s
const CAST_OFFSET := Vector2(0, -12)  # projétil nasce no peito, não nos pés

var _bolt_cooldown := 0.0

var _target := Vector2.ZERO
var _moving := false

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox


func _ready() -> void:
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)


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
	if Input.is_action_just_pressed("skill_1") and _bolt_cooldown <= 0.0:
		_cast_bolt()

	# segurar o botão direito = seguir o cursor (estilo Diablo)
	if Input.is_action_pressed("move_click"):
		_target = get_global_mouse_position()
		_moving = true

	if not _moving:
		return

	var to_target := _target - global_position
	if to_target.length() <= ARRIVE_DISTANCE:
		_moving = false
		velocity = Vector2.ZERO
		return

	velocity = to_target.normalized() * SPEED
	move_and_slide()


func _cast_bolt() -> void:
	_bolt_cooldown = BOLT_COOLDOWN
	var origin := global_position + CAST_OFFSET
	var bolt: MagicBolt = BOLT_SCENE.instantiate()
	bolt.direction = (get_global_mouse_position() - origin).normalized()
	bolt.position = origin
	get_tree().current_scene.add_child(bolt)
	EventBus.skill_cast.emit(0, null)
