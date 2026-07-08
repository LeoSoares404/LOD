class_name CameraRig
extends Node3D
## Rig da câmera 2.5D isométrica fixa (estilo Diablo, como a referência):
## segue o player com suavização. A inclinação (Iso.CAM_PITCH) fica no rig;
## a Camera3D filha é ortográfica e recuada no eixo local.

const SMOOTH := 8.0

var _target: Node3D


func _ready() -> void:
	rotation_degrees.x = Iso.CAM_PITCH
	_target = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_target):
		global_position = _target.global_position


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player")
		return
	var k := 1.0 - exp(-SMOOTH * delta)
	global_position = global_position.lerp(_target.global_position, k)
