extends Label3D
## Número de dano flutuante: sobe acelerando e desaparece.

var vel := Vector3.ZERO
var lifetime := 1.5
var time_left := 0.0


func _ready() -> void:
	time_left = lifetime
	vel = Vector3(randf_range(-1.9, 1.9), 3.75, 0)


func _physics_process(delta: float) -> void:
	time_left -= delta
	global_position += vel * delta
	vel.y += 1.25 * delta  # acelera para cima (era gravidade invertida no 2D)

	modulate.a = time_left / lifetime

	if time_left <= 0.0:
		queue_free()
