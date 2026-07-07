class_name Player
extends CharacterBody2D

const SPEED := 90.0  # px/s (~5.6 tiles/s)
const ARRIVE_DISTANCE := 4.0  # px — perto o bastante do alvo para parar sem "vibrar"

var _target := Vector2.ZERO
var _moving := false


func _physics_process(_delta: float) -> void:
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
