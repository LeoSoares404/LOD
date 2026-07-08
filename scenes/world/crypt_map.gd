extends Node3D
## Cripta 2.5D — chão em mesh com a textura HD ladrilhada + emblema de runas
## deitado no centro. Boundaries por paredes de colisão invisíveis nas bordas.
## Props altos (colunas/obeliscos) como Sprite3D em pé — a profundidade real
## do 3D substitui o Y-sort.

const MAP_W := 60.0   # m (era 960 px; 16 px = 1 m)
const MAP_H := 34.0   # m (era 544 px)
const WALL := 1.0     # espessura das paredes invisíveis
const WALL_HEIGHT := 4.0
const PIXEL_SIZE := 1.0 / Iso.PPM  # 0.0625 m por pixel da arte

const FLOOR_TEX := preload("res://image/chao2.jpg")
const FLOOR_TILE_WORLD := 7.5  # tamanho de UMA cópia da textura em m (era 120 px)
const EMBLEM_TEX := preload("res://assets/sprites/props/emblem.png")
const COLUMN_TEX := preload("res://assets/sprites/props/column.png")
const OBELISK_TEX := preload("res://assets/sprites/props/obelisk.png")
const GLOW_TEX := preload("res://assets/sprites/props/glow_gradient.tres")

const EMBLEM_CENTER := Vector3(31.25, 0.02, 17.0)
const EMBLEM_DIAMETER := 10.9  # extensão-alvo do emblema em m (era 175 px)

# posições (m) do PONTO DA BASE de cada prop
const COLUMNS: Array[Vector3] = [
	Vector3(9.4, 0, 10.6), Vector3(50.6, 0, 10.6),
	Vector3(9.4, 0, 29.4), Vector3(50.6, 0, 29.4),
]
const OBELISKS: Array[Vector3] = [
	Vector3(20.6, 0, 6.9), Vector3(39.4, 0, 6.9),
]


func _ready() -> void:
	_add_floor()
	_add_emblem()
	_add_borders()
	_spawn_props()


func _add_floor() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_W, MAP_H)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = FLOOR_TEX
	mat.albedo_color = Color(0.52, 0.66, 0.68)  # tom teal da cripta (ex-CanvasModulate)
	mat.uv1_scale = Vector3(MAP_W / FLOOR_TILE_WORLD, MAP_H / FLOOR_TILE_WORLD, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # reduz shimmer
	plane.material = mat
	mi.mesh = plane
	mi.position = Vector3(MAP_W / 2.0, 0.0, MAP_H / 2.0)
	add_child(mi)


func _add_emblem() -> void:
	var emblem := Sprite3D.new()
	emblem.texture = EMBLEM_TEX
	emblem.pixel_size = PIXEL_SIZE
	emblem.rotation_degrees.x = -90.0  # deitado no chão
	var s := EMBLEM_DIAMETER / (EMBLEM_TEX.get_height() * PIXEL_SIZE)
	emblem.scale = Vector3(s, s, s)
	emblem.position = EMBLEM_CENTER
	add_child(emblem)

	# glow ciano suave e pulsante sobre o emblema
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.9)
	light.light_energy = 0.5
	light.omni_range = 9.0
	light.position = EMBLEM_CENTER + Vector3(0, 1.5, 0)
	add_child(light)
	var tw := create_tween().set_loops()
	tw.tween_property(light, "light_energy", 0.9, 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "light_energy", 0.5, 2.0).set_trans(Tween.TRANS_SINE)


func _add_borders() -> void:
	var half_h := WALL_HEIGHT / 2.0
	_add_wall(Vector3(MAP_W / 2.0, half_h, WALL / 2.0), Vector3(MAP_W, WALL_HEIGHT, WALL))
	_add_wall(Vector3(MAP_W / 2.0, half_h, MAP_H - WALL / 2.0), Vector3(MAP_W, WALL_HEIGHT, WALL))
	_add_wall(Vector3(WALL / 2.0, half_h, MAP_H / 2.0), Vector3(WALL, WALL_HEIGHT, MAP_H))
	_add_wall(Vector3(MAP_W - WALL / 2.0, half_h, MAP_H / 2.0), Vector3(WALL, WALL_HEIGHT, MAP_H))


func _add_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1  # layer "world"
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = center
	body.add_child(shape)

	# volume visível — antes era só colisão invisível, o que deixava o mapa
	# sem profundidade (paredes existiam pro player, não pros olhos)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.22, 0.24)
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)

	add_child(body)


func _spawn_props() -> void:
	for pos in COLUMNS:
		_add_prop(COLUMN_TEX, pos)
	for pos in OBELISKS:
		_add_prop(OBELISK_TEX, pos, true)


## Prop alto: sprite em pé com a BASE no ponto dado + colisão pequena na base,
## pra dar pra andar por trás (a profundidade 3D resolve a oclusão).
func _add_prop(tex: Texture2D, pos: Vector3, glow := false) -> void:
	var h := tex.get_height() * PIXEL_SIZE
	var spr := Sprite3D.new()
	spr.texture = tex
	spr.pixel_size = PIXEL_SIZE
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.position = pos + Vector3(0, h / 2.0, 0)
	add_child(spr)

	var shadow := Sprite3D.new()
	shadow.texture = GLOW_TEX
	shadow.pixel_size = PIXEL_SIZE
	shadow.modulate = Color(0, 0, 0, 0.45)
	shadow.rotation_degrees.x = -90.0
	shadow.scale = Vector3(0.11, 0.055, 1.0)
	shadow.position = pos + Vector3(0, 0.02, 0)
	add_child(shadow)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	shape.shape = sphere
	body.position = pos + Vector3(0, 0.3, 0)
	body.add_child(shape)
	add_child(body)

	if glow:
		var light := OmniLight3D.new()
		light.light_color = Color(0.55, 1.0, 0.92)
		light.light_energy = 0.7
		light.omni_range = 5.0
		light.position = pos + Vector3(0, 1.3, 0)
		add_child(light)
