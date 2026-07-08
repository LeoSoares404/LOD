extends Node2D
## Gerencia as rodadas: 4 → 6 → 8 ghouls e por fim o BOSS.
## A próxima rodada só começa quando todos os inimigos da atual morrem.

const GHOUL_SCENE := preload("res://scenes/entities/enemies/ghoul.tscn")
const BOSS_SCENE := preload("res://scenes/entities/enemies/ghoul_boss.tscn")

const GHOUL_WAVES := [4, 6, 8]  # quantidade por rodada; depois vem o boss
const FIRST_DELAY := 1.5        # s antes da 1ª rodada
const NEXT_DELAY := 2.5         # s entre limpar uma rodada e iniciar a próxima

const MAP_W := 960
const MAP_H := 544
const MARGIN := 70              # inset das bordas para o spawn
const MIN_PLAYER_DIST := 180.0  # não nascer em cima do player

var _wave := 0
var _alive := 0
var _active := false
var _player: Node2D
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
		EventBus.wave_started.emit(_wave, false)
	else:
		_spawn_boss()
		EventBus.wave_started.emit(_wave, true)


func _spawn_ghouls(count: int) -> void:
	_active = true
	for i in count:
		_spawn(GHOUL_SCENE.instantiate(), _random_spawn())


func _spawn_boss() -> void:
	_active = true
	_spawn(BOSS_SCENE.instantiate(), Vector2(MAP_W / 2.0, 170))


func _spawn(enemy: Node2D, pos: Vector2) -> void:
	enemy.position = pos
	get_tree().current_scene.add_child(enemy)
	_alive += 1


func _on_enemy_died(_data: Resource, _pos: Vector2) -> void:
	_alive -= 1
	if not _active or _alive > 0:
		return
	_active = false
	if _wave <= GHOUL_WAVES.size():
		_schedule_next(NEXT_DELAY)
	else:
		EventBus.victory.emit()  # boss derrotado


## Ponto aleatório no anel externo do mapa, longe do player.
func _random_spawn() -> Vector2:
	var player_pos := _player.global_position if is_instance_valid(_player) else Vector2(MAP_W, MAP_H) / 2.0
	for _attempt in 20:
		var p := Vector2(
			_rng.randf_range(MARGIN, MAP_W - MARGIN),
			_rng.randf_range(MARGIN, MAP_H - MARGIN)
		)
		if p.distance_to(player_pos) >= MIN_PLAYER_DIST:
			return p
	return Vector2(MARGIN, MARGIN)  # fallback
