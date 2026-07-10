extends CanvasLayer

const INVENTORY_SLOTS := 12
const GEM_ICONS := {"red": "🔴", "green": "🟢", "blue": "🔵", "yellow": "🟡"}

@onready var menu_panel: Panel = $MenuPanel
@onready var slots_container: GridContainer = $MenuPanel/VBoxContainer/SlotsContainer
@onready var weapon_slot: ColorRect = $MenuPanel/VBoxContainer/WeaponRow/WeaponSlot
@onready var settings_button: Button = $MenuPanel/VBoxContainer/SettingsButton

var is_open := false
var inventory_items: Array = []
var weapon_item: Dictionary = {}  # {} = slot vazio → auto-attack da classe
var skills_menu_node: Node = null
var gems_inventory = {
	"red": 3,    # 3 pedras vermelhas
	"green": 3,
	"blue": 3,
	"yellow": 3,
}


func _ready() -> void:
	menu_panel.visible = false
	inventory_items.resize(INVENTORY_SLOTS)
	_create_inventory_slots()
	_setup_weapon_slot()
	_create_gems_section()
	settings_button.pressed.connect(_on_settings_pressed)
	EventBus.item_picked_up.connect(add_item)

	# reflete o que o GameState já traz (a cena recarrega na morte, o autoload não)
	weapon_item = _current_weapon_item()
	_update_weapon_visual()


func _current_weapon_item() -> Dictionary:
	if GameState.equipped_weapon != "":
		return GameState.WEAPON_ITEMS.get(GameState.equipped_weapon, {})
	return GameState.WEAPONS.get(GameState.selected_class, {})


## Input.is_key_just_pressed() não existe na API — detecta o aperto via evento.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_I:
		toggle_menu()


func toggle_menu() -> void:
	is_open = !is_open
	menu_panel.visible = is_open


## Slots são ColorRect sem script: o drag-and-drop vem por set_drag_forwarding
## (mesmo caminho das pedras — Control só chama _get_drag_data em si mesmo).
func _create_inventory_slots() -> void:
	for i in INVENTORY_SLOTS:
		var slot := ColorRect.new()
		slot.color = Color(0.2, 0.2, 0.25, 0.8)
		slot.custom_minimum_size = Vector2(50, 50)
		slot.set_drag_forwarding(
			_get_slot_drag_data.bind(i, slot),
			_can_drop_on_slot.bind(i),
			_drop_on_slot.bind(i),
		)

		var label := Label.new()
		label.name = "Label"
		label.text = str(i + 1)
		label.add_theme_font_size_override("font_size", 10)
		slot.add_child(label)

		slots_container.add_child(slot)


func _setup_weapon_slot() -> void:
	weapon_slot.set_drag_forwarding(
		_get_weapon_drag_data.bind(weapon_slot), _can_drop_on_weapon, _drop_on_weapon
	)


## Adiciona no primeiro slot vazio. Retorna o índice ocupado, ou -1 se cheio.
func add_item(item: Dictionary) -> int:
	for i in INVENTORY_SLOTS:
		if inventory_items[i] == null:
			inventory_items[i] = item
			_update_slot_visual(i)
			return i
	return -1


## Remove o item do slot (sem efeito se já estiver vazio).
func remove_item(slot_index: int) -> void:
	if inventory_items[slot_index] == null:
		return
	inventory_items[slot_index] = null
	_update_slot_visual(slot_index)


# --- drag & drop ------------------------------------------------------------

func _get_slot_drag_data(_at_position: Vector2, slot_index: int, slot: ColorRect) -> Variant:
	var item: Variant = inventory_items[slot_index]
	if item == null:
		return null
	slot.set_drag_preview(_make_preview(item["icon"]))
	return {"src": "inv", "index": slot_index}


func _get_weapon_drag_data(_at_position: Vector2, slot: ColorRect) -> Variant:
	if weapon_item.is_empty():
		return null
	slot.set_drag_preview(_make_preview(weapon_item["icon"]))
	return {"src": "weapon"}


## Só aceita os dicts daqui — o drag das pedras carrega uma String.
func _can_drop_on_slot(_at_position: Vector2, data: Variant, _slot_index: int) -> bool:
	return data is Dictionary and data.has("src")


func _can_drop_on_weapon(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.get("src") == "inv"):
		return false
	var item: Variant = inventory_items[data["index"]]
	return item != null and item.has("weapon_id")


func _drop_on_slot(_at_position: Vector2, data: Variant, slot_index: int) -> void:
	if data["src"] == "weapon":
		if inventory_items[slot_index] != null:
			return  # desequipar só em slot vazio — nada de sobrescrever item
		inventory_items[slot_index] = weapon_item
		_update_slot_visual(slot_index)
		_equip({})
		return

	var from: int = data["index"]
	var swapped: Variant = inventory_items[slot_index]
	inventory_items[slot_index] = inventory_items[from]
	inventory_items[from] = swapped
	_update_slot_visual(slot_index)
	_update_slot_visual(from)


## A arma que estava equipada volta pro slot de onde a nova saiu — troca 1:1,
## sem depender de ter espaço livre no inventário.
func _drop_on_weapon(_at_position: Vector2, data: Variant) -> void:
	var from: int = data["index"]
	var incoming: Dictionary = inventory_items[from]
	inventory_items[from] = null if weapon_item.is_empty() else weapon_item
	_update_slot_visual(from)
	_equip(incoming)


## Slot de arma vazio = weapon_id "" = auto-attack padrão da classe.
func _equip(item: Dictionary) -> void:
	weapon_item = item
	_update_weapon_visual()
	EventBus.weapon_equipped.emit(item.get("weapon_id", ""))


func _update_slot_visual(slot_index: int) -> void:
	var slot: ColorRect = slots_container.get_child(slot_index)
	var label: Label = slot.get_node("Label")
	var item: Variant = inventory_items[slot_index]
	label.text = item["icon"] if item else str(slot_index + 1)


func _update_weapon_visual() -> void:
	var label: Label = weapon_slot.get_node("Label")
	label.text = weapon_item.get("icon", "—")


func _make_preview(icon: String) -> Control:
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(40, 40)
	var label := Label.new()
	label.text = icon
	label.add_theme_font_size_override("font_size", 20)
	preview.add_child(label)
	return preview


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

	for gem_type in GEM_ICONS:
		var gem_button = Button.new()
		gem_button.text = GEM_ICONS[gem_type] + "\n" + str(gems_inventory[gem_type])
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
	button.set_drag_preview(_make_preview(GEM_ICONS[gem_type]))
	return gem_type


func _cant_drop(_at_position: Vector2, _data: Variant) -> bool:
	return false


func _no_drop(_at_position: Vector2, _data: Variant) -> void:
	pass
