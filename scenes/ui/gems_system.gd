extends CanvasLayer

const GEM_TYPES = {
	"red": {"name": "Dano", "icon": "🔴", "effect": "damage", "value": 0.25},
	"green": {"name": "Economia", "icon": "🟢", "effect": "mana_cost", "value": 0.25},
	"blue": {"name": "Projéteis", "icon": "🔵", "effect": "projectiles", "value": 2},
	"yellow": {"name": "Tamanho", "icon": "🟡", "effect": "size", "value": 0.25},
}

@onready var panel: Panel = $Panel
@onready var skills_container: HBoxContainer = $Panel/VBoxContainer/SkillsContainer

var is_open := false
var equipped_gems := {0: [], 1: [], 2: [], 3: []}
var slot_containers := {}


func _ready() -> void:
	panel.visible = false
	_create_skill_slots()


## Input.is_key_just_pressed() não existe na API — detecta o aperto via evento.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_CTRL:
		toggle_gems_ui()


func toggle_gems_ui() -> void:
	is_open = !is_open
	panel.visible = is_open


func _create_skill_slots() -> void:
	for slot in range(4):
		var vbox = VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(100, 150)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		# slot de pedra (CircleRect simulado com ColorRect)
		var gem_slot = Control.new()
		gem_slot.custom_minimum_size = Vector2(70, 70)
		gem_slot.mouse_filter = Control.MOUSE_FILTER_STOP

		var slot_rect = ColorRect.new()
		slot_rect.color = Color(0.3, 0.3, 0.3, 0.8)
		slot_rect.custom_minimum_size = Vector2(70, 70)
		slot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem_slot.add_child(slot_rect)

		# detectar drop (drop_mode/DROP_MODE_ON_ITEM é da classe Tree, não de
		# Control — em Control usa-se forwarding de _can_drop_data/_drop_data)
		gem_slot.set_drag_forwarding(
			_no_drag, _can_drop_on_slot.bind(slot), _drop_on_slot.bind(slot)
		)

		var gems_display = HBoxContainer.new()
		gems_display.custom_minimum_size = Vector2(70, 70)
		gems_display.alignment = BoxContainer.ALIGNMENT_CENTER
		gems_display.name = "GemsDisplay_%d" % slot
		gem_slot.add_child(gems_display)

		vbox.add_child(gem_slot)
		slot_containers[slot] = gem_slot

		var label = Label.new()
		label.text = ["Q", "W", "E", "R"][slot]
		label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(label)

		skills_container.add_child(vbox)


func _no_drag(_at_position: Vector2) -> Variant:
	return null


func _can_drop_on_slot(_at_position: Vector2, data: Variant, _slot: int) -> bool:
	return typeof(data) == TYPE_STRING and data in GEM_TYPES


func _drop_on_slot(_at_position: Vector2, data: Variant, slot: int) -> void:
	if typeof(data) == TYPE_STRING and data in GEM_TYPES:
		equipped_gems[slot].append(data)
		_update_gem_display(slot)
		print("Pedra %s equipada no slot %s" % [data, ["Q", "W", "E", "R"][slot]])


func _update_gem_display(slot: int) -> void:
	var container = slot_containers[slot].get_node("GemsDisplay_%d" % slot)

	# limpa display anterior
	for child in container.get_children():
		child.queue_free()

	# mostra gems equipadas
	for gem_type in equipped_gems[slot]:
		var label = Label.new()
		label.text = GEM_TYPES[gem_type]["icon"]
		label.add_theme_font_size_override("font_size", 20)
		container.add_child(label)


func get_equipped_gems(slot: int) -> Array:
	return equipped_gems[slot]
