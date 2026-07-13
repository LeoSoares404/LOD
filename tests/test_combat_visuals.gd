extends Node
## Check dos visuais de combate. Roda como cena (precisa dos autoloads e da
## árvore montada para o _ready dos projéteis e o global_transform):
##   godot --headless --path . res://tests/test_combat_visuals.tscn
## Sai com código 1 se algo quebrar.

const BOLT := preload("res://scenes/entities/projectiles/magic_bolt.tscn")
const SWAMP := preload("res://scenes/world/swamp_map.tscn")
const PLAYER := preload("res://scenes/entities/player/player.tscn")

var _failures := 0


func _ready() -> void:
	_test_arrow_aims_at_direction()
	_test_orb_stays_billboard()
	_test_orb_explodes_at_half_screen()
	_test_orb_always_explodes()
	_test_melee_hits_only_the_mouse_arc()
	_test_scythe_sweeps_the_damage_cone()
	_test_attack_cooldowns()
	_test_orb_charge_stages()
	_test_wave_upgrades()
	_test_xp_levels_up()
	_test_poison_damage_is_percent_of_max_health()
	_test_poison_icon_follows_debuff()
	_test_player_damage_always_pops_a_number()
	_test_pool_image_is_pixel_blob()
	_test_night_sky_sits_behind_the_map()

	if _failures > 0:
		printerr("FALHOU: %d check(s) de visuais de combate" % _failures)
		get_tree().quit(1)
	else:
		print("OK: visuais de combate")
		get_tree().quit(0)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_failures += 1
		printerr("  x %s" % msg)


## A flecha do arqueiro fica deitada no chão e com o eixo comprido (o +Y local
## do sprite) apontando exatamente na direção do voo.
func _test_arrow_aims_at_direction() -> void:
	for dir in [Vector3.RIGHT, Vector3.FORWARD, Vector3(0.6, 0, -0.8), Vector3(-0.5, 0, 0.5)]:
		var bolt: MagicBolt = BOLT.instantiate()
		bolt.direction = dir.normalized()
		bolt.is_arrow = true
		add_child(bolt)

		var spr: Sprite3D = bolt.get_node("Sprite")
		var long_axis := spr.global_transform.basis.y.normalized()
		_check(long_axis.distance_to(dir.normalized()) < 0.01,
			"flecha aponta pra %v, esperado %v" % [long_axis, dir.normalized()])
		_check(absf(spr.global_transform.basis.z.y) > 0.99, "flecha não está deitada no chão")
		_check(bolt._speed > MagicBolt.SPEED, "flecha deveria voar mais rápido que o orbe")
		bolt.queue_free()


## O orbe do mago não passa pelo _become_arrow: continua billboard e na SPEED base.
func _test_orb_stays_billboard() -> void:
	var bolt: MagicBolt = BOLT.instantiate()
	add_child(bolt)
	var spr: Sprite3D = bolt.get_node("Sprite")
	_check(spr.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "orbe perdeu o billboard")
	_check(bolt._speed == MagicBolt.SPEED, "orbe não deveria ganhar a velocidade da flecha")
	bolt.queue_free()


## O orbe do mago voa meia tela e estoura: o estouro é o golpe cheio, e quem
## toma o orbe direto na cara antes disso leva metade. Flecha não estoura.
func _test_orb_explodes_at_half_screen() -> void:
	var orb: MagicBolt = BOLT.instantiate()
	add_child(orb)
	_check(orb.damage == 3, "acerto direto deveria ser metade do estouro (6/2), veio %d" % orb.damage)
	_check(orb.damage * 2 == MagicBolt.EXPLOSION_DAMAGE, "acerto direto tem que ser 50%% do estouro")
	_check(orb.damage < MagicBolt.EXPLOSION_DAMAGE, "acerto direto não pode doer mais que o estouro")
	_check(orb._range == MagicBolt.ORB_RANGE, "orbe deveria estourar no alcance de meia tela")
	# meia tela ~9,9 m: perto o bastante de metade da largura visível (~19,7 m)
	_check(absf(MagicBolt.ORB_RANGE - 9.86) < 0.5, "ORB_RANGE saiu de meia tela")
	_check(not orb.is_arrow, "orbe do mago não deveria nascer flecha")
	orb.queue_free()

	var arrow: MagicBolt = BOLT.instantiate()
	arrow.is_arrow = true
	add_child(arrow)
	_check(arrow._range == MagicBolt.ARROW_RANGE, "flecha tem alcance próprio, não o do orbe")
	_check(arrow._range > MagicBolt.ORB_RANGE, "a flecha deveria alcançar mais que o orbe")
	arrow.queue_free()


## O orbe estoura ao encostar em qualquer coisa — o estouro é o único dano do AA.
func _test_orb_always_explodes() -> void:
	var orb: MagicBolt = BOLT.instantiate()
	add_child(orb)
	_check(orb.will_explode(), "orbe do mago deveria sempre estourar")
	_check(orb.damage == 0, "contato do orbe não fere; o dano é só do estouro")
	orb.queue_free()

	var arrow: MagicBolt = BOLT.instantiate()
	arrow.is_arrow = true
	add_child(arrow)
	_check(not arrow.will_explode(), "flecha do arqueiro nunca estoura")
	arrow.queue_free()


## O golpe do lutador só pega o cone na direção do mouse: à frente sim, nas
## costas e nos lados de fora do arco, não.
func _test_melee_hits_only_the_mouse_arc() -> void:
	var player: Player = PLAYER.instantiate()
	add_child(player)

	var origin := Vector3.ZERO
	var facing := Vector3.FORWARD  # -Z
	var arc: float = Player.MELEE_ARC_DEG  # 110° => 55° pra cada lado

	_check(player._in_arc(origin, Vector3(0, 0, -2), facing, arc), "inimigo à frente deveria ser atingido")
	_check(not player._in_arc(origin, Vector3(0, 0, 2), facing, arc), "inimigo atrás NÃO pode ser atingido")
	_check(not player._in_arc(origin, Vector3(2, 0, 0), facing, arc), "inimigo a 90° está fora do arco")
	# 50° pra frente-direita: dentro. 60°: fora.
	_check(player._in_arc(origin, Vector3(sin(deg_to_rad(50)), 0, -cos(deg_to_rad(50))), facing, arc),
		"inimigo a 50° deveria estar dentro do arco de 110°")
	_check(not player._in_arc(origin, Vector3(sin(deg_to_rad(60)), 0, -cos(deg_to_rad(60))), facing, arc),
		"inimigo a 60° deveria estar fora do arco de 110°")
	# sem arco (superataque) continua acertando os 360°
	_check(player._in_arc(origin, Vector3(0, 0, 2), facing, 0.0), "arc_deg=0 deveria acertar tudo")

	player.queue_free()


## A foice varre EXATAMENTE o cone do dano: girada nos dois extremos, nenhum
## vértice sai do raio nem do arco, e a lâmina encosta nas duas bordas do cone.
## Se ela mentir, o lutador bate onde o jogador não vê.
func _test_scythe_sweeps_the_damage_cone() -> void:
	var player: Player = PLAYER.instantiate()
	add_child(player)

	# vale na onda 1 (cone base) e na onda 4 (cone 60% maior) — se o bônus de
	# arco crescer sem a varredura acompanhar, o efeito passa a mentir
	for wave in [1, 4]:
		GameState.current_wave = wave
		_check_scythe(player, player._melee_arc_deg(), wave)
	GameState.current_wave = 0
	player.queue_free()


func _check_scythe(player: Player, arc: float, wave: int) -> void:
	var radius := 2.5
	var facing := Vector3.FORWARD  # a lâmina nasce centrada no -Z
	var mesh: ArrayMesh = player._scythe_mesh(radius)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(verts.size() > 0, "malha da foice saiu vazia")

	# a lâmina é um crescente: abre menos que o cone e tem buraco no meio
	_check(Player.SCYTHE_SPAN_DEG < arc, "onda %d: a lâmina não pode abrir o cone inteiro" % wave)
	var closest := radius
	for v in verts:
		_check(absf(v.y) < 0.001, "vértice fora do plano do chão: %v" % v)
		closest = minf(closest, v.length())
	_check(closest > 0.1, "a foice deveria ser um crescente, não uma fatia de pizza")

	# gira a lâmina até os dois extremos da varredura e confere o cone.
	# EPS: os vértices das pontas caem EM CIMA da borda do cone, e aí o
	# arredondamento decide se estão dentro ou fora — 0,01° de folga resolve.
	const EPS := 0.01
	var sweep := deg_to_rad(player._sweep_half_deg(arc))
	var reach_angle := 0.0
	for turn in [-sweep, sweep]:
		var basis := Basis(Vector3.UP, turn)
		for v in verts:
			var p: Vector3 = basis * v
			_check(p.length() <= radius + 0.001, "foice passa do raio do dano: %v" % p)
			if p == Vector3.ZERO:
				continue
			var ang := rad_to_deg(Iso.flat_direction(Vector3.ZERO, p).angle_to(facing))
			_check(ang <= arc / 2.0 + EPS,
				"onda %d: foice sai do arco: %.2f° > %.2f°" % [wave, ang, arc / 2.0])
			reach_angle = maxf(reach_angle, deg_to_rad(ang))

	# e a varredura chega até a borda do cone (não deixa canto sem cobrir)
	_check(is_equal_approx(rad_to_deg(reach_angle), arc / 2.0),
		"onda %d: a foice varre %.1f°, cone tem %.1f°" % [wave, rad_to_deg(reach_angle), arc / 2.0])

	# o vértice mais distante encosta no raio do dano
	var reach := 0.0
	for v in verts:
		reach = maxf(reach, v.length())
	_check(is_equal_approx(reach, radius), "a foice não alcança o raio inteiro do dano")


## Cada nível melhora o auto-attack: lutador +2 de dano e +20% de cone, arqueiro
## +1 flecha, mago estouro maior. Nível 1 é a base (bônus 0).
func _test_wave_upgrades() -> void:
	var player: Player = PLAYER.instantiate()
	add_child(player)

	GameState.level = 1
	_check(player._melee_damage() == Player.MELEE_DAMAGE, "nível 1 deveria ser o dano base")
	_check(is_equal_approx(player._melee_arc_deg(), Player.MELEE_ARC_DEG), "nível 1 = cone base")
	_check(player._arrow_count() == 1, "nível 1 = uma flecha só")
	_check(is_equal_approx(player._explosion_scale(), 1.0), "nível 1 = estouro base")

	GameState.level = 2
	_check(player._melee_damage() == Player.MELEE_DAMAGE + 2, "nível 2 deveria dar +2 de dano")
	_check(is_equal_approx(player._melee_arc_deg(), Player.MELEE_ARC_DEG * 1.2), "nível 2 = +20% de cone")
	_check(player._arrow_count() == 2, "nível 2 = duas flechas lado a lado")
	_check(player._explosion_scale() > 1.0, "nível 2 = estouro maior")

	GameState.level = 4
	_check(player._melee_damage() == Player.MELEE_DAMAGE + 6, "nível 4 = +6 de dano (3 níveis)")
	_check(player._arrow_count() == 4, "nível 4 = quatro flechas")
	_check(player._melee_arc_deg() <= 360.0, "o cone não pode passar de 360°")

	GameState.level = 1
	player.queue_free()


## XP acumula e sobe de nível quantas vezes couber num único ganho grande.
func _test_xp_levels_up() -> void:
	GameState.level = 1
	GameState.xp = 0
	GameState.add_xp(1)  # threshold do nível 1 é 6
	_check(GameState.level == 1, "1 de XP não sobe de nível")
	GameState.add_xp(GameState.xp_to_next() - GameState.xp)  # completa o nível
	_check(GameState.level == 2, "completar o threshold sobe pro nível 2")
	GameState.add_xp(100)  # ganho enorme sobe vários níveis de uma vez
	_check(GameState.level > 3, "um ganho grande de XP deve subir vários níveis")
	GameState.level = 1
	GameState.xp = 0


## Arqueiro 2x mais rápido que o mago; lutador 2x mais lento.
func _test_attack_cooldowns() -> void:
	var cd: Dictionary = Player.ATTACK_COOLDOWN
	_check(is_equal_approx(cd["arqueiro"], cd["mago"] / 2.0), "arqueiro deveria atacar 2x mais rápido")
	_check(is_equal_approx(cd["lutador"], cd["mago"] * 2.0), "lutador deveria atacar 2x mais lento")


## Orbe carregável: 3 estágios discretos de 1.5s. Estágio N = N× (máx 3×);
## carga parcial não sobe de estágio e passar de 4.5s trava no 3º.
func _test_orb_charge_stages() -> void:
	var player: Player = PLAYER.instantiate()
	add_child(player)
	_check(player._orb_charge_stage(0.0) == 1, "toque (0s) = estágio 1 (dano base)")
	_check(player._orb_charge_stage(1.49) == 1, "carga parcial não sobe de estágio")
	_check(player._orb_charge_stage(1.5) == 2, "1.5s = estágio 2")
	_check(player._orb_charge_stage(3.0) == 3, "3.0s = estágio 3 (3×, o máximo)")
	_check(player._orb_charge_stage(9.0) == 3, "passar de 4.5s trava no estágio 3")
	player.queue_free()


## Veneno tira 2% da vida máxima por tick, com piso de 1 (o dano é int).
func _test_poison_damage_is_percent_of_max_health() -> void:
	var player: Player = PLAYER.instantiate()
	add_child(player)

	player.health.max_health = 500
	_check(player._poison_damage() == 10, "500 de vida => 10 de dano por tick (2%%)")
	player.health.max_health = 20  # vida real do player: 2% = 0,4, arredonda pra 0
	_check(player._poison_damage() == 1, "veneno nunca pode tickar 0 de dano")

	_check(is_equal_approx(Player.POISON_LINGER, 3.0), "debuff deveria durar 3 s após sair da poça")
	player.queue_free()


## Ícone de veneno na cabeça: aparece na poça, não expira enquanto estiver
## dentro, e só some 3 s depois de sair.
func _test_poison_icon_follows_debuff() -> void:
	var player: Player = PLAYER.instantiate()
	add_child(player)
	_check(not player._poison_icon.visible, "ícone não deveria começar visível")

	player.set_in_poison(true)
	player._update_poison(0.016)
	_check(player._poison_icon.visible, "dentro da poça o ícone deveria aparecer")

	player._update_poison(10.0)  # dentro, o debuff renova: nenhum tempo o mata
	_check(player._poison_icon.visible, "dentro da poça o debuff não pode expirar")

	player.set_in_poison(false)
	player._update_poison(Player.POISON_LINGER - 0.1)
	_check(player._poison_icon.visible, "o debuff deveria durar os 3 s depois de sair")
	player._update_poison(0.2)
	_check(not player._poison_icon.visible, "passados os 3 s fora da poça o debuff acaba")

	# duas poças sobrepostas: sair de uma não limpa a outra
	player.set_in_poison(true)
	player.set_in_poison(true)
	player._update_poison(0.016)
	player.set_in_poison(false)
	player._update_poison(10.0)
	_check(player._poison_icon.visible, "ainda dentro da 2ª poça, o debuff tem que seguir")
	player.queue_free()


## Todo dano no player vira popup — venha da hurtbox ou do veneno. Cura, não.
func _test_player_damage_always_pops_a_number() -> void:
	var player: Player = PLAYER.instantiate()
	add_child(player)

	var before := _count_damage_numbers()
	player.health.take_damage(2)
	_check(_count_damage_numbers() == before + 1, "dano deveria abrir popup")

	before = _count_damage_numbers()
	player.set_in_poison(true)
	player._update_poison(0.016)  # veneno não passa pela hurtbox
	_check(_count_damage_numbers() == before + 1, "tick de veneno também deveria abrir popup")

	before = _count_damage_numbers()
	player.health.heal(1)
	_check(_count_damage_numbers() == before, "cura não pode abrir popup de dano")
	player.queue_free()


func _count_damage_numbers() -> int:
	var n := 0
	for child in get_tree().current_scene.get_children():
		if child is Label3D:
			n += 1
	return n


## A poça: opaca no miolo, vazada nos cantos (blob, não quadrado), só com as
## cores da paleta de 16 bits, e diferente a cada seed.
func _test_pool_image_is_pixel_blob() -> void:
	var swamp: Node3D = SWAMP.instantiate()
	var img: Image = swamp._pool_image(12345)
	var size: int = swamp.POOL_PX
	_check(img.get_width() == size, "textura fora da resolução de pixel art")

	var mid := size / 2
	_check(img.get_pixel(mid, mid).a > 0.99, "centro da poça deveria ser opaco")
	_check(img.get_pixel(0, 0).a < 0.01, "canto da poça deveria ser transparente")

	var palette: Array = swamp.POOL_PALETTE + [swamp.POOL_BUBBLE, swamp.POOL_SLUDGE]
	var off_palette := 0
	for y in size:
		for x in size:
			var px := img.get_pixel(x, y)
			if px.a > 0.01 and not px in palette:
				off_palette += 1
	_check(off_palette == 0, "%d pixels fora da paleta 16 bits" % off_palette)

	_check(img.get_data() != swamp._pool_image(999).get_data(), "poças saíram idênticas")
	swamp.free()


## A câmera é fixa e olha pra baixo: o céu só pode viver no vazio ALÉM da parede
## norte (z < 0) e ABAIXO do chão (y < 0). Se subir pra cima do mapa, some da tela.
func _test_night_sky_sits_behind_the_map() -> void:
	var swamp: Node3D = SWAMP.instantiate()

	for layer in [SwampMap.SKY_STARS_POS, SwampMap.SKY_MOON_POS]:
		_check(layer.z < 0.0, "camada do céu deveria ficar além da parede norte: %v" % layer)
		_check(layer.y < 0.0, "camada do céu deveria ficar abaixo do chão: %v" % layer)

	# a lua fica mais perto da câmera que as estrelas — é isso que dá o parallax
	var stars_depth := SwampMap.SKY_STARS_POS.distance_to(SwampMap.SKY_MOON_POS)
	_check(stars_depth > 5.0, "as camadas precisam de profundidades distintas pro parallax")
	_check(SwampMap.SKY_MOON_POS.z > SwampMap.SKY_STARS_POS.z, "a lua deveria estar à frente das estrelas")

	# a lua é um disco: opaca no centro, vazada nos cantos
	var moon: Image = swamp._moon_image()
	var mid: int = SwampMap.SKY_MOON_PX / 2
	_check(moon.get_pixel(mid, mid).a > 0.99, "centro da lua deveria ser opaco")
	_check(moon.get_pixel(0, 0).a < 0.01, "canto da lua deveria ser transparente")

	# o campo de estrelas tem estrelas, e não é só a cor da noite
	var stars: Image = swamp._starfield_image(1337)
	var lit := 0
	for y in SwampMap.SKY_STARS_PX.y:
		for x in SwampMap.SKY_STARS_PX.x:
			if stars.get_pixel(x, y) != SwampMap.SKY_NIGHT:
				lit += 1
	_check(lit > 100, "o céu ficou sem estrelas (%d acesas)" % lit)
	swamp.free()

	# a lua entra no campo de visão só com o player lá em cima
	_check(_moon_in_view(2.0), "encostado na parede norte, a lua deveria aparecer")
	_check(_moon_in_view(5.0), "na faixa de cima do mapa a lua ainda aparece")
	_check(not _moon_in_view(17.0), "no meio do mapa a lua não deveria aparecer")
	_check(not _moon_in_view(30.0), "lá embaixo a lua não deveria aparecer")

	# e a parede norte precisa ser baixa, senão ela tapa a faixa de céu inteira
	_check(SwampMap.NORTH_WALL_HEIGHT < SwampMap.WALL_HEIGHT,
		"a parede norte tapa o céu se for tão alta quanto as outras")


## Reconstrói o rig da câmera (main.tscn) com o player em `player_z` e pergunta
## se a lua cai dentro do frustum.
func _moon_in_view(player_z: float) -> bool:
	var rig := Node3D.new()
	rig.rotation_degrees.x = Iso.CAM_PITCH
	rig.position = Vector3(SwampMap.MAP_W / 2.0, 0.0, player_z)
	var cam := Camera3D.new()
	cam.fov = 25.0
	cam.near = 0.1
	cam.far = 120.0
	cam.position = Vector3(0, 0, 25)
	rig.add_child(cam)
	add_child(rig)
	var visible := cam.is_position_in_frustum(SwampMap.SKY_MOON_POS)
	rig.free()
	return visible
