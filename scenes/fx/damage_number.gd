extends Label

var velocity := Vector2.ZERO
var lifetime := 1.5
var time_left := 0.0


func _ready() -> void:
	time_left = lifetime
	velocity = Vector2(randf_range(-30, 30), -60)
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_color", Color.WHITE)


func _physics_process(delta: float) -> void:
	time_left -= delta
	global_position += velocity * delta
	velocity.y -= 20 * delta  # gravidade

	var progress = time_left / lifetime
	modulate.a = progress

	if time_left <= 0.0:
		queue_free()
