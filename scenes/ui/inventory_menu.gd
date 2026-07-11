extends CanvasLayer
## Inventário com moldura dark-fantasy (inventory_frame.png).
## Os 12 slots são posicionados sobre os sockets da arte (grade 4x3).
## Itens são Dictionaries {"name","icon"[,"weapon_id"]}; entram por pickup ou arma inicial.
##
## Sistema de arma integrado por clique: clicar num item que é arma (tem "weapon_id")
## equipa aquela arma (glow dourado no socket) e emite EventBus.weapon_equipped —
## o Player escuta e troca o auto-attack. Clicar na arma já equipada volta pro
## auto-attack padrão da classe (weapon_id "").

const INVENTORY_SLOTS := 12
const GRID_COLS := 4
const GRID_ROWS := 3

# tamanho em que a moldura é exibida (base 640x360; mantém o ratio 944x1680)
const FRAME_W := 190.0
const FRAME_H := 338.0

# retângulo interno da grade, em fração da moldura (medido na arte)
const GRID_L := 0.1144
const GRID_R := 0.8877
const GRID_T := 0.2488
const GRID_B := 0.6994

const SLOT_W := 30.0
const SLOT_H := 44.0

const HOVER_TINT := Color(0.7, 0.5, 1.0, 0.25)      # brilho roxo sutil no hover
const EQUIPPED_TINT := Color(1.0, 0.78, 0.3, 0.5)   # glow dourado na arma equipada
const EMPTY_TINT := Color(1, 1, 1, 0)               # invisível: mostra o socket da arte

@onready var root: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var frame: TextureRect = $Root/Frame
@onready var gems_row: HBoxContainer = $Root/Frame/GemsRow
@onready var skills_button: Button = $Root/SkillsButton

var is_open := false
var inventory_items: Array = []
var _slots: Array[Panel] = []
var gems_inventory := {
	"red": 3,
	"green": 3,
	"blue": 3,
	"yellow": 3,
}


func _ready() -> void:
	root.visible = false
	inventory_items.resize(INVENTORY_SLOTS)
	_create_inventory_slots()
	_create_gems_section()
	dim.gui_input.connect(_on_dim_input)  # clicar no fundo escuro fecha
	skills_button.pressed.connect(_on_skills_pressed)
	EventBus.item_picked_up.connect(add_item)

	# cada classe nasce com sua arma inicial no inventário (equipada por padrão)
	var starting_weapon: Dictionary = GameState.WEAPONS.get(GameState.selected_class, {})
	if not starting_weapon.is_empty():
		add_item(starting_weapon)

	# a cena recarrega na morte mas o GameState (autoload) não: se havia uma arma
	# dropada equipada, recoloca ela no inventário pra refletir o estado atual
	if GameState.equipped_weapon != "":
		var w: Dictionary = GameState.WEAPON_ITEMS.get(GameState.equipped_weapon, {})
		if not w.is_empty():
			add_item(w)

	_refresh_equipped()


## Input.is_key_just_pressed() não existe na API — detecta o aperto via evento.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_I:
			toggle_menu()
		elif event.physical_keycode == KEY_ESCAPE and is_open:
			_close()


func toggle_menu() -> void:
	is_open = not is_open
	root.visible = is_open


func _close() -> void:
	is_open = false
	root.visible = false


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _on_skills_pressed() -> void:
	var skills_menu := get_tree().root.get_node_or_null("Main/SkillsMenu")
	if skills_menu:
		skills_menu.toggle_menu()


func _create_inventory_slots() -> void:
	var col_pitch := (GRID_R - GRID_L) / GRID_COLS
	var row_pitch := (GRID_B - GRID_T) / GRID_ROWS
	for i in INVENTORY_SLOTS:
		var c := i % GRID_COLS
		var r := i / GRID_COLS
		var cx := (GRID_L + (c + 0.5) * col_pitch) * FRAME_W
		var cy := (GRID_T + (r + 0.5) * row_pitch) * FRAME_H

		var slot := Panel.new()
		slot.name = "Slot%d" % i
		slot.self_modulate = EMPTY_TINT
		slot.offset_left = cx - SLOT_W * 0.5
		slot.offset_top = cy - SLOT_H * 0.5
		slot.offset_right = cx + SLOT_W * 0.5
		slot.offset_bottom = cy + SLOT_H * 0.5
		slot.mouse_entered.connect(_on_slot_hovered.bind(slot))
		slot.mouse_exited.connect(_on_slot_unhovered.bind(i))
		slot.gui_input.connect(_on_slot_gui_input.bind(i))

		# ícone do item (emoji) centralizado; vazio mostra só o socket da arte
		var icon := Label.new()
		icon.name = "Icon"
		icon.add_theme_font_size_override("font_size", 16)
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		frame.add_child(slot)
		_slots.append(slot)


func _on_slot_hovered(slot: Panel) -> void:
	slot.self_modulate = HOVER_TINT


func _on_slot_unhovered(slot_index: int) -> void:
	_apply_slot_tint(slot_index)  # volta pro glow de equipada, ou invisível


## Clique num slot: se o item for uma arma, equipa (ou desequipa se já ativa).
func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var item: Variant = inventory_items[slot_index]
		if item != null and item.has("weapon_id"):
			_equip(item["weapon_id"])


## Emite weapon_equipped: o Player seta GameState.equipped_weapon e troca o AA.
## Clicar na arma já equipada (weapon_id != "") destrava = volta pro AA da classe.
func _equip(weapon_id: String) -> void:
	if weapon_id != "" and weapon_id == GameState.equipped_weapon:
		weapon_id = ""  # toggle: desequipa → auto-attack padrão da classe
	EventBus.weapon_equipped.emit(weapon_id)  # Player atualiza GameState.equipped_weapon
	_refresh_equipped()


## Adiciona no primeiro slot vazio. Retorna o índice ocupado, ou -1 se cheio.
func add_item(item: Dictionary) -> int:
	for i in INVENTORY_SLOTS:
		if inventory_items[i] == null:
			inventory_items[i] = item
			_update_slot_visual(i)
			return i
	return -1


func _update_slot_visual(slot_index: int) -> void:
	var icon: Label = _slots[slot_index].get_node("Icon")
	var item: Variant = inventory_items[slot_index]
	icon.text = item["icon"] if item else ""


## Glow dourado no socket cujo item corresponde à arma ativa (equipped_weapon).
## equipped_weapon "" = a arma da classe (weapon_id "") fica marcada como ativa.
func _refresh_equipped() -> void:
	for i in INVENTORY_SLOTS:
		_apply_slot_tint(i)


func _apply_slot_tint(slot_index: int) -> void:
	var item: Variant = inventory_items[slot_index]
	var equipped: bool = item != null and item.has("weapon_id") \
			and item["weapon_id"] == GameState.equipped_weapon
	_slots[slot_index].self_modulate = EQUIPPED_TINT if equipped else EMPTY_TINT


func _create_gems_section() -> void:
	var gem_icons := {"red": "🔴", "green": "🟢", "blue": "🔵", "yellow": "🟡"}
	for gem_type: String in ["red", "green", "blue", "yellow"]:
		var gem_button := Button.new()
		gem_button.text = "%s\n%d" % [gem_icons[gem_type], gems_inventory[gem_type]]
		gem_button.add_theme_font_size_override("font_size", 7)
		gem_button.custom_minimum_size = Vector2(30, 30)
		gem_button.mouse_filter = Control.MOUSE_FILTER_STOP
		# permite drag dessa pedra (forwarding — Button não implementa _get_drag_data)
		gem_button.set_drag_forwarding(
			_get_gem_drag_data.bind(gem_type, gem_button), _cant_drop, _no_drop
		)
		gems_row.add_child(gem_button)


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
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(40, 40)
	var label := Label.new()
	label.text = {"red": "🔴", "green": "🟢", "blue": "🔵", "yellow": "🟡"}[gem_type]
	label.add_theme_font_size_override("font_size", 20)
	preview.add_child(label)
	return preview
