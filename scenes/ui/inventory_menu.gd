extends CanvasLayer

const INVENTORY_SLOTS := 12

@onready var menu_panel: Panel = $MenuPanel
@onready var slots_container: GridContainer = $MenuPanel/VBoxContainer/SlotsContainer
@onready var settings_button: Button = $MenuPanel/VBoxContainer/SettingsButton

var is_open := false
var inventory_items: Array = []
var skills_menu_node: Node = null
var gems_inventory = {
	"red": 3,    # 3 pedras vermelhas
	"green": 3,
	"blue": 3,
	"yellow": 3,
}


func _ready() -> void:
	menu_panel.visible = false
	_create_inventory_slots()
	_create_gems_section()
	inventory_items.resize(INVENTORY_SLOTS)
	settings_button.pressed.connect(_on_settings_pressed)


## Input.is_key_just_pressed() não existe na API — detecta o aperto via evento.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_I:
		toggle_menu()


func toggle_menu() -> void:
	is_open = !is_open
	menu_panel.visible = is_open


func _create_inventory_slots() -> void:
	for i in INVENTORY_SLOTS:
		var slot = ColorRect.new()
		slot.color = Color(0.2, 0.2, 0.25, 0.8)
		slot.custom_minimum_size = Vector2(50, 50)
		slot.mouse_entered.connect(_on_slot_hovered.bindv([i]))

		var label = Label.new()
		label.text = str(i + 1)
		label.add_theme_font_size_override("font_size", 10)
		slot.add_child(label)

		slots_container.add_child(slot)


func _on_slot_hovered(slot_index: int) -> void:
	pass  # tooltip futuro


func _on_settings_pressed() -> void:
	var skills_menu = get_tree().root.get_node_or_null("Main/SkillsMenu")
	if skills_menu:
		skills_menu.toggle_menu()


func _create_gems_section() -> void:
	# adiciona seção de pedras dinamicamente
	var gems_label = Label.new()
	gems_label.text = "Pedras:"
	slots_container.add_child(gems_label)

	var gems_hbox = HBoxContainer.new()
	gems_hbox.custom_minimum_size = Vector2(0, 60)
	slots_container.add_child(gems_hbox)

	var gem_types = ["red", "green", "blue", "yellow"]
	var gem_icons = {"red": "🔴", "green": "🟢", "blue": "🔵", "yellow": "🟡"}

	for gem_type in gem_types:
		var gem_button = Button.new()
		gem_button.text = gem_icons[gem_type] + "\n" + str(gems_inventory[gem_type])
		gem_button.custom_minimum_size = Vector2(50, 50)
		gem_button.mouse_filter = Control.MOUSE_FILTER_STOP

		# permite drag dessa pedra (forwarding — Button não implementa _get_drag_data)
		gem_button.set_drag_forwarding(
			_get_gem_drag_data.bind(gem_type, gem_button), _cant_drop, _no_drop
		)

		gems_hbox.add_child(gem_button)


func _get_gem_drag_data(_at_position: Vector2, gem_type: String, button: Button) -> Variant:
	if gems_inventory[gem_type] <= 0:
		return null
	button.set_drag_preview(_create_gem_preview(gem_type))
	return gem_type


func _cant_drop(_at_position: Vector2, _data: Variant) -> bool:
	return false


func _no_drop(_at_position: Vector2, _data: Variant) -> void:
	pass


func _create_gem_preview(gem_type: String) -> Control:
	var preview = Control.new()
	preview.custom_minimum_size = Vector2(40, 40)
	var label = Label.new()
	label.text = {"red": "🔴", "green": "🟢", "blue": "🔵", "yellow": "🟡"}[gem_type]
	label.add_theme_font_size_override("font_size", 20)
	preview.add_child(label)
	return preview
