class_name GhoulBoss
extends CharacterBody2D
## Boss: demônio grande e resistente. Persegue o player mantendo distância,
## causa dano por contato E atira projéteis. Muito HP.

const SPEED := 34.0
const STOP_DISTANCE := 90.0   # mantém distância para bombardear
const KNOCKBACK_DECAY := 500.0
const KNOCKBACK_RESIST := 0.25  # boss pesado: sofre pouco empurrão
const SHOOT_INTERVAL := 1.5

const BOLT_SCENE := preload("res://scenes/entities/projectiles/enemy_bolt.tscn")

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox

var _player: Node2D
var _knockback := Vector2.ZERO
var _shoot_timer := SHOOT_INTERVAL


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	var chase := Vector2.ZERO
	if _player != null and is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		if to_player.length() > STOP_DISTANCE:
			chase = to_player.normalized() * SPEED
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_timer = SHOOT_INTERVAL
			_shoot(to_player.normalized())

	velocity = chase + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()


func _shoot(dir: Vector2) -> void:
	var bolt: EnemyBolt = BOLT_SCENE.instantiate()
	bolt.direction = dir
	bolt.position = global_position + Vector2(0, -20)
	get_tree().current_scene.add_child(bolt)


func _on_hit_received(hitbox: HitboxComponent) -> void:
	modulate = Color(3.0, 2.0, 2.0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
	if hitbox.knockback_force > 0.0:
		_knockback = (global_position - hitbox.global_position).normalized() \
			* hitbox.knockback_force * KNOCKBACK_RESIST


func _on_died() -> void:
	EventBus.enemy_died.emit(null, global_position)
	queue_free.call_deferred()
