extends CanvasLayer

# Todas as skills disponíveis no jogo
const ALL_SKILLS = [
	{"name": "Raio", "icon": "⚡"},
	{"name": "Bolha", "icon": "🫧"},
	{"name": "Pilar de Fogo", "icon": "🔥"},
	{"name": "Superataque", "icon": "✨"},
	{"name": "Bolt Mágico", "icon": "✦"},
	{"name": "Arcane Nova", "icon": "◆"},
	{"name": "Chuva de Meteoros", "icon": "☄"},
]

@onready var menu_panel: Panel = $MenuPanel
@onready var equipped_container: VBoxContainer = $MenuPanel/VBoxContainer/EquippedContainer
@onready var available_container: GridContainer = $MenuPanel/VBoxContainer/AvailableContainer

var is_open := false
var selected_slot := -1
var current_equipped = [0, 1, 2, 3]  # índices das skills equipadas em Q, W, E, R


func _ready() -> void:
	menu_panel.visible = false
	_create_equipped_slots()
	_create_available_skills()


## Input.is_key_just_pressed() não existe na API — detecta o aperto via evento.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_I:
		if is_open:
			toggle_menu()


func toggle_menu() -> void:
	is_open = !is_open
	menu_panel.visible = is_open


func _create_equipped_slots() -> void:
	for i in range(4):
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(0, 40)

		var slot_label = Label.new()
		slot_label.text = ["Q", "W", "E", "R"][i]
		slot_label.custom_minimum_size = Vector2(30, 0)
		hbox.add_child(slot_label)

		var skill_button = Button.new()
		skill_button.text = ALL_SKILLS[current_equipped[i]]["icon"] + " " + ALL_SKILLS[current_equipped[i]]["name"]
		skill_button.custom_minimum_size = Vector2(150, 0)
		skill_button.toggled.connect(_on_slot_selected.bindv([i]))
		skill_button.toggle_mode = true
		hbox.add_child(skill_button)

		equipped_container.add_child(hbox)


func _create_available_skills() -> void:
	for i in ALL_SKILLS.size():
		var skill = ALL_SKILLS[i]
		var button = Button.new()
		button.text = skill["icon"] + "\n" + skill["name"]
		button.custom_minimum_size = Vector2(80, 80)
		button.pressed.connect(_on_skill_pressed.bindv([i]))
		available_container.add_child(button)


func _on_slot_selected(toggled: bool, slot: int) -> void:
	if toggled:
		selected_slot = slot
		print("Slot %s selecionado" % ["Q", "W", "E", "R"][slot])


func _on_skill_pressed(skill_index: int) -> void:
	if selected_slot != -1:
		current_equipped[selected_slot] = skill_index
		print("Equipou %s no slot %s" % [ALL_SKILLS[skill_index]["name"], ["Q", "W", "E", "R"][selected_slot]])
		_refresh_equipped_display()


func _refresh_equipped_display() -> void:
	for i in range(4):
		var hbox = equipped_container.get_child(i)
		var button = hbox.get_child(1)
		var skill = ALL_SKILLS[current_equipped[i]]
		button.text = skill["icon"] + " " + skill["name"]
