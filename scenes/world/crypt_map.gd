extends Node2D
## Cripta — pinta o TileMapLayer proceduralmente com o tileset placeholder.
## Colisão das paredes vem do próprio TileSet (physics layer "world").

const MAP_W := 60  # tiles → 960 px
const MAP_H := 34  # tiles → 544 px

# coordenadas no atlas (crypt_tiles.png)
const FLOOR_A := Vector2i(0, 0)
const FLOOR_B := Vector2i(1, 0)
const FLOOR_CRACKED := Vector2i(2, 0)
const FLOOR_SPECKLED := Vector2i(3, 0)
const SLAB := Vector2i(4, 0)
const RUBBLE := Vector2i(5, 0)
const WALL_FACE := Vector2i(0, 1)
const WALL_TOP := Vector2i(1, 1)

const SLAB_CENTER := Vector2i(30, 18)  # praça de lajes claras (spawn do player)
const SLAB_RADIUS := 5.5  # tiles

const PILLARS: Array[Vector2i] = [
	Vector2i(14, 8), Vector2i(44, 8), Vector2i(14, 24), Vector2i(44, 24),
]

@onready var tiles: TileMapLayer = %Tiles


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	for y in MAP_H:
		for x in MAP_W:
			var cell := Vector2i(x, y)
			if Vector2(cell - SLAB_CENTER).length() <= SLAB_RADIUS:
				tiles.set_cell(cell, 0, SLAB)
			else:
				tiles.set_cell(cell, 0, _pick_floor(rng, x, y))

	# bordas: topo tem face visível (parede "de pé"), demais só o topo
	for x in MAP_W:
		tiles.set_cell(Vector2i(x, 0), 0, WALL_TOP)
		tiles.set_cell(Vector2i(x, 1), 0, WALL_FACE)
		tiles.set_cell(Vector2i(x, MAP_H - 1), 0, WALL_TOP)
	for y in MAP_H:
		tiles.set_cell(Vector2i(0, y), 0, WALL_TOP)
		tiles.set_cell(Vector2i(MAP_W - 1, y), 0, WALL_TOP)

	# pilares 2x2: linha de cima é o topo, linha de baixo a face
	for p in PILLARS:
		tiles.set_cell(p, 0, WALL_TOP)
		tiles.set_cell(p + Vector2i(1, 0), 0, WALL_TOP)
		tiles.set_cell(p + Vector2i(0, 1), 0, WALL_FACE)
		tiles.set_cell(p + Vector2i(1, 1), 0, WALL_FACE)


func _pick_floor(rng: RandomNumberGenerator, x: int, y: int) -> Vector2i:
	var roll := rng.randf()
	if roll < 0.05:
		return FLOOR_CRACKED
	if roll < 0.10:
		return FLOOR_SPECKLED
	if roll < 0.13:
		return RUBBLE
	@warning_ignore("integer_division")
	var checker := (x / 2 + y / 2) % 2 == 0
	return FLOOR_A if checker else FLOOR_B
