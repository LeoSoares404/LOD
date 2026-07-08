extends Node3D
## Raio (Q): voa até o alvo e ricocheteia entre inimigos próximos.

var target := Vector3.ZERO
var player: Node3D
var direction := Vector3.RIGHT
var bounces_left := 3
var last_targets: Array = []
var time_alive := 0.0
var speed := 25.0    # m/s (era 400 px/s)
var lifetime := 5.0

const ENEMY_LAYER_MASK := 4


func _ready() -> void:
	# visual simples — feixe de luz (box fino e emissivo apontando para -Z)
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 1.9)
	beam.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 1.0, 1.0)
	mat.emission_energy_multiplier = 2.0
	beam.material_override = mat
	beam.position.z = -0.95
	add_child(beam)

	direction = target - global_position
	direction.y = 0.0
	direction = direction.normalized()
	if direction == Vector3.ZERO:
		direction = Vector3.RIGHT

	_face_direction()
	time_alive = 0.0
	bounces_left = player.LIGHTNING_BOUNCES


func _face_direction() -> void:
	look_at(global_position + direction)


func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive > lifetime:
		queue_free()
		return

	global_position += direction * speed * delta

	if bounces_left > 0 and Iso.flat_distance(target, global_position) < 1.25:
		_bounce()


func _bounce() -> void:
	bounces_left -= 1

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = player.LIGHTNING_BOUNCE_RANGE
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = ENEMY_LAYER_MASK

	var results := space_state.intersect_shape(query)

	var next_target: Node3D = null
	var closest_dist := INF

	for result in results:
		var collider: Object = result.collider
		if collider is Node3D and collider.is_in_group("enemies") and collider not in last_targets:
			var dist := Iso.flat_distance(global_position, collider.global_position)
			if dist < closest_dist:
				closest_dist = dist
				next_target = collider

	if next_target:
		last_targets.append(next_target)  # rastreia INIMIGOS já atingidos (antes guardava posições)
		target = next_target.global_position + Vector3(0, 0.75, 0)
		direction = target - global_position
		direction.y = 0.0
		direction = direction.normalized()
		_face_direction()

		# causa dano via HitboxComponent
		var hitbox := HitboxComponent.new()
		hitbox.damage = 20
		hitbox.stun_duration = 0.3
		if next_target.has_node("Hurtbox"):
			next_target.get_node("Hurtbox").take_hit(hitbox)
		hitbox.queue_free()
	else:
		queue_free()
