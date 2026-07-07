extends Node2D
## Mapa de teste do M0 — chão, paredes de borda, pilares e uma runa com glow.
## Protótipo desenhado por código (sem arte); será substituído por TileMap com sprites.

const TILE := 16
const MAP_W := 60  # tiles → 960 px
const MAP_H := 34  # tiles → 544 px

# Paleta da referência visual: cripta gelada teal/ciano
const FLOOR_A := Color("15393d")
const FLOOR_B := Color("184347")
const WALL := Color("081d20")
const WALL_TOP := Color("11333a")
const PILLAR := Color("0d282c")
const PILLAR_TOP := Color("2f6d6d")
const RUNE_STONE := Color("0f2e33")
const RUNE_GLOW := Color(0.5, 3.2, 2.8)  # HDR > 1.0 → estoura no glow/bloom

const PILLARS: Array[Vector2i] = [
	Vector2i(14, 8), Vector2i(44, 8), Vector2i(14, 24), Vector2i(44, 24),
]
const RUNE_POS := Vector2i(29, 5)


func _ready() -> void:
	_add_wall(Rect2(0, 0, MAP_W * TILE, TILE))
	_add_wall(Rect2(0, (MAP_H - 1) * TILE, MAP_W * TILE, TILE))
	_add_wall(Rect2(0, 0, TILE, MAP_H * TILE))
	_add_wall(Rect2((MAP_W - 1) * TILE, 0, TILE, MAP_H * TILE))
	for p in PILLARS:
		_add_wall(Rect2(p.x * TILE, p.y * TILE, TILE * 2, TILE * 2))
	_add_wall(Rect2(RUNE_POS.x * TILE, RUNE_POS.y * TILE, TILE * 2, TILE * 2))


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1  # layer "world"
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.position + rect.size / 2.0
	body.add_child(shape)
	add_child(body)


func _draw() -> void:
	# chão em xadrez de 2x2 tiles
	for y in MAP_H:
		for x in MAP_W:
			@warning_ignore("integer_division")
			var checker := (x / 2 + y / 2) % 2 == 0
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), FLOOR_A if checker else FLOOR_B)

	# bordas
	draw_rect(Rect2(0, 0, MAP_W * TILE, TILE), WALL)
	draw_rect(Rect2(0, (MAP_H - 1) * TILE, MAP_W * TILE, TILE), WALL)
	draw_rect(Rect2(0, 0, TILE, MAP_H * TILE), WALL)
	draw_rect(Rect2((MAP_W - 1) * TILE, 0, TILE, MAP_H * TILE), WALL)
	draw_rect(Rect2(0, TILE, MAP_W * TILE, 2), WALL_TOP)

	# pilares (bloco + topo claro pra dar leitura de altura)
	for p in PILLARS:
		var px := p.x * TILE
		var py := p.y * TILE
		draw_rect(Rect2(px, py - 8, TILE * 2, TILE * 2 + 8), PILLAR)
		draw_rect(Rect2(px, py - 8, TILE * 2, 6), PILLAR_TOP)

	# runa central (pedra escura + símbolo HDR que brilha com o glow)
	var rx := RUNE_POS.x * TILE
	var ry := RUNE_POS.y * TILE
	draw_rect(Rect2(rx, ry - 10, TILE * 2, TILE * 2 + 10), RUNE_STONE)
	draw_rect(Rect2(rx + 12, ry - 4, 8, 20), RUNE_GLOW)
	draw_rect(Rect2(rx + 8, ry + 4, 16, 4), RUNE_GLOW)
