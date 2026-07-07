extends Node2D
## Cripta — chão em arte HD (imagem) + emblema de runas no centro.
## Boundaries por paredes de colisão invisíveis nas bordas.
## Props altos (colunas/obeliscos) com Y-sort — o player passa atrás.

const MAP_W := 960
const MAP_H := 544
const WALL := 16  # espessura das paredes de colisão invisíveis

const FLOOR_TEX := preload("res://image/chao2.jpg")
const FLOOR_TILE_WORLD := 120.0  # tamanho de UMA cópia da textura em px de mundo
const EMBLEM_TEX := preload("res://assets/sprites/props/emblem.png")  # fundo já recortado
const COLUMN_TEX := preload("res://assets/sprites/props/column.png")
const OBELISK_TEX := preload("res://assets/sprites/props/obelisk.png")
const GLOW_TEX := preload("res://assets/sprites/props/glow_gradient.tres")

const EMBLEM_CENTER := Vector2(500, 272)
const EMBLEM_DIAMETER := 175.0  # altura-alvo do emblema em px de mundo

# posições em px do PONTO DA BASE de cada prop (Y-sort ordena por ela)
const COLUMNS: Array[Vector2] = [
	Vector2(150, 170), Vector2(810, 170),
	Vector2(150, 470), Vector2(810, 470),
]
const OBELISKS: Array[Vector2] = [
	Vector2(330, 110), Vector2(630, 110),
]


func _ready() -> void:
	_add_floor()
	_add_emblem()
	_add_borders()
	_spawn_props()


func _add_floor() -> void:
	# textura ladrilhada: repete pelo mapa (region maior que a textura + repeat)
	var floor_spr := Sprite2D.new()
	floor_spr.texture = FLOOR_TEX
	floor_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # reduz shimmer ao mover
	floor_spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_spr.centered = false
	floor_spr.region_enabled = true
	var k := FLOOR_TILE_WORLD / FLOOR_TEX.get_width()
	floor_spr.scale = Vector2(k, k)
	floor_spr.region_rect = Rect2(0, 0, MAP_W / k, MAP_H / k)
	floor_spr.position = Vector2.ZERO
	floor_spr.z_index = -20
	add_child(floor_spr)


func _add_emblem() -> void:
	var emblem := Sprite2D.new()
	emblem.texture = EMBLEM_TEX
	emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	emblem.position = EMBLEM_CENTER
	var s := EMBLEM_DIAMETER / EMBLEM_TEX.get_height()
	emblem.scale = Vector2(s, s)
	emblem.z_index = -19  # acima do chão, abaixo dos personagens
	add_child(emblem)

	# glow ciano suave e pulsante sob o emblema
	var light := PointLight2D.new()
	light.texture = GLOW_TEX
	light.color = Color(0.4, 1.0, 0.9)
	light.energy = 0.5
	light.texture_scale = 1.1
	light.position = EMBLEM_CENTER
	add_child(light)
	var tw := create_tween().set_loops()
	tw.tween_property(light, "energy", 0.9, 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "energy", 0.5, 2.0).set_trans(Tween.TRANS_SINE)


func _add_borders() -> void:
	_add_wall(Rect2(0, 0, MAP_W, WALL))
	_add_wall(Rect2(0, MAP_H - WALL, MAP_W, WALL))
	_add_wall(Rect2(0, 0, WALL, MAP_H))
	_add_wall(Rect2(MAP_W - WALL, 0, WALL, MAP_H))


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1  # layer "world"
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.position = rect.position + rect.size / 2.0
	body.add_child(shape)
	add_child(body)


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

	var shadow := Sprite2D.new()
	shadow.texture = GLOW_TEX
	shadow.modulate = Color(0, 0, 0, 0.45)
	shadow.scale = Vector2(0.11, 0.05)
	shadow.position = Vector2(0, -2)
	shadow.show_behind_parent = true
	spr.add_child(shadow)

	var body := StaticBody2D.new()
	body.collision_layer = 1
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
		light.texture = GLOW_TEX
		light.color = Color(0.55, 1.0, 0.92)
		light.energy = 0.7
		light.texture_scale = 0.6
		light.position = Vector2(0, -20)
		spr.add_child(light)

	add_child(spr)
