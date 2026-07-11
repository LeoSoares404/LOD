class_name CameraRig
extends Node3D
## Rig da câmera 2.5D isométrica fixa (estilo Diablo, como a referência):
## segue o player com suavização. A inclinação (Iso.CAM_PITCH) fica no rig;
## a Camera3D filha é ortográfica e recuada no eixo local.

const SMOOTH := 8.0

var _target: Node3D
var _base_pos := Vector3.ZERO   # posição do follow, antes do shake
var _shake_time := 0.0
var _shake_dur := 0.0
var _shake_amount := 0.0


func _ready() -> void:
	rotation_degrees.x = Iso.CAM_PITCH
	add_to_group("camera_rig")   # golpes pesados chamam shake() por aqui
	_target = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_target):
		global_position = _target.global_position
		_base_pos = _target.global_position


## Tremor decrescente somado ao follow — impacto de golpe pesado, etc.
func shake(amount: float, duration: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)
	_shake_time = duration
	_shake_dur = duration


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player")
		return
	var k := 1.0 - exp(-SMOOTH * delta)
	_base_pos = _base_pos.lerp(_target.global_position, k)

	var offset := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		var s := _shake_amount * (_shake_time / _shake_dur)  # decai linear até 0
		offset = Vector3(randf_range(-s, s), 0.0, randf_range(-s, s))

	global_position = _base_pos + offset
