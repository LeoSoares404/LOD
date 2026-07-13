extends CanvasLayer
## Menu de PAUSA (abre com ESC): pausa o jogo. Página inicial com Continuar /
## Configuração / Sair. "Configuração" abre uma sub-página (mesma moldura) com
## Áudio e Estilo de jogo (Clássico=mouse / Moderno=WASD).

@onready var menu_panel: Control = $MenuPanel
@onready var pause_page: VBoxContainer = $MenuPanel/Window/PausePage
@onready var config_page: VBoxContainer = $MenuPanel/Window/ConfigPage

@onready var continue_button: Button = $MenuPanel/Window/PausePage/ContinueButton
@onready var config_button: Button = $MenuPanel/Window/PausePage/ConfigButton
@onready var quit_button: Button = $MenuPanel/Window/PausePage/QuitButton

@onready var volume_slider: HSlider = $MenuPanel/Window/ConfigPage/VolumeSlider
@onready var classico_button: Button = $MenuPanel/Window/ConfigPage/ClassicoButton
@onready var moderno_button: Button = $MenuPanel/Window/ConfigPage/ModernoButton
@onready var voltar_button: Button = $MenuPanel/Window/ConfigPage/VoltarButton

var is_open := false
var _master_bus := AudioServer.get_bus_index("Master")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # continua funcionando com o jogo pausado
	menu_panel.visible = false
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(_master_bus))
	classico_button.button_pressed = GameState.control_scheme == "mouse"
	moderno_button.button_pressed = GameState.control_scheme == "wasd"

	continue_button.pressed.connect(toggle_menu)
	config_button.pressed.connect(_show_config)
	quit_button.pressed.connect(_on_quit_pressed)
	voltar_button.pressed.connect(_show_pause)
	volume_slider.value_changed.connect(_on_volume_changed)
	classico_button.toggled.connect(_on_scheme_toggled.bind("mouse"))
	moderno_button.toggled.connect(_on_scheme_toggled.bind("wasd"))


## ESC abre/fecha a pausa. process_mode = ALWAYS garante o evento com o jogo
## pausado. is_key_just_pressed() não existe na API do Godot.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		toggle_menu()


func toggle_menu() -> void:
	is_open = not is_open
	menu_panel.visible = is_open
	if is_open:
		_show_pause()  # sempre abre na página principal
	GameState.toggle_pause()


func _show_config() -> void:
	pause_page.visible = false
	config_page.visible = true


func _show_pause() -> void:
	config_page.visible = false
	pause_page.visible = true


func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(value))


func _on_scheme_toggled(pressed: bool, scheme: String) -> void:
	if pressed:
		GameState.control_scheme = scheme


## Volta ao menu principal. Recarregar a cena reseta a fase (WaveManager zera
## current_wave), mas o nível/XP ficam no GameState e são mantidos.
func _on_quit_pressed() -> void:
	get_tree().paused = false  # o pause é do tree e sobrevive à troca de cena
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
