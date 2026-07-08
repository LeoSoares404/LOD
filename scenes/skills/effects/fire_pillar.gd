extends Area2D

var player: Node2D
var time_left: float
var time_until_tick: float
var damaged_enemies: Dictionary = {}


func _ready() -> void:
	time_left = player.PILLAR_DURATION
	time_until_tick = player.PILLAR_TICK_RATE

	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = player.PILLAR_RADIUS
	add_child(collision)

	modulate = Color(1.0, 0.5, 0.0, 0.8)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	time_left -= delta
	time_until_tick -= delta

	# escala vai de 1 (início) a 1.5 (fim) em Y simulando chamas subindo
	var progress = 1.0 - (time_left / player.PILLAR_DURATION)
	scale = Vector2(1.0, 1.0 + progress * 0.5)

	if time_until_tick <= 0.0:
		time_until_tick = player.PILLAR_TICK_RATE
		_apply_damage()

	if time_left <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var enemy = area.get_parent()
		if enemy is Ghoul and enemy not in damaged_enemies:
			damaged_enemies[enemy] = 0.0


func _apply_damage() -> void:
	var to_remove = []

	for enemy in damaged_enemies.keys():
		if is_instance_valid(enemy):
			damaged_enemies[enemy] += player.PILLAR_TICK_RATE
			# causa dano via HitboxComponent
			var hitbox = HitboxComponent.new()
			hitbox.damage = 8
			hitbox.stun_duration = 0.0
			if enemy.has_node("Hurtbox"):
				enemy.get_node("Hurtbox").hit_received.emit(hitbox)
		else:
			to_remove.append(enemy)

	for enemy in to_remove:
		damaged_enemies.erase(enemy)
