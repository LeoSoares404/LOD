extends Node2D
## Cripta — pinta o TileMapLayer proceduralmente com o tileset placeholder.
## Visão 3/4: profundidade vem de penhasco alto com borda irregular, sombra na
## base e props ALTOS (colunas/obeliscos) com Y-sort — o player passa atrás.
## Colisão de paredes/penhascos vem do TileSet; props têm corpo próprio na base.

const TILE := 16
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
const CLIFF_UPPER := Vector2i(2, 1)
const CLIFF_LOWER := Vector2i(3, 1)
const PLATEAU_RIM := Vector2i(4, 1)
const STAIRS := Vector2i(5, 1)
const SHADOW_FLOOR := Vector2i(6, 1)
const PLATEAU_FLOOR := Vector2i(7, 1)
const SLAB_MIX := Vector2i(0, 2)  # dithering laje↔chão (borda suave da praça)

# geografia do desnível
const RIM_BASE_Y := 9            # linha média da borda do platô
const CLIFF_HEIGHT := 3          # tiles de face de penhasco
const STAIRS_X_RANGE := [28, 31] # colunas da escadaria (inclusive)

const SLAB_CENTER := Vector2i(30, 22)  # praça de lajes claras (spawn do player)
const SLAB_RADIUS := 5.0  # tiles

const COLUMN_TEX := preload("res://assets/sprites/props/column.png")
const OBELISK_TEX := preload("res://assets/sprites/props/obelisk.png")

# posições em px do PONTO DA BASE de cada prop (Y-sort ordena por ele)
const COLUMNS: Array[Vector2] = [
	Vector2(424, 260), Vector2(536, 260),  # flanqueando o pé da escada
	Vector2(208, 330), Vector2(752, 330),
	Vector2(180, 480), Vector2(780, 480),
]
const OBELISKS: Array[Vector2] = [
	Vector2(432, 120), Vector2(528, 120),  # flanqueando a runa, no platô
	Vector2(144, 110), Vector2(816, 110),
]

@onready var tiles: TileMapLayer = %Tiles

var _rim: Array[int] = []


func _ready() -> void:
	_build_rim_line()
	_paint_tiles()
	_spawn_props()


## Borda do penhasco irregular (noise 1D suavizado), reta só na escadaria.
func _build_rim_line() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.09
	_rim.resize(MAP_W)
	for x in MAP_W:
		# amplitude curta (±2): sem tile de "quina" p/ face lateral, recorte fundo parece glitch
		_rim[x] = clampi(RIM_BASE_Y + roundi(noise.get_noise_1d(float(x)) * 2.5), 8, 11)
	for x in range(STAIRS_X_RANGE[0] - 1, STAIRS_X_RANGE[1] + 2):
		_rim[x] = RIM_BASE_Y
	for x in range(1, MAP_W):  # limita degrau entre colunas vizinhas a 1 tile
		_rim[x] = clampi(_rim[x], _rim[x - 1] - 1, _rim[x - 1] + 1)


func _paint_tiles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var patches := FastNoiseLite.new()  # manchas orgânicas no chão
	patches.seed = 21
	patches.frequency = 0.13

	for y in MAP_H:
		for x in MAP_W:
			tiles.set_cell(Vector2i(x, y), 0, _pick_cell(rng, patches, x, y))

	# bordas do mapa
	for x in MAP_W:
		tiles.set_cell(Vector2i(x, 0), 0, WALL_TOP)
		tiles.set_cell(Vector2i(x, 1), 0, WALL_FACE)
		tiles.set_cell(Vector2i(x, MAP_H - 1), 0, WALL_TOP)
	for y in MAP_H:
		tiles.set_cell(Vector2i(0, y), 0, WALL_TOP)
		tiles.set_cell(Vector2i(MAP_W - 1, y), 0, WALL_TOP)


func _pick_cell(rng: RandomNumberGenerator, patches: FastNoiseLite, x: int, y: int) -> Vector2i:
	var rim: int = _rim[x]
	var on_stairs: bool = x >= STAIRS_X_RANGE[0] and x <= STAIRS_X_RANGE[1]

	# faixa do desnível: borda, faces do penhasco, sombra na base
	if y == rim:
		return STAIRS if on_stairs else PLATEAU_RIM
	if y > rim and y <= rim + CLIFF_HEIGHT:
		if on_stairs:
			return STAIRS
		return CLIFF_LOWER if y == rim + CLIFF_HEIGHT else CLIFF_UPPER
	if y == rim + CLIFF_HEIGHT + 1:
		return STAIRS if on_stairs else SHADOW_FLOOR

	# nível de cima (platô)
	if y < rim:
		if rng.randf() < 0.05:
			return FLOOR_CRACKED
		return PLATEAU_FLOOR

	# nível de baixo: praça de lajes + manchas orgânicas de desgaste
	var cell := Vector2i(x, y)
	var slab_dist := Vector2(cell - SLAB_CENTER).length()
	if slab_dist <= SLAB_RADIUS:
		return SLAB if slab_dist <= SLAB_RADIUS - 1.2 else SLAB_MIX
	var roll := rng.randf()
	if roll < 0.04:
		return FLOOR_CRACKED
	if roll < 0.07:
		return RUBBLE
	var n := patches.get_noise_2d(float(x), float(y))
	if n > 0.22:
		return FLOOR_B
	if n < -0.3:
		return FLOOR_SPECKLED
	return FLOOR_A


func _spawn_props() -> void:
	for pos in COLUMNS:
		_add_prop(COLUMN_TEX, pos)
	for pos in OBELISKS:
		_add_prop(OBELISK_TEX, pos, true)


## Prop alto: sprite com a BASE no ponto dado (pivô nos pés → Y-sort correto)
## + colisão pequena só na base, pra dar pra andar por trás.
func _add_prop(tex: Texture2D, pos: Vector2, glow := false) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.offset = Vector2(-tex.get_width() / 2.0, -float(tex.get_height()))
	spr.position = pos

	# sombra elíptica na base — vende o "objeto de pé no chão"
	var shadow := Sprite2D.new()
	shadow.texture = preload("res://assets/sprites/props/glow_gradient.tres")
	shadow.modulate = Color(0, 0, 0, 0.45)
	shadow.scale = Vector2(0.11, 0.05)
	shadow.position = Vector2(0, -2)
	shadow.show_behind_parent = true
	spr.add_child(shadow)

	var body := StaticBody2D.new()
	body.collision_layer = 1  # layer "world"
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	shape.position = Vector2(0, -4)
	body.add_child(shape)
	spr.add_child(body)

	if glow:
		var light := PointLight2D.new()
		light.texture = preload("res://assets/sprites/props/glow_gradient.tres")
		light.color = Color(0.55, 1.0, 0.92)
		light.energy = 0.7
		light.texture_scale = 0.6
		light.position = Vector2(0, -20)
		spr.add_child(light)

	add_child(spr)
