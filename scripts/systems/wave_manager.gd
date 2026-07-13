extends Node
## Gerencia as 4 rodadas: 2 rodadas de inimigos comuns (ghouls + sprinters)
## → rodada 3 o boss à distância nasce sozinho → rodada 4 o DashBoss (melee,
## dash reto previsto). A próxima rodada só começa quando todos os inimigos
## da atual morrem. Posições agora em metros no plano XZ (16 px = 1 m).

const GHOUL_SCENE := preload("res://scenes/entities/enemies/ghoul.tscn")
const SPRINTER_SCENE := preload("res://scenes/entities/enemies/sprinter.tscn")
const DANIEL_SCENE := preload("res://scenes/entities/enemies/daniel.tscn")
const BOSS_SCENE := preload("res://scenes/entities/enemies/ghoul_boss.tscn")
const DASH_BOSS_SCENE := preload("res://scenes/entities/enemies/dash_boss.tscn")
const ITEM_PICKUP_SCENE := preload("res://scenes/entities/pickups/item_pickup.tscn")

const GHOUL_WAVES := [4, 6]     # quantidade de ghouls nas rodadas 1 e 2
const SPRINTER_WAVES := [0, 3]  # sprinters só entram com tudo na rodada 2
const DANIEL_WAVES := [1, 2]    # atiradores "pum" nas rodadas 1 e 2
const TOTAL_WAVES := 4          # 2 rodadas comuns + 2 rodadas de boss
const FIRST_DELAY := 1.5        # s antes da 1ª rodada
const NEXT_DELAY := 2.5         # s entre limpar uma rodada e iniciar a próxima

# Inferno: após limpar as 4 fases, o player é teleportado pra cá. 3 hordas — só
# ghouls (médios, com aura de fogo) e daniels (ranged, tiro que pega fogo), sem
# sprinters. Última horda é o boss de fogo. Todos dão 2x XP.
const HELL_GHOUL_WAVES := [5, 7]    # ghouls nas 2 primeiras hordas do inferno
const HELL_DANIEL_WAVES := [2, 3]   # ranged nas 2 primeiras hordas
const HELL_WAVES := 3               # 2 hordas + 1 boss de fogo
const HELL_PLAYER_SPAWN := Vector3(30.0, 0.0, 25.0)
const FIRE_BOSS_HP := 220           # boss de fogo, mais tanque que os outros

const MAP_W := 60.0             # m (era 960 px)
const MAP_H := 34.0             # m (era 544 px)
const MARGIN := 4.5             # inset das bordas para o spawn
const MIN_PLAYER_DIST := 11.0   # não nascer em cima do player

var _wave := 0
var _alive := 0
var _active := false
var _kills := 0
var _hell := false              # fase do inferno ativa
var _hell_wave := 0             # horda atual do inferno (1..HELL_WAVES)
var _player: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	GameState.current_wave = 0  # autoload sobrevive ao reload da cena; zera aqui
	GameState.hell_active = false
	_player = get_tree().get_first_node_in_group("player")
	EventBus.enemy_died.connect(_on_enemy_died)
	_schedule_next(FIRST_DELAY)


## Debug: "," pula direto pro inferno (a qualquer momento).
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_COMMA and not _hell:
		_enter_hell()


func _schedule_next(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if _hell:
		return  # "," pode ter entrado no inferno no meio de uma rodada agendada
	_wave += 1
	GameState.current_wave = _wave  # o auto-attack do player melhora por onda
	if _wave <= GHOUL_WAVES.size():
		_spawn_ghouls(GHOUL_WAVES[_wave - 1])
		_spawn_sprinters(SPRINTER_WAVES[_wave - 1])
		_spawn_daniels(DANIEL_WAVES[_wave - 1])
		EventBus.wave_started.emit(_wave, false)
	elif _wave == GHOUL_WAVES.size() + 1:
		_spawn_boss()
		EventBus.wave_started.emit(_wave, true)
	else:
		_spawn_dash_boss()
		EventBus.wave_started.emit(_wave, true)


func _spawn_ghouls(count: int) -> void:
	_active = true
	for i in count:
		_spawn(GHOUL_SCENE.instantiate(), _random_spawn())


func _spawn_sprinters(count: int) -> void:
	if count <= 0:
		return
	_active = true
	for i in count:
		_spawn(SPRINTER_SCENE.instantiate(), _random_spawn())


func _spawn_daniels(count: int) -> void:
	if count <= 0:
		return
	_active = true
	for i in count:
		_spawn(DANIEL_SCENE.instantiate(), _random_spawn())


func _spawn_boss() -> void:
	_active = true
	var boss := BOSS_SCENE.instantiate()
	_spawn(boss, Vector3(MAP_W / 2.0, 0.0, 10.6))
	_wire_boss_hp(boss, "DEMÔNIO")


func _spawn_dash_boss() -> void:
	_active = true
	var boss := DASH_BOSS_SCENE.instantiate()
	_spawn(boss, Vector3(MAP_W / 2.0, 0.0, 10.6))
	_wire_boss_hp(boss, "CEIFADOR")


## Entra na fase do inferno: limpa o que sobrou, troca o mapa, teleporta o player
## e engata as 3 hordas. Chamado ao limpar a 4ª fase OU pelo debug ",".
func _enter_hell() -> void:
	_hell = true
	_active = false
	_hell_wave = 0
	GameState.hell_active = true
	_clear_enemies()
	_swap_to_hell_map()
	if is_instance_valid(_player):
		_player.global_position = HELL_PLAYER_SPAWN
	EventBus.hell_started.emit()
	_schedule_hell(FIRST_DELAY)


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	_alive = 0


## Troca o mapa da cena (SwampMap → HellMap) mantendo player/câmera/HUD.
func _swap_to_hell_map() -> void:
	var main := get_parent()
	var old := main.get_node_or_null("SwampMap")
	if old:
		old.queue_free()
	var hell := HellMap.new()
	hell.name = "HellMap"
	main.add_child(hell)


func _schedule_hell(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not _hell:
		return
	_hell_wave += 1
	if _hell_wave < HELL_WAVES:
		_spawn_hell_ghouls(HELL_GHOUL_WAVES[_hell_wave - 1])
		_spawn_daniels(HELL_DANIEL_WAVES[_hell_wave - 1])
		EventBus.wave_started.emit(_hell_wave, false)
	else:
		_spawn_fire_boss()
		EventBus.wave_started.emit(_hell_wave, true)


## Ghouls do inferno = médios com aura de fogo (75% do alcance da rapieira).
func _spawn_hell_ghouls(count: int) -> void:
	_active = true
	for i in count:
		var g := GHOUL_SCENE.instantiate()
		g.add_child(FireAura.new())
		_spawn(g, _random_spawn())


## Boss de fogo: reusa o boss à distância (tiros já pegam fogo no inferno via
## EnemyBolt), com aura de fogo em volta e mais HP.
func _spawn_fire_boss() -> void:
	_active = true
	var boss := BOSS_SCENE.instantiate()
	boss.get_node("HealthComponent").max_health = FIRE_BOSS_HP
	boss.add_child(FireAura.new())
	_spawn(boss, Vector3(MAP_W / 2.0, 0.0, 8.0))
	_wire_boss_hp(boss, "🔥 SENHOR DAS CHAMAS 🔥")


## Liga a vida do boss à UI: emite o nascimento e repassa cada mudança de HP via
## EventBus (a HUD só escuta — não referencia o boss).
func _wire_boss_hp(boss: Node, boss_name: String) -> void:
	var hc: HealthComponent = boss.get_node("HealthComponent")
	EventBus.boss_spawned.emit(boss_name, hc.max_health)
	hc.health_changed.connect(
		func(cur: int, mx: int) -> void: EventBus.boss_health_changed.emit(cur, mx)
	)


func _spawn(enemy: Node3D, pos: Vector3) -> void:
	enemy.position = pos
	get_tree().current_scene.add_child(enemy)
	_alive += 1


const XP_PER_KILL := 1
const XP_PER_BOSS := 10

func _on_enemy_died(_data: Resource, pos: Vector3) -> void:
	# rodadas de boss só têm o boss vivo — vale mais XP; no inferno tudo dá 2x
	var is_boss := (_hell and _hell_wave >= HELL_WAVES) or (not _hell and _wave > GHOUL_WAVES.size())
	var xp := XP_PER_BOSS if is_boss else XP_PER_KILL
	if _hell:
		xp *= 2
	GameState.add_xp(xp)
	if not _hell:
		_maybe_drop_weapon(pos)  # drops de arma só na fase normal
	_alive -= 1
	if not _active or _alive > 0:
		return
	_active = false
	if _hell:
		if _hell_wave < HELL_WAVES:
			_schedule_hell(NEXT_DELAY)
		else:
			EventBus.victory.emit()  # boss de fogo derrotado — fim
	elif _wave < TOTAL_WAVES:
		_schedule_next(NEXT_DELAY)
	else:
		_enter_hell()  # 4 fases limpas → inferno


func _maybe_drop_weapon(pos: Vector3) -> void:
	var drops := GameState.ranged_weapon_drops()
	if _kills >= drops.size():
		return
	var weapon_id: String = drops[_kills]
	_kills += 1
	var pickup: ItemPickup = ITEM_PICKUP_SCENE.instantiate()
	pickup.item = GameState.WEAPON_ITEMS[weapon_id]
	pickup.position = pos
	get_tree().current_scene.add_child(pickup)


## Ponto aleatório no anel externo do mapa, longe do player.
func _random_spawn() -> Vector3:
	var player_pos := _player.global_position if is_instance_valid(_player) \
		else Vector3(MAP_W / 2.0, 0.0, MAP_H / 2.0)
	for _attempt in 20:
		var p := Vector3(
			_rng.randf_range(MARGIN, MAP_W - MARGIN),
			0.0,
			_rng.randf_range(MARGIN, MAP_H - MARGIN)
		)
		if p.distance_to(player_pos) >= MIN_PLAYER_DIST:
			return p
	return Vector3(MARGIN, 0.0, MARGIN)  # fallback
