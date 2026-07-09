extends Node3D
## Pântano de lodo 2.5D — mesmo tamanho da cripta (60x34 m, compatível com o
## WaveManager), mas todo envenenado: chão esverdeado e poças de veneno.
## A poça só avisa o Player (entrou/saiu); o slow e o debuff de veneno
## são regra do próprio Player.

const MAP_W := 60.0   # m
const MAP_H := 34.0   # m
const WALL := 1.0
const WALL_HEIGHT := 4.0

const FLOOR_TEX := preload("res://image/chao2.jpg")
const FLOOR_TILE_WORLD := 7.5
const GLOW_TEX := preload("res://assets/sprites/props/glow_gradient.tres")

# poça em pixel art: textura baixa + filtro NEAREST = pixelão coerente com os
# sprites do jogo. Paleta de 4 tons (16 bits), do contorno escuro ao centro.
const POOL_PX := 48  # lado da textura em pixels (baixo de propósito)
const POOL_PALETTE := [
	Color8(31, 61, 23),    # contorno
	Color8(58, 112, 32),   # borda
	Color8(106, 168, 42),  # miolo
	Color8(158, 214, 61),  # centro
]
const POOL_BUBBLE := Color8(203, 245, 122)
const POOL_WEDGES := 16  # setores da borda irregular

# [centro (m), raio (m)] de cada poça — longe do spawn do player (30.5, 19)
const POOLS := [
	[Vector3(12.0, 0, 8.0), 3.2],
	[Vector3(47.0, 0, 9.0), 2.6],
	[Vector3(9.0, 0, 26.0), 2.8],
	[Vector3(50.0, 0, 27.0), 3.4],
	[Vector3(30.0, 0, 7.0), 2.2],
	[Vector3(22.0, 0, 28.0), 2.5],
	[Vector3(39.0, 0, 20.0), 2.0],
]


func _ready() -> void:
	_add_floor()
	_add_borders()
	for pool in POOLS:
		_add_poison_pool(pool[0], pool[1])


func _add_floor() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_W, MAP_H)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = FLOOR_TEX
	mat.albedo_color = Color(0.42, 0.58, 0.3)  # tom doentio de pântano
	mat.uv1_scale = Vector3(MAP_W / FLOOR_TILE_WORLD, MAP_H / FLOOR_TILE_WORLD, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	plane.material = mat
	mi.mesh = plane
	mi.position = Vector3(MAP_W / 2.0, 0.0, MAP_H / 2.0)
	add_child(mi)


## Poça de veneno: sprite de pixel art deitado no chão + Area3D que avisa o Player.
func _add_poison_pool(center: Vector3, radius: float) -> void:
	var spr := Sprite3D.new()
	spr.texture = ImageTexture.create_from_image(_pool_image(hash(center)))
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.rotation_degrees.x = -90.0
	spr.pixel_size = radius * 2.0 / POOL_PX  # POOL_PX pixels = diâmetro da poça
	spr.modulate = Color(1.2, 1.35, 1.2)  # leve brilho tóxico (glow do Environment)
	spr.position = center + Vector3(0, 0.03, 0)
	add_child(spr)

	# brilho verde pulsante — "borbulhando"
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 1.0, 0.25)
	light.light_energy = 0.6
	light.omni_range = radius * 2.0
	light.position = center + Vector3(0, 1.0, 0)
	add_child(light)
	var tw := create_tween().set_loops()
	tw.tween_property(light, "light_energy", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "light_energy", 0.6, 1.2).set_trans(Tween.TRANS_SINE)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # layer 2 = corpo do player
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 2.0
	shape.shape = cyl
	area.position = center + Vector3(0, 1.0, 0)
	area.add_child(shape)
	area.body_entered.connect(_on_pool_body.bind(true))
	area.body_exited.connect(_on_pool_body.bind(false))
	add_child(area)


## Desenha a poça pixel a pixel: borda irregular (raio sorteado por setor) e
## bandas de cor concêntricas, mais algumas bolhas. `seed_val` = poça sempre
## igual entre execuções.
func _pool_image(seed_val: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var wedge := PackedFloat32Array()
	for i in POOL_WEDGES:
		wedge.append(rng.randf_range(0.78, 1.0))

	var img := Image.create(POOL_PX, POOL_PX, false, Image.FORMAT_RGBA8)
	var c := (POOL_PX - 1) / 2.0
	for y in POOL_PX:
		for x in POOL_PX:
			var d := Vector2(x - c, y - c)
			# raio da borda neste ângulo, interpolado entre dois setores
			var a := fposmod(d.angle(), TAU) / TAU * POOL_WEDGES
			var i0 := int(a)
			var edge: float = lerpf(wedge[i0], wedge[(i0 + 1) % POOL_WEDGES], a - i0) * c
			var dist := d.length()
			if dist > edge:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif dist > edge - 2.0:
				img.set_pixel(x, y, POOL_PALETTE[0])
			elif dist > edge * 0.6:
				img.set_pixel(x, y, POOL_PALETTE[1])
			elif dist > edge * 0.3:
				img.set_pixel(x, y, POOL_PALETTE[2])
			else:
				img.set_pixel(x, y, POOL_PALETTE[3])

	# bolhas: quadradinhos 2x2 bem no meio, longe da borda irregular
	for i in 6:
		var bx := int(c + rng.randf_range(-0.25, 0.25) * POOL_PX)
		var by := int(c + rng.randf_range(-0.25, 0.25) * POOL_PX)
		for oy in 2:
			for ox in 2:
				img.set_pixel(bx + ox, by + oy, POOL_BUBBLE)

	return img


func _on_pool_body(body: Node3D, inside: bool) -> void:
	if body is Player:
		body.set_in_poison(inside)


func _add_borders() -> void:
	var half_h := WALL_HEIGHT / 2.0
	_add_wall(Vector3(MAP_W / 2.0, half_h, WALL / 2.0), Vector3(MAP_W, WALL_HEIGHT, WALL))
	_add_wall(Vector3(MAP_W / 2.0, half_h, MAP_H - WALL / 2.0), Vector3(MAP_W, WALL_HEIGHT, WALL))
	_add_wall(Vector3(WALL / 2.0, half_h, MAP_H / 2.0), Vector3(WALL, WALL_HEIGHT, MAP_H))
	_add_wall(Vector3(MAP_W - WALL / 2.0, half_h, MAP_H / 2.0), Vector3(WALL, WALL_HEIGHT, MAP_H))


func _add_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = center
	body.add_child(shape)

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.2, 0.1)  # muro musgo escuro
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)

	add_child(body)
