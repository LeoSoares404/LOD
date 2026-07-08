extends Node
## Gerencia as 4 rodadas: 2 rodadas de inimigos comuns (ghouls + sprinters)
## → rodada 3 o boss à distância nasce sozinho → rodada 4 o DashBoss (melee,
## dash reto previsto). A próxima rodada só começa quando todos os inimigos
## da atual morrem. Posições agora em metros no plano XZ (16 px = 1 m).

const GHOUL_SCENE := preload("res://scenes/entities/enemies/ghoul.tscn")
const SPRINTER_SCENE := preload("res://scenes/entities/enemies/sprinter.tscn")
const BOSS_SCENE := preload("res://scenes/entities/enemies/ghoul_boss.tscn")
const DASH_BOSS_SCENE := preload("res://scenes/entities/enemies/dash_boss.tscn")

const GHOUL_WAVES := [4, 6]     # quantidade de ghouls nas rodadas 1 e 2
const SPRINTER_WAVES := [0, 3]  # sprinters só entram com tudo na rodada 2
const TOTAL_WAVES := 4          # 2 rodadas comuns + 2 rodadas de boss
const FIRST_DELAY := 1.5        # s antes da 1ª rodada
const NEXT_DELAY := 2.5         # s entre limpar uma rodada e iniciar a próxima

const MAP_W := 60.0             # m (era 960 px)
const MAP_H := 34.0             # m (era 544 px)
const MARGIN := 4.5             # inset das bordas para o spawn
const MIN_PLAYER_DIST := 11.0   # não nascer em cima do player

var _wave := 0
var _alive := 0
var _active := false
var _player: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_player = get_tree().get_first_node_in_group("player")
	EventBus.enemy_died.connect(_on_enemy_died)
	_schedule_next(FIRST_DELAY)


func _schedule_next(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_wave += 1
	if _wave <= GHOUL_WAVES.size():
		_spawn_ghouls(GHOUL_WAVES[_wave - 1])
		_spawn_sprinters(SPRINTER_WAVES[_wave - 1])
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


func _spawn_boss() -> void:
	_active = true
	_spawn(BOSS_SCENE.instantiate(), Vector3(MAP_W / 2.0, 0.0, 10.6))


func _spawn_dash_boss() -> void:
	_active = true
	_spawn(DASH_BOSS_SCENE.instantiate(), Vector3(MAP_W / 2.0, 0.0, 10.6))


func _spawn(enemy: Node3D, pos: Vector3) -> void:
	enemy.position = pos
	get_tree().current_scene.add_child(enemy)
	_alive += 1


func _on_enemy_died(_data: Resource, _pos: Vector3) -> void:
	_alive -= 1
	if not _active or _alive > 0:
		return
	_active = false
	if _wave < TOTAL_WAVES:
		_schedule_next(NEXT_DELAY)
	else:
		EventBus.victory.emit()  # boss final derrotado


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
