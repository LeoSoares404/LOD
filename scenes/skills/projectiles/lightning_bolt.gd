extends Node2D

const HITBOX_SCENE = preload("res://scenes/entities/projectiles/magic_bolt.tscn")

var target: Vector2 = Vector2.ZERO
var player: Node2D
var direction: Vector2 = Vector2.RIGHT
var bounces_left := 3
var last_targets: Array = []
var time_alive := 0.0
var speed := 400.0
var lifetime := 5.0


func _ready() -> void:
	# visual simples - linha de luz
	var line = Line2D.new()
	line.default_color = Color(0.8, 1.0, 1.0)
	line.width = 4.0
	line.add_point(Vector2.ZERO)
	line.add_point(direction * 30.0)
	add_child(line)

	direction = (target - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	rotation = direction.angle()
	time_alive = 0.0
	bounces_left = player.LIGHTNING_BOUNCES


func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive > lifetime:
		queue_free()
		return

	global_position += direction * speed * delta

	if bounces_left > 0 and target.distance_to(global_position) < 20.0:
		_bounce()


func _bounce() -> void:
	bounces_left -= 1
	last_targets.append(target)

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = CircleShape2D.new()
	query.shape.radius = player.LIGHTNING_BOUNCE_RANGE
	query.transform = Transform2D.IDENTITY.translated(global_position)

	var results = space_state.intersect_shape(query)

	var next_target: Node2D = null
	var closest_dist := INF

	for result in results:
		if result.collider is Ghoul and result.collider not in last_targets:
			var dist := global_position.distance_to(result.collider.global_position)
			if dist < closest_dist:
				closest_dist = dist
				next_target = result.collider

	if next_target:
		target = next_target.global_position
		direction = (target - global_position).normalized()
		rotation = direction.angle()

		# causa dano via HitboxComponent
		var hitbox = HitboxComponent.new()
		hitbox.damage = 20
		hitbox.stun_duration = 0.3
		if next_target.has_node("Hurtbox"):
			next_target.get_node("Hurtbox").hit_received.emit(hitbox)
	else:
		queue_free()
