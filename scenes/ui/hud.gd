extends CanvasLayer
## HUD: orbes de vida/mana + hotbar com cooldown radial.
## Só ESCUTA o EventBus — nunca referencia player/entidades (ARCHITECTURE.md).

const SLOT_COUNT := 4

@onready var health_orb: ColorRect = %HealthOrb
@onready var mana_orb: ColorRect = %ManaOrb
@onready var banner: Label = %WaveBanner
@onready var counter: Label = %WaveCounter

var _cd_remaining: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _cd_total: Array[float] = [1.0, 1.0, 1.0, 1.0]
var _overlays: Array[ColorRect] = []


func _ready() -> void:
	for i in SLOT_COUNT:
		_overlays.append(get_node("Hotbar/Slot%d/Cooldown" % i))
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_mana_changed.connect(_on_mana_changed)
	EventBus.skill_cooldown_started.connect(_on_cooldown_started)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.victory.connect(_on_victory)
	banner.modulate.a = 0.0


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


func _on_wave_started(wave: int, is_boss: bool) -> void:
	if is_boss:
		counter.text = "CHEFE"
		_flash_banner("⚠ CHEFE ⚠", Color(1.0, 0.4, 0.3))
	else:
		counter.text = "Rodada %d" % wave
		_flash_banner("RODADA %d" % wave, Color(0.6, 1.0, 0.95))


func _on_victory() -> void:
	counter.text = ""
	_flash_banner("VITÓRIA!", Color(1.0, 0.9, 0.4), 5.0)


func _flash_banner(text: String, color: Color, hold := 1.6) -> void:
	banner.text = text
	banner.modulate = color
	banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(hold)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)
