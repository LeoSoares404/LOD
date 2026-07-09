class_name SwampMap
extends Node3D
## Pântano de lodo 2.5D — mesmo tamanho da cripta (60x34 m, compatível com o
## WaveManager), mas todo envenenado: chão esverdeado e poças de veneno.
## A poça só avisa o Player (entrou/saiu); o slow e o debuff de veneno
## são regra do próprio Player.

const MAP_W := 60.0   # m
const MAP_H := 34.0   # m
const WALL := 1.0
const WALL_HEIGHT := 4.0
## A parede norte é a única por cima da qual se enxerga. Com 4 m ela cobria a
## faixa de cima da tela inteira e o céu nunca aparecia; 2 m abrem a vista.
const NORTH_WALL_HEIGHT := 2.0

const FLOOR_TEX := preload("res://image/chao2.jpg")
const FLOOR_TILE_WORLD := 7.5
const GLOW_TEX := preload("res://assets/sprites/props/glow_gradient.tres")

# poça em pixel art: textura baixa + filtro NEAREST = pixelão coerente com os
# sprites do jogo. Paleta de 4 tons (16 bits), do contorno quase preto ao ácido
# do centro — quanto mais escura a borda, mais a poça parece funda e podre.
const POOL_PX := 48  # lado da textura em pixels (baixo de propósito)
const POOL_PALETTE := [
	Color8(16, 26, 13),    # contorno quase preto
	Color8(38, 74, 26),    # borda podre
	Color8(74, 132, 30),   # miolo
	Color8(126, 190, 44),  # centro ácido
]
const POOL_BUBBLE := Color8(196, 242, 104)  # bolhas de ácido
const POOL_SLUDGE := Color8(27, 46, 19)     # manchas de lodo afundado
const POOL_WEDGES := 24    # setores da borda: mais setores = borda mais rasgada
const POOL_EDGE_MIN := 0.6  # o quanto o raio pode encolher num setor (borda amebóide)

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


## Céu noturno atrás da borda de cima. A câmera é fixa (Iso.CAM_PITCH) e olha
## SEMPRE pra baixo — nenhum raio dela sobe até o horizonte. Então o "céu" não
## fica acima do mapa: fica no vazio além da parede norte, em painéis inclinados
## no mesmo pitch da câmera (o mesmo truque da HealthBar). Aparece na faixa de
## cima da tela quando o player sobe o mapa, e some quando ele desce.
## As camadas ficam a distâncias diferentes da câmera — a perspectiva já entrega
## o parallax de graça, sem código de scroll.
## Posições calculadas com o player encostado na parede norte (z≈2): a lua fica
## a ~52 m da câmera e as estrelas a ~75 m — a de trás desliza menos.
const SKY_STARS_POS := Vector3(30.0, -33.6, -37.2)
const SKY_MOON_POS := Vector3(30.0, -16.9, -21.0)
const SKY_STARS_PX := Vector2i(320, 140)
const SKY_STARS_PIXEL := 0.4375  # 320 px × 0,4375 = 140 m de largura
const SKY_MOON_PX := 32
const SKY_MOON_PIXEL := 0.28125  # 32 px × 0,28125 = 9 m de lua

const SKY_NIGHT := Color8(9, 14, 26)
const SKY_STAR_TONES := [Color8(120, 140, 180), Color8(190, 205, 230), Color8(255, 255, 255)]
const SKY_MOON_BONE := Color8(236, 240, 214)
const SKY_MOON_SHADE := Color8(198, 206, 176)
const SKY_MOON_CRATER := Color8(168, 178, 150)


func _ready() -> void:
	_add_floor()
	_add_borders()
	_add_night_sky()
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


func _add_night_sky() -> void:
	var stars := _add_sky_layer(_starfield_image(1337), SKY_STARS_POS, SKY_STARS_PIXEL, Color.WHITE)

	# halo difuso atrás da lua, com a textura de glow que o resto do jogo usa
	var halo := _add_sky_layer(null, SKY_MOON_POS, 0.086, Color(0.55, 0.65, 0.85, 0.35))
	halo.texture = GLOW_TEX
	halo.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	halo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	var moon := _add_sky_layer(_moon_image(), SKY_MOON_POS, SKY_MOON_PIXEL, Color(1.3, 1.3, 1.2))
	moon.position.z += 0.1  # à frente do halo

	# piscar lento das estrelas (a lua não pisca)
	var tw := create_tween().set_loops()
	tw.tween_property(stars, "modulate:a", 0.75, 2.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(stars, "modulate:a", 1.0, 2.4).set_trans(Tween.TRANS_SINE)


## Painel do céu: quad inclinado no pitch da câmera, então na tela ele lê como
## um fundo chapado por trás do mapa.
func _add_sky_layer(img: Image, pos: Vector3, pixel: float, tint: Color) -> Sprite3D:
	var spr := Sprite3D.new()
	if img != null:
		spr.texture = ImageTexture.create_from_image(img)
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.pixel_size = pixel
	spr.modulate = tint
	spr.rotation_degrees.x = Iso.CAM_PITCH  # encara a câmera fixa
	spr.position = pos
	add_child(spr)
	return spr


## Fundo estrelado: noite quase preta com estrelas de 3 brilhos, em pixel art.
func _starfield_image(seed_val: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var img := Image.create(SKY_STARS_PX.x, SKY_STARS_PX.y, false, Image.FORMAT_RGBA8)
	img.fill(SKY_NIGHT)
	var count := SKY_STARS_PX.x * SKY_STARS_PX.y / 90  # ~1 estrela a cada 90 px
	for i in count:
		var x := rng.randi_range(0, SKY_STARS_PX.x - 1)
		var y := rng.randi_range(0, SKY_STARS_PX.y - 1)
		# as mais brilhantes são as mais raras
		var roll := rng.randf()
		var tone: Color = SKY_STAR_TONES[0] if roll < 0.6 \
			else (SKY_STAR_TONES[1] if roll < 0.92 else SKY_STAR_TONES[2])
		img.set_pixel(x, y, tone)
	return img


## Lua cheia em pixel art: disco claro, terminador sutil de um lado e crateras.
func _moon_image() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var img := Image.create(SKY_MOON_PX, SKY_MOON_PX, false, Image.FORMAT_RGBA8)
	var c := (SKY_MOON_PX - 1) / 2.0
	var r := c - 0.5
	for y in SKY_MOON_PX:
		for x in SKY_MOON_PX:
			var d := Vector2(x - c, y - c)
			if d.length() > r:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d.x + d.y > r * 0.75:  # canto inferior-direito um pouco mais escuro
				img.set_pixel(x, y, SKY_MOON_SHADE)
			else:
				img.set_pixel(x, y, SKY_MOON_BONE)

	for i in 7:  # crateras: discos escuros dentro do limbo
		var cr := rng.randf_range(1.2, 3.0)
		var cx := rng.randf_range(cr, SKY_MOON_PX - cr)
		var cy := rng.randf_range(cr, SKY_MOON_PX - cr)
		if Vector2(cx - c, cy - c).length() > r - cr:
			continue  # cratera cairia pra fora do disco
		for y in SKY_MOON_PX:
			for x in SKY_MOON_PX:
				if Vector2(x - cx, y - cy).length() <= cr:
					img.set_pixel(x, y, SKY_MOON_CRATER)
	return img


## Poça de veneno: sprite de pixel art deitado no chão + Area3D que avisa o Player.
func _add_poison_pool(center: Vector3, radius: float) -> void:
	var spr := Sprite3D.new()
	spr.texture = ImageTexture.create_from_image(_pool_image(hash(center)))
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.rotation_degrees.x = -90.0
	spr.pixel_size = radius * 2.0 / POOL_PX  # POOL_PX pixels = diâmetro da poça
	spr.modulate = Color(1.25, 1.5, 1.15)  # brilho tóxico (glow do Environment)
	spr.position = center + Vector3(0, 0.03, 0)
	add_child(spr)

	# pulso curto e irregular — a poça "respira" como algo vivo, não decora
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.15)
	light.light_energy = 0.8
	light.omni_range = radius * 2.4
	light.position = center + Vector3(0, 0.8, 0)
	add_child(light)
	var tw := create_tween().set_loops()
	tw.tween_property(light, "light_energy", 1.6, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "light_energy", 0.8, 1.1).set_trans(Tween.TRANS_SINE)

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
		wedge.append(rng.randf_range(POOL_EDGE_MIN, 1.0))

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

	# manchas de lodo afundado (escuras) e bolhas de ácido (claras) — o contraste
	# é o que faz a poça parecer viva e nojenta em vez de um decalque liso
	_blotches(img, rng, 9, 3, POOL_SLUDGE, 0.32)
	_blotches(img, rng, 7, 2, POOL_BUBBLE, 0.26)
	return img


## Espalha `count` quadrados de lado `size` dentro da poça. Só pinta em cima de
## pixel já opaco, senão a mancha vaza pra fora da borda rasgada.
func _blotches(
	img: Image, rng: RandomNumberGenerator, count: int, size: int, color: Color, spread: float
) -> void:
	var c := (POOL_PX - 1) / 2.0
	for i in count:
		var bx := int(c + rng.randf_range(-spread, spread) * POOL_PX)
		var by := int(c + rng.randf_range(-spread, spread) * POOL_PX)
		for oy in size:
			for ox in size:
				var px := Vector2i(bx + ox, by + oy)
				if img.get_pixel(px.x, px.y).a > 0.5:
					img.set_pixel(px.x, px.y, color)


func _on_pool_body(body: Node3D, inside: bool) -> void:
	if body is Player:
		body.set_in_poison(inside)


func _add_borders() -> void:
	var half_h := WALL_HEIGHT / 2.0
	var north_h := NORTH_WALL_HEIGHT
	_add_wall(Vector3(MAP_W / 2.0, north_h / 2.0, WALL / 2.0), Vector3(MAP_W, north_h, WALL))
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
