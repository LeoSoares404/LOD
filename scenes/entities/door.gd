class_name WorldDoor
extends Area3D
## Passagem entre cenas. Clicar na porta OU encostar nela troca de cena.
## (mover é botão direito; então andar até a porta também funciona.)

@export_file("*.tscn") var target_scene: String = ""

var _used := false


func _ready() -> void:
	input_ray_pickable = true
	get_viewport().physics_object_picking = true  # habilita clique em objeto 3D
	input_event.connect(_on_input_event)
	body_entered.connect(_on_body_entered)


func _on_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_use()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_use()


func _use() -> void:
	if _used or target_scene == "":
		return
	_used = true
	get_tree().change_scene_to_file.call_deferred(target_scene)
