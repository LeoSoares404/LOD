extends CanvasLayer

const ARMOR_TYPES = [
	{"name": "Sem Armadura", "damage_reduction": 0.0, "color": Color(0.5, 0.5, 0.5)},
	{"name": "Armadura Leve", "damage_reduction": 0.15, "color": Color(0.8, 0.8, 0.4)},
	{"name": "Armadura Média", "damage_reduction": 0.30, "color": Color(0.7, 0.7, 0.8)},
	{"name": "Armadura Pesada", "damage_reduction": 0.45, "color": Color(0.6, 0.4, 0.3)},
]

@onready var menu_panel: Panel = $MenuPanel
@onready var options_container: VBoxContainer = $MenuPanel/VBoxContainer

var is_open := false
var current_armor := 0
var menu_buttons: Array = []


func _ready() -> void:
	menu_panel.visible = false
	_create_menu_options()


func _process(_delta: float) -> void:
	if Input.is_key_just_pressed(KEY_M):
		toggle_menu()


func toggle_menu() -> void:
	is_open = !is_open
	menu_panel.visible = is_open
	if is_open:
		menu_buttons[current_armor].grab_focus()


func _create_menu_options() -> void:
	for i in ARMOR_TYPES.size():
		var armor = ARMOR_TYPES[i]
		var button = Button.new()
		button.text = "%s (%d%% redução)" % [armor.name, int(armor.damage_reduction * 100)]
		button.custom_minimum_size = Vector2(200, 30)
		button.pressed.connect(_on_armor_selected.bindv([i]))
		options_container.add_child(button)
		menu_buttons.append(button)


func _on_armor_selected(index: int) -> void:
	current_armor = index
	var armor = ARMOR_TYPES[index]
	print("Armadura selecionada: %s" % armor.name)
	toggle_menu()
