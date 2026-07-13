extends CanvasLayer
## HUD: orbes de vida/mana + hotbar com cooldown radial.
## Só ESCUTA o EventBus — nunca referencia player/entidades (ARCHITECTURE.md).

const SLOT_COUNT := 4
const TOTAL_WAVES := 4  # precisa bater com WaveManager.TOTAL_WAVES
const HELL_WAVES := 3   # precisa bater com WaveManager.HELL_WAVES

@onready var health_orb: TextureRect = %HealthOrb
@onready var mana_orb: TextureRect = %ManaOrb
@onready var banner: Label = %WaveBanner
@onready var counter: Label = %WaveCounter
@onready var inventory_button: Button = $InventoryButton
@onready var xp_fill: ColorRect = %Fill
@onready var level_label: Label = %LevelLabel

var _cd_remaining: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _cd_total: Array[float] = [1.0, 1.0, 1.0, 1.0]
var _overlays: Array[ColorRect] = []
var _wave_total := TOTAL_WAVES  # vira HELL_WAVES ao entrar no inferno

var _boss_ui: Control
var _boss_fill: ColorRect
var _boss_label: Label


func _ready() -> void:
	for i in SLOT_COUNT:
		_overlays.append(get_node("Hotbar/Slot%d/Cooldown" % i))
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_mana_changed.connect(_on_mana_changed)
	EventBus.skill_cooldown_started.connect(_on_cooldown_started)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.hell_started.connect(_on_hell_started)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_health_changed.connect(_on_boss_health_changed)
	EventBus.victory.connect(_on_victory)
	_build_boss_bar()
	EventBus.xp_gained.connect(_on_xp_gained)
	EventBus.player_leveled_up.connect(_on_leveled_up)
	inventory_button.pressed.connect(_on_inventory_pressed)
	banner.modulate.a = 0.0
	_refresh_level()  # nível persiste ao recarregar a cena; mostra o valor atual


func _process(delta: float) -> void:
	for i in SLOT_COUNT:
		if _cd_remaining[i] > 0.0:
			_cd_remaining[i] = maxf(_cd_remaining[i] - delta, 0.0)
			var mat: ShaderMaterial = _overlays[i].material
			mat.set_shader_parameter("progress", _cd_remaining[i] / _cd_total[i])


func _on_health_changed(current: int, max_health: int) -> void:
	var mat: ShaderMaterial = health_orb.material
	mat.set_shader_parameter("fill", float(current) / float(max_health))


func _on_mana_changed(current: int, max_mana: int) -> void:
	var mat: ShaderMaterial = mana_orb.material
	mat.set_shader_parameter("fill", float(current) / float(max_mana))


func _on_cooldown_started(slot: int, duration: float) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		return
	_cd_total[slot] = maxf(duration, 0.01)
	_cd_remaining[slot] = duration


func _on_xp_gained(_amount: int) -> void:
	_refresh_level()


func _on_leveled_up(new_level: int) -> void:
	_refresh_level()
	_flash_banner("NÍVEL %d" % new_level, Color(0.5, 0.9, 1.0), 1.0)


func _refresh_level() -> void:
	level_label.text = "Nv %d" % GameState.level
	xp_fill.anchor_right = clampf(float(GameState.xp) / float(GameState.xp_to_next()), 0.0, 1.0)


func _on_wave_started(wave: int, is_boss: bool) -> void:
	counter.text = "%d/%d ondas" % [wave, _wave_total]
	if is_boss:
		_flash_banner("⚠ CHEFE ⚠", Color(1.0, 0.4, 0.3))
	else:
		_flash_banner("RODADA %d" % wave, Color(0.6, 1.0, 0.95))


func _on_hell_started() -> void:
	_wave_total = HELL_WAVES
	counter.text = "0/%d ondas" % HELL_WAVES
	_flash_banner("🔥 INFERNO 🔥", Color(1.0, 0.35, 0.15), 2.5)


func _on_victory() -> void:
	counter.text = ""
	_boss_ui.visible = false
	_flash_banner("VITÓRIA!", Color(1.0, 0.9, 0.4), 5.0)


## Barra de vida do boss no topo — montada em código pra não mexer no hud.tscn.
func _build_boss_bar() -> void:
	const BAR_W := 560.0
	const BAR_H := 20.0
	_boss_ui = Control.new()
	_boss_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_ui.visible = false
	add_child(_boss_ui)

	_boss_label = Label.new()
	_boss_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_label.offset_top = 40.0
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_boss_ui.add_child(_boss_label)

	var back := ColorRect.new()
	back.color = Color(0.08, 0.04, 0.05, 0.85)
	back.anchor_left = 0.5
	back.anchor_right = 0.5
	back.offset_left = -BAR_W / 2.0
	back.offset_right = BAR_W / 2.0
	back.offset_top = 64.0
	back.offset_bottom = 64.0 + BAR_H
	_boss_ui.add_child(back)

	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(0.85, 0.18, 0.22)
	_boss_fill.set_anchors_preset(Control.PRESET_FULL_RECT)  # anchor_right vira a fração de HP
	back.add_child(_boss_fill)


func _on_boss_spawned(boss_name: String, _max_health: int) -> void:
	_boss_label.text = boss_name
	_boss_fill.anchor_right = 1.0
	_boss_ui.visible = true


func _on_boss_health_changed(current: int, max_health: int) -> void:
	_boss_fill.anchor_right = clampf(float(current) / float(max_health), 0.0, 1.0)
	if current <= 0:
		_boss_ui.visible = false


func _flash_banner(text: String, color: Color, hold := 1.6) -> void:
	banner.text = text
	banner.modulate = color
	banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(hold)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)


func _on_inventory_pressed() -> void:
	var inventory_menu = get_tree().root.get_node_or_null("Main/InventoryMenu")
	if inventory_menu:
		inventory_menu.toggle_menu()
