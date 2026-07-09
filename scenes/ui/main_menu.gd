extends Control
## Tela inicial: Novo Jogo (escolha de classe) → Configuração → Sair.
## A classe escolhida vai pro GameState.selected_class antes de entrar no jogo.

const GAME_SCENE := "res://scenes/main.tscn"

@onready var title_page: Control = $TitlePage
@onready var class_page: Control = $ClassPage
@onready var config_page: Control = $ConfigPage

@onready var _cards: HBoxContainer = $ClassPage/Cards
@onready var _jogar: Button = $ClassPage/Bottom/Jogar

var _selected := ""
var _cards_by_class := {}


func _ready() -> void:
	_build_cards()
	_show_page(title_page)

	$TitlePage/Buttons/NovoJogo.pressed.connect(_show_page.bind(class_page))
	$TitlePage/Buttons/Config.pressed.connect(_show_page.bind(config_page))
	$TitlePage/Buttons/Sair.pressed.connect(func() -> void: get_tree().quit())

	$ClassPage/Bottom/Voltar.pressed.connect(_show_page.bind(title_page))
	_jogar.pressed.connect(_start_game)
	_jogar.disabled = true

	$ConfigPage/VBox/Voltar.pressed.connect(_show_page.bind(title_page))
	var bus := AudioServer.get_bus_index("Master")
	var volume: HSlider = $ConfigPage/VBox/VolumeSlider
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(bus))
	volume.value_changed.connect(
		func(v: float) -> void: AudioServer.set_bus_volume_db(bus, linear_to_db(v))
	)
	var classico: Button = $ConfigPage/VBox/ClassicoButton
	var moderno: Button = $ConfigPage/VBox/ModernoButton
	classico.button_pressed = GameState.control_scheme == "mouse"
	moderno.button_pressed = GameState.control_scheme == "wasd"
	classico.toggled.connect(_on_scheme.bind("mouse"))
	moderno.toggled.connect(_on_scheme.bind("wasd"))


func _on_scheme(pressed: bool, scheme: String) -> void:
	if pressed:
		GameState.control_scheme = scheme


func _show_page(page: Control) -> void:
	title_page.visible = page == title_page
	class_page.visible = page == class_page
	config_page.visible = page == config_page
	# escurece o wallpaper nas telas cheias de conteúdo (classe/config)
	$PageDim.visible = page != title_page


func _build_cards() -> void:
	for key in GameState.CLASSES:
		var card := _make_card(key, GameState.CLASSES[key])
		_cards.add_child(card)
		_cards_by_class[key] = card


func _make_card(key: String, data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 0)
	panel.self_modulate = Color(1, 1, 1, 0.5)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = data["nome"]
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var desc := Label.new()
	desc.text = data["desc"]
	desc.add_theme_font_size_override("font_size", 6)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(134, 40)
	vbox.add_child(desc)

	for attr: String in GameState.ATTR_ORDER:
		vbox.add_child(_attr_row(attr, data[attr]))

	var btn := Button.new()
	btn.text = "Escolher"
	btn.add_theme_font_size_override("font_size", 8)
	btn.custom_minimum_size = Vector2(0, 24)
	btn.pressed.connect(_on_select.bind(key))
	vbox.add_child(btn)
	return panel


func _attr_row(attr: String, value: int) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)

	var lbl := Label.new()
	lbl.text = "%s: %d" % [GameState.ATTR_LABEL[attr], value]
	lbl.add_theme_font_size_override("font_size", 6)
	col.add_child(lbl)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.12, 0.1, 0.9)
	bar_bg.custom_minimum_size = Vector2(130, 6)

	var fill := ColorRect.new()
	fill.color = Color(0.78, 0.58, 0.26)
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(float(value) / GameState.ATTR_MAX[attr], 0.05, 1.0)
	bar_bg.add_child(fill)

	col.add_child(bar_bg)
	return col


func _on_select(key: String) -> void:
	_selected = key
	for k: String in _cards_by_class:
		_cards_by_class[k].self_modulate = Color(1, 1, 1, 1) if k == key else Color(1, 1, 1, 0.5)
	_jogar.disabled = false
	_jogar.text = "Jogar como %s" % GameState.CLASSES[key]["nome"]


func _start_game() -> void:
	if _selected == "":
		return
	GameState.selected_class = _selected
	get_tree().change_scene_to_file(GAME_SCENE)
