class_name ItemPickup
extends Area3D
## Item largado no chão (collision layer "pickups"). O player encosta, o item
## entra no inventário via EventBus e o pickup some.

@export var item: Dictionary = {}

@onready var _label: Label3D = $Label3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_label.text = item.get("icon", "?")


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	EventBus.item_picked_up.emit(item)
	queue_free()
