extends Area2D

var player: Node2D
var frozen_enemies: Array = []
var time_left: float
var secondary_created := 0


func _ready() -> void:
	time_left = player.BUBBLE_DURATION

	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = 40.0
	add_child(collision)

	area_entered.connect(_on_area_entered)
	modulate = Color(0.5, 0.7, 1.0, 0.6)


func _physics_process(delta: float) -> void:
	time_left -= delta

	var alpha = maxf(time_left / player.BUBBLE_DURATION, 0.0)
	modulate.a = alpha * 0.6

	if time_left <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var enemy = area.get_parent()
		if enemy is Ghoul and enemy not in frozen_enemies:
			frozen_enemies.append(enemy)

			# causa dano e stun via HitboxComponent
			var hitbox = HitboxComponent.new()
			hitbox.damage = 20
			hitbox.stun_duration = player.BUBBLE_DURATION
			area.hit_received.emit(hitbox)

			if secondary_created < player.BUBBLE_MAX_SECONDARY:
				_create_secondary_bubble(enemy)
				secondary_created += 1


func _create_secondary_bubble(enemy: Ghoul) -> void:
	var bubble = duplicate()
	bubble.global_position = enemy.global_position
	bubble.player = player
	bubble.secondary_created = secondary_created + 1
	bubble.frozen_enemies = frozen_enemies.duplicate()
	get_tree().current_scene.add_child(bubble)
