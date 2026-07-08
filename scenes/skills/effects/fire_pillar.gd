extends Area3D
## Pilar de fogo (E): área que aplica dano por tick em quem estiver dentro.

const GLOW := preload("res://assets/sprites/props/glow_gradient.tres")

var player: Node3D
var time_left: float
var time_until_tick: float
var damaged_enemies: Dictionary = {}

var _visual: Sprite3D


func _ready() -> void:
	time_left = player.PILLAR_DURATION
	time_until_tick = player.PILLAR_TICK_RATE

	collision_layer = 0
	collision_mask = 16  # enemy_hurtbox — antes ficava no default (1) e nunca detectava

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = player.PILLAR_RADIUS
	collision.shape = sphere
	collision.position.y = 0.75
	add_child(collision)

	_visual = Sprite3D.new()
	_visual.texture = GLOW
	_visual.pixel_size = 1.0 / Iso.PPM
	_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual.modulate = Color(2.0, 1.0, 0.0, 0.8)
	_visual.scale = Vector3(0.63, 0.63, 1.0)
	_visual.position.y = 1.5
	add_child(_visual)

	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	time_left -= delta
	time_until_tick -= delta

	# escala vai de 1 (início) a 1.5 (fim) em Y simulando chamas subindo
	var progress: float = 1.0 - (time_left / player.PILLAR_DURATION)
	if is_instance_valid(_visual):
		_visual.scale.y = 0.63 * (1.0 + progress * 0.5)

	if time_until_tick <= 0.0:
		time_until_tick = player.PILLAR_TICK_RATE
		_apply_damage()

	if time_left <= 0.0:
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	if area is HurtboxComponent:
		var enemy = area.get_parent()
		if enemy is Node3D and enemy.is_in_group("enemies") and enemy not in damaged_enemies:
			damaged_enemies[enemy] = 0.0


func _apply_damage() -> void:
	var to_remove := []

	for enemy in damaged_enemies.keys():
		if is_instance_valid(enemy):
			damaged_enemies[enemy] += player.PILLAR_TICK_RATE
			# causa dano via HitboxComponent
			var hitbox := HitboxComponent.new()
			hitbox.damage = 8
			hitbox.stun_duration = 0.0
			if enemy.has_node("Hurtbox"):
				enemy.get_node("Hurtbox").take_hit(hitbox)
			hitbox.queue_free()
		else:
			to_remove.append(enemy)

	for enemy in to_remove:
		damaged_enemies.erase(enemy)
