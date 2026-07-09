extends CanvasLayer
## Menu de PAUSA (abre com ESC): pausa o jogo e concentra as configurações —
## volume master, esquema de controle (mouse/WASD), continuar e sair.

@onready var menu_panel: Panel = $MenuPanel
@onready var continue_button: Button = $MenuPanel/VBoxContainer/ContinueButton
@onready var volume_slider: HSlider = $MenuPanel/VBoxContainer/VolumeSlider
@onready var mouse_button: Button = $MenuPanel/VBoxContainer/SchemeRow/MouseButton
@onready var wasd_button: Button = $MenuPanel/VBoxContainer/SchemeRow/WasdButton
@onready var quit_button: Button = $MenuPanel/VBoxContainer/QuitButton

var is_open := false
var _master_bus := AudioServer.get_bus_index("Master")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # continua funcionando com o jogo pausado
	menu_panel.visible = false
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(_master_bus))
	volume_slider.value_changed.connect(_on_volume_changed)
	mouse_button.button_pressed = GameState.control_scheme == "mouse"
	wasd_button.button_pressed = GameState.control_scheme == "wasd"
	mouse_button.toggled.connect(_on_scheme_toggled.bind("mouse"))
	wasd_button.toggled.connect(_on_scheme_toggled.bind("wasd"))
	quit_button.pressed.connect(_on_quit_pressed)
	continue_button.pressed.connect(toggle_menu)  # "Continuar" = fecha e despausa


## ESC abre/fecha a pausa. process_mode = ALWAYS garante que o evento chega
## mesmo com o jogo pausado. is_key_just_pressed() não existe na API do Godot.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		toggle_menu()


func toggle_menu() -> void:
	is_open = !is_open
	menu_panel.visible = is_open
	GameState.toggle_pause()


func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(value))


func _on_scheme_toggled(pressed: bool, scheme: String) -> void:
	if pressed:
		GameState.control_scheme = scheme


func _on_quit_pressed() -> void:
	get_tree().quit()
