extends Area3D
## Bolha (W): congela inimigos que encostam e propaga bolhas secundárias.

const GLOW := preload("res://assets/sprites/props/glow_gradient.tres")

var player: Node3D
var frozen_enemies: Array = []
var time_left: float
var secondary_created := 0

var _visual: Sprite3D


func _ready() -> void:
	time_left = player.BUBBLE_DURATION

	collision_layer = 0
	collision_mask = 16  # enemy_hurtbox — antes ficava no default (1) e nunca detectava

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = player.BUBBLE_RADIUS
	collision.shape = sphere
	collision.position.y = 0.75
	add_child(collision)

	area_entered.connect(_on_area_entered)

	_visual = Sprite3D.new()
	_visual.texture = GLOW
	_visual.pixel_size = 1.0 / Iso.PPM
	_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual.modulate = Color(0.5, 0.7, 1.0, 0.6)
	_visual.scale = Vector3(0.31, 0.31, 1.0)
	_visual.position.y = 0.9
	add_child(_visual)


func _physics_process(delta: float) -> void:
	time_left -= delta

	var alpha: float = maxf(time_left / player.BUBBLE_DURATION, 0.0)
	if is_instance_valid(_visual):
		_visual.modulate.a = alpha * 0.6

	if time_left <= 0.0:
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	if area is HurtboxComponent:
		var enemy = area.get_parent()
		if enemy is Node3D and enemy.is_in_group("enemies") and enemy not in frozen_enemies:
			frozen_enemies.append(enemy)

			# causa dano e stun via HitboxComponent
			var hitbox := HitboxComponent.new()
			hitbox.damage = 20
			hitbox.stun_duration = player.BUBBLE_DURATION
			area.take_hit(hitbox)  # aplica o dano de verdade (emit puro pulava o take_damage)
			hitbox.queue_free()

			if secondary_created < player.BUBBLE_MAX_SECONDARY:
				_create_secondary_bubble(enemy)
				secondary_created += 1


func _create_secondary_bubble(enemy: Node3D) -> void:
	var bubble = duplicate()
	bubble.global_position = enemy.global_position
	bubble.player = player
	bubble.secondary_created = secondary_created + 1
	bubble.frozen_enemies = frozen_enemies.duplicate()
	get_tree().current_scene.add_child(bubble)
