class_name Player
extends CharacterBody3D
## Player 2.5D: corpo 3D no plano XZ, sprite billboard. Mira das skills via
## projeção do mouse no chão (Iso.mouse_ground_position). 16 px = 1 m.

const SPEED := 5.6            # m/s (era 90 px/s)
const ARRIVE_DISTANCE := 0.25  # m — perto o bastante do alvo para parar sem "vibrar"

const LIGHTNING_SCENE := preload("res://scenes/skills/projectiles/lightning_bolt.tscn")
const BUBBLE_SCENE := preload("res://scenes/skills/effects/bubble.tscn")
const PILLAR_SCENE := preload("res://scenes/skills/effects/fire_pillar.tscn")
const CAST_OFFSET := Vector3(0, 0.75, 0)  # altura do peito

# slots: 0=raio · 1=bolha · 2=pilar de fogo · 3=superataque
# teclas: mouse-mode = Q,W,E,R · wasd-mode = Q,E,C,R (W/A/S/D vira movimento)
const SKILL_COOLDOWN := [0.6, 5.0, 3.5, 15.0]
const SKILL_MANA := [8, 14, 10, 28]

# raio (Q)
const LIGHTNING_BOUNCES := 3
const LIGHTNING_BOUNCE_RANGE := 9.4

# bolha (W)
const BUBBLE_DURATION := 3.0
const BUBBLE_MAX_SECONDARY := 2
const BUBBLE_SECONDARY_RANGE := 7.5
const BUBBLE_RADIUS := 2.5

# pilar de fogo (E)
const PILLAR_DURATION := 2.5
const PILLAR_RADIUS := 5.0
const PILLAR_TICK_RATE := 0.2

# superataque (R)
const SUPER_EXPLOSION_RADIUS := 12.5
const SUPER_STUN_DURATION := 1.5

const MAX_MANA := 30
const MANA_REGEN := 4.0

# auto-attack (botão esquerdo): sem custo de mana; classe decide forma e ritmo.
const BOLT_SCENE := preload("res://scenes/entities/projectiles/magic_bolt.tscn")
const GLOW_TEX := preload("res://assets/sprites/props/glow_gradient.tres")

const MAGE_ATTACK_CD := 0.5  # ritmo de referência; as outras classes derivam daqui
const ARCHER_ATTACK_CD := MAGE_ATTACK_CD * 0.5  # 2x mais rápido
const ATTACK_COOLDOWN := {
	"mago": MAGE_ATTACK_CD,
	"arqueiro": ARCHER_ATTACK_CD,
	"lutador": MAGE_ATTACK_CD * 2.0,   # 2x mais lento — golpe pesado em arco
}

# armas à distância dropadas por inimigos (ver GameState.equipped_weapon),
# derivadas do dano/ritmo do arco.
const ARROW_DAMAGE := 6                          # dano do arco (= "dano" do arqueiro no GameState)
const PISTOL_DAMAGE := 5                         # 75% do dano do arco (6 × 0,75 = 4,5 → 5)
const PISTOL_BURST_SHOTS := 2
const PISTOL_BURST_GAP := 0.12                   # s entre os 2 tiros da rajada
const PISTOL_COOLDOWN := 0.9                     # recarga após a rajada, independente do arco
const BLOWGUN_DAMAGE := 3                        # 50% do dano do arco
const BLOWGUN_COOLDOWN := ARCHER_ATTACK_CD / 0.75  # atira a 75% da velocidade do arco

# orbe carregável (mago): segurar ataque carrega, soltar dispara — dano e
# estouro crescem linearmente até CHARGE_ORB_MAX_TIME.
const CHARGE_ORB_MAX_TIME := 1.5
const CHARGE_ORB_DAMAGE_BONUS := 1.5      # carga máxima = 2,5x o dano do cajado
const CHARGE_ORB_EXPLOSION_BONUS := 1.0   # carga máxima = 2x o estouro do cajado
const ORB_COOLDOWN := MAGE_ATTACK_CD      # recarga própria após o disparo

# luva (mago): 3 orbes juntos, cada um bem mais fraco que o cajado.
const GLOVE_SHOTS := 3
const GLOVE_DAMAGE := 2               # 30% do estouro do cajado (6 × 0,3 = 1,8 → 2)
const GLOVE_EXPLOSION_MULT := 0.3     # 30% do tamanho de estouro do cajado
const GLOVE_SPACING := 0.55           # m entre os 3 orbes lado a lado
const GLOVE_COOLDOWN := MAGE_ATTACK_CD

# ícone da arma atual (mesmo emoji do GameState), flutuando na frente do
# personagem e seguindo a direção da mira.
const WEAPON_ICON_OFFSET := 0.6  # m à frente do peito

# barra fantasma logo acima da barra de vida (1.8 m): enche conforme o
# auto-attack recarrega — cheia = pronto pra atacar.
const ATTACK_BAR_HEIGHT := 1.94   # m
const ATTACK_BAR_WIDTH := 1.0     # mesma largura da HealthBar
const ATTACK_BAR_THICKNESS := 0.06
const ATTACK_BAR_TRACK := Color(0.05, 0.08, 0.09, 0.45)
const ATTACK_BAR_FILL := Color(1.0, 1.0, 1.0, 0.6)  # branco fantasma

# golpe do lutador: foice varrendo um cone à frente, na direção do mouse.
# A lâmina abre SCYTHE_SPAN_DEG e gira de ponta a ponta; o que ela varre é
# exatamente MELEE_ARC_DEG (span + os dois lados da varredura).
const MELEE_RADIUS := 2.5
const MELEE_DAMAGE := 6
const MELEE_ARC_DEG := 110.0
const SCYTHE_SPAN_DEG := 46.0   # abertura da lâmina
const SCYTHE_INNER := 0.30      # raio interno no cabo (× MELEE_RADIUS)
const SCYTHE_TIP := 0.92        # raio interno na ponta — a lâmina afina até virar gume
const SLASH_FX_TIME := 0.22
const SLASH_SEGMENTS := 16

# cada onda vencida melhora o auto-attack da classe (nível 0 na 1ª onda)
const WAVE_MELEE_DAMAGE_BONUS := 2     # +2 de dano por onda
const WAVE_MELEE_ARC_BONUS := 0.20     # +20% de cone por onda
const WAVE_ORB_EXPLOSION_BONUS := 0.25 # estouro do mago +25% por onda
const ARROW_SPACING := 0.45            # m entre as flechas do arqueiro

# popup de dano do player (mesmo da hitbox dos inimigos, mas em vermelho)
const DAMAGE_NUMBER_SCENE := preload("res://scenes/fx/damage_number.tscn")
const DAMAGE_NUMBER_TINT := Color(1.0, 0.35, 0.32)

# veneno (poças de lodo): slow enquanto dentro + dano por tempo que persiste.
# O debuff é renovado a cada frame dentro da poça e só então conta POISON_LINGER
# segundos até acabar — sair da poça não cura, só inicia a contagem.
const POISON_SLOW := 0.5      # multiplicador de velocidade dentro da poça
const POISON_TICK := 1.0      # s entre ticks de dano
const POISON_LINGER := 3.0    # s que o veneno dura após sair da poça
const POISON_TICK_PCT := 0.02  # 2% da vida máxima por tick

# caveirinha de envenenado que flutua sobre a cabeça. '#' = osso, '.' = órbita.
const POISON_ICON := [
	"  ####  ",
	" ###### ",
	"########",
	"#.####.#",
	"#.####.#",
	"########",
	" ###### ",
	" #.##.# ",
]
const POISON_ICON_BONE := Color8(198, 240, 140)
const POISON_ICON_DARK := Color8(20, 32, 16)
const POISON_ICON_HEIGHT := 2.15  # m — acima da barra de vida (1.8)

const ENEMY_LAYER_MASK := 4  # layer 3 "enemies"

var _cooldowns := [0.0, 0.0, 0.0, 0.0]
var _mana := float(MAX_MANA)
var _attack_cd := 0.0
var _attack_cd_total := 1.0   # recarga cheia do último ataque (base da barra)
var _attack_bar_fill: MeshInstance3D

var _pistol_burst_left := 0    # tiros restantes na rajada atual (0 = nenhuma em andamento)
var _pistol_burst_dir := Vector3.ZERO
var _pistol_burst_timer := 0.0

var _orb_charge_time := 0.0    # 0 = sem carga em andamento

var _poison_zones := 0        # quantas poças estão tocando o player
var _poison_left := 0.0       # tempo restante do debuff de veneno
var _poison_tick := 0.0
var _poison_icon: Sprite3D

var _weapon_icon: Label3D

var _last_health := 0  # p/ virar dano em popup, venha de onde vier

# animação: spritesheet 5 colunas (0=parado, 1-4=andando) x 3 linhas de direção
const ANIM_FPS := 8.0
const ROW_DOWN := 0
const ROW_UP := 1
const ROW_SIDE := 2

var _anim_time := 0.0
var _facing_row := ROW_DOWN

@onready var _sprite: Sprite3D = %Sprite

var _target := Vector3.ZERO
var _moving := false
var _just_pressed := {}  # physical_keycode -> true (limpo a cada tick de física)

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox


func _ready() -> void:
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed)
	hurtbox.hit_received.connect(_on_hit_received)
	EventBus.weapon_equipped.connect(_on_weapon_equipped)
	_last_health = health.health
	_build_poison_icon()
	_build_weapon_icon()
	_build_attack_bar()
	_emit_initial_status.call_deferred()  # deferido: garante que a HUD já conectou


func _emit_initial_status() -> void:
	EventBus.player_health_changed.emit(health.health, health.max_health)
	EventBus.player_mana_changed.emit(int(_mana), MAX_MANA)


## Todo dano vira popup aqui — golpe, veneno, o que for. Ficar preso ao
## hit_received deixaria o veneno (que chama take_damage direto) sem número.
func _on_health_changed(current: int, max_health: int) -> void:
	EventBus.player_health_changed.emit(current, max_health)
	if current < _last_health:
		_spawn_damage_number(_last_health - current)
	_last_health = current


func _spawn_damage_number(amount: int) -> void:
	var dmg_num: Label3D = DAMAGE_NUMBER_SCENE.instantiate()
	dmg_num.text = "-%d" % amount
	dmg_num.modulate = DAMAGE_NUMBER_TINT
	dmg_num.position = global_position + Vector3(randf_range(-0.6, 0.6), 1.9, 0)
	get_tree().current_scene.add_child(dmg_num)


## Arma só troca quando o jogador arrasta uma pro slot de arma do inventário
## (EventBus.weapon_equipped). Pegar do chão apenas guarda no inventário.
## weapon_id "" = slot vazio ou arma da classe → auto-attack padrão.
func _on_weapon_equipped(weapon_id: String) -> void:
	GameState.equipped_weapon = weapon_id
	_pistol_burst_left = 0  # trocar de arma cancela rajada de pistola pendente
	_orb_charge_time = 0.0  # ...e também cancela carga de orbe pendente
	_attack_cd = 0.0        # ...e libera o ataque com a arma nova na hora


func _on_hit_received(_hitbox: HitboxComponent) -> void:
	EventBus.player_damaged.emit(_hitbox.damage, health.health)
	# flash vermelho de dano (modulate no sprite — Node3D não tem modulate)
	_sprite.modulate = Color(2.5, 0.6, 0.6)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)


func _on_died() -> void:
	# morte por enquanto = recomeçar a cena (respawn instantâneo)
	get_tree().reload_current_scene.call_deferred()


## Buffer de "acabou de apertar" por tecla física — Input.is_key_just_pressed()
## NÃO existe na API do Godot (erro nº 3 do ERROS_GODOT.md).
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_just_pressed[event.physical_keycode] = true


func _key_just_pressed(key: Key) -> bool:
	return _just_pressed.has(key)


func _physics_process(delta: float) -> void:
	for i in 4:
		if _cooldowns[i] > 0.0:
			_cooldowns[i] -= delta
	if _attack_cd > 0.0:
		_attack_cd -= delta
	_update_pistol_burst(delta)
	_regen_mana(delta)
	_update_poison(delta)
	_update_weapon_icon()
	_update_attack_bar()

	for i in 4:
		if _skill_key_pressed(i) and _can_cast(i):
			_cast(i)

	if GameState.equipped_weapon == "orbe":
		_update_charge_orb(delta)
	elif Input.is_action_pressed("attack") and _attack_cd <= 0.0:
		_auto_attack()

	if GameState.control_scheme == "wasd":
		_move_wasd()
	else:
		_move_click()

	_update_animation(delta)
	_just_pressed.clear()


## Segurar o botão direito = seguir o cursor (estilo Diablo).
func _move_click() -> void:
	if Input.is_action_pressed("move_click"):
		_target = Iso.mouse_ground_position(self)
		_moving = true

	if _moving:
		var to_target := _target - global_position
		to_target.y = 0.0
		if to_target.length() <= ARRIVE_DISTANCE:
			_moving = false
			velocity = Vector3.ZERO
		else:
			velocity = to_target.normalized() * _speed()
			move_and_slide()


## WASD direto, sem click-to-move.
func _move_wasd() -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_key_pressed(KEY_S):
		dir.z += 1
	if Input.is_key_pressed(KEY_W):
		dir.z -= 1

	_moving = dir.length() > 0.0
	if _moving:
		velocity = dir.normalized() * _speed()
		move_and_slide()
	else:
		velocity = Vector3.ZERO


## Tecla da skill depende do esquema de controle ativo (número sempre funciona).
func _skill_key_pressed(slot: int) -> bool:
	if _key_just_pressed(KEY_1 + slot):
		return true
	var wasd := GameState.control_scheme == "wasd"
	match slot:
		0:
			return _key_just_pressed(KEY_Q)
		1:
			return _key_just_pressed(KEY_E if wasd else KEY_W)
		2:
			return _key_just_pressed(KEY_C if wasd else KEY_E)
		3:
			return _key_just_pressed(KEY_R)
	return false


func _update_animation(delta: float) -> void:
	var walking := _moving and velocity.length() > 0.1
	if walking:
		# direção dominante decide a linha do spritesheet (tela: -Z = cima)
		if absf(velocity.x) > absf(velocity.z):
			_facing_row = ROW_SIDE
			_sprite.flip_h = velocity.x < 0
		else:
			_facing_row = ROW_UP if velocity.z < 0 else ROW_DOWN
		_anim_time += delta
	else:
		_anim_time = 0.0
	var col := 1 + int(_anim_time * ANIM_FPS) % 4 if walking else 0
	_sprite.frame = _facing_row * 5 + col


## Velocidade atual — reduzida enquanto estiver dentro de uma poça de veneno.
func _speed() -> float:
	return SPEED * (POISON_SLOW if _poison_zones > 0 else 1.0)


## Chamado pelas poças de veneno do mapa (entrou = true / saiu = false).
func set_in_poison(inside: bool) -> void:
	_poison_zones = maxi(_poison_zones + (1 if inside else -1), 0)


## Dano de um tick de veneno: 2% da vida máxima. Com 20 de vida isso daria 0,4 —
## como o dano é int, o piso de 1 impede que o debuff vire um nada.
func _poison_damage() -> int:
	return maxi(1, roundi(health.max_health * POISON_TICK_PCT))


## Caveirinha pixelada sobre a cabeça: só aparece com o debuff ativo.
func _build_poison_icon() -> void:
	var w: int = POISON_ICON[0].length()
	var h: int = POISON_ICON.size()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			match POISON_ICON[y][x]:
				"#": img.set_pixel(x, y, POISON_ICON_BONE)
				".": img.set_pixel(x, y, POISON_ICON_DARK)
				_: img.set_pixel(x, y, Color(0, 0, 0, 0))

	_poison_icon = Sprite3D.new()
	_poison_icon.texture = ImageTexture.create_from_image(img)
	_poison_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_poison_icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_poison_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_poison_icon.no_depth_test = true
	_poison_icon.pixel_size = 1.0 / Iso.PPM  # 8 px = 0,5 m
	_poison_icon.position.y = POISON_ICON_HEIGHT
	_poison_icon.visible = false
	add_child(_poison_icon)

	# pulsa enquanto existir — só é visto quando o debuff liga o visible
	var tw := create_tween().set_loops()
	tw.tween_property(_poison_icon, "scale", Vector3.ONE * 1.25, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_poison_icon, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_SINE)


## Emoji da arma em uso agora — a dropada (pistola/zarabatana), ou a da classe
## quando nenhuma foi equipada ainda.
func _current_weapon_icon() -> String:
	if GameState.equipped_weapon != "":
		return GameState.WEAPON_ITEMS.get(GameState.equipped_weapon, {}).get("icon", "")
	return GameState.WEAPONS.get(GameState.selected_class, {}).get("icon", "")


## Só o emoji mesmo (sem sprite dedicado), igual ao ItemPickup no chão.
func _build_weapon_icon() -> void:
	_weapon_icon = Label3D.new()
	_weapon_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_weapon_icon.no_depth_test = true
	_weapon_icon.outline_size = 8
	_weapon_icon.font_size = 48
	_weapon_icon.visible = false
	add_child(_weapon_icon)


## Reposiciona o ícone na frente do personagem, na direção da mira — chamado
## todo frame porque a mira muda mesmo sem atacar.
func _update_weapon_icon() -> void:
	var icon := _current_weapon_icon()
	if icon == "":
		_weapon_icon.visible = false
		return
	_weapon_icon.visible = true
	_weapon_icon.text = icon
	_weapon_icon.position = CAST_OFFSET + _aim_direction() * WEAPON_ICON_OFFSET


## Trilho escuro + preenchimento branco translúcido, no mesmo pitch da câmera
## fixa que a HealthBar usa (billboard por eixo desalinharia o preenchimento).
func _build_attack_bar() -> void:
	var bar := Node3D.new()
	bar.position.y = ATTACK_BAR_HEIGHT
	bar.rotation_degrees.x = Iso.CAM_PITCH
	add_child(bar)
	_make_bar_quad(bar, ATTACK_BAR_TRACK, 0.0)
	_attack_bar_fill = _make_bar_quad(bar, ATTACK_BAR_FILL, 0.01)


func _make_bar_quad(parent: Node3D, color: Color, z_offset: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = color
	mi.material_override = mat
	mi.scale = Vector3(ATTACK_BAR_WIDTH, ATTACK_BAR_THICKNESS, 1.0)
	mi.position.z = z_offset
	parent.add_child(mi)
	return mi


## Enche da esquerda pra direita conforme a recarga passa; cheia = pronto.
## O orbe carregável não tem recarga enquanto carrega, então fica cheia.
func _update_attack_bar() -> void:
	var ratio := 1.0
	if _attack_cd > 0.0:
		ratio = clampf(1.0 - _attack_cd / _attack_cd_total, 0.0, 1.0)
	var filled := ATTACK_BAR_WIDTH * ratio
	_attack_bar_fill.scale = Vector3(maxf(filled, 0.001), ATTACK_BAR_THICKNESS, 1.0)
	_attack_bar_fill.position.x = -ATTACK_BAR_WIDTH / 2.0 + filled / 2.0


## Direção da mira no plano XZ — mouse exatamente em cima do player cai pra frente.
func _aim_direction() -> Vector3:
	var dir := Iso.flat_direction(global_position, Iso.mouse_ground_position(self))
	return dir if dir != Vector3.ZERO else Vector3.FORWARD


## Debuff de veneno: dentro da poça ele é renovado a cada frame (não expira);
## ao sair, começa a contar POISON_LINGER s até acabar, tickando até lá.
func _update_poison(delta: float) -> void:
	if _poison_zones > 0:
		if _poison_left <= 0.0:
			_poison_tick = 0.0  # entrou limpo: o primeiro tick sai na hora
		_poison_left = POISON_LINGER  # dentro da poça o debuff não expira, só renova
	elif _poison_left > 0.0:
		_poison_left = maxf(_poison_left - delta, 0.0)  # fora: conta os 3 s até acabar

	if _poison_left > 0.0:
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = POISON_TICK
			health.take_damage(_poison_damage())
			_sprite.modulate = Color(0.6, 2.2, 0.6)  # flash verde de veneno
			create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.3)

	_poison_icon.visible = _poison_left > 0.0


## Auto-attack (botão esquerdo): o player PARA e ataca. Lutador dá dano em
## área ao redor de si; as outras classes atiram um projétil na mira do mouse.
## Ondas vencidas. Onda 1 = nível 0 (auto-attack base).
func _upgrade_level() -> int:
	return maxi(GameState.current_wave - 1, 0)


func _melee_damage() -> int:
	return MELEE_DAMAGE + WAVE_MELEE_DAMAGE_BONUS * _upgrade_level()


func _melee_arc_deg() -> float:
	var arc := MELEE_ARC_DEG * (1.0 + WAVE_MELEE_ARC_BONUS * _upgrade_level())
	return minf(arc, 360.0)  # além disso a foice daria a volta em si mesma


func _arrow_count() -> int:
	return 1 + _upgrade_level()


func _explosion_scale() -> float:
	return 1.0 + WAVE_ORB_EXPLOSION_BONUS * _upgrade_level()


## Único ponto que arma a recarga — guarda o total pra barra fantasma saber a
## fração que falta.
func _set_attack_cd(seconds: float) -> void:
	_attack_cd = seconds
	_attack_cd_total = maxf(seconds, 0.01)


func _auto_attack() -> void:
	_moving = false
	velocity = Vector3.ZERO

	var dir := _aim_direction()

	# arma dropada por inimigo tem prioridade sobre o auto-attack da classe
	match GameState.equipped_weapon:
		"pistola":
			_start_pistol_burst(dir)
			return
		"zarabatana":
			_set_attack_cd(BLOWGUN_COOLDOWN)
			_blowgun_attack(dir)
			return
		"luva":
			_set_attack_cd(GLOVE_COOLDOWN)
			_glove_attack(dir)
			return

	_set_attack_cd(ATTACK_COOLDOWN.get(GameState.selected_class, MAGE_ATTACK_CD))
	match GameState.selected_class:
		"lutador": _melee_attack(dir)
		"arqueiro": _arrow_volley(dir)
		_: _orb_attack(dir)


## Rajada de 2 tiros rápidos e SÓ DEPOIS entra em recarga — por isso o cooldown
## cheio já é setado aqui (recarga conta a partir do gatilho, não do 2º tiro).
func _start_pistol_burst(dir: Vector3) -> void:
	_set_attack_cd(PISTOL_COOLDOWN)
	_pistol_burst_dir = dir
	_fire_pistol_shot(dir)
	_pistol_burst_left = PISTOL_BURST_SHOTS - 1
	_pistol_burst_timer = PISTOL_BURST_GAP


func _update_pistol_burst(delta: float) -> void:
	if _pistol_burst_left <= 0:
		return
	_pistol_burst_timer -= delta
	if _pistol_burst_timer <= 0.0:
		_fire_pistol_shot(_pistol_burst_dir)
		_pistol_burst_left -= 1


func _fire_pistol_shot(dir: Vector3) -> void:
	var bolt: MagicBolt = BOLT_SCENE.instantiate()
	bolt.is_arrow = true
	bolt.direction = dir
	bolt.damage = PISTOL_DAMAGE
	bolt.position = global_position + CAST_OFFSET
	get_tree().current_scene.add_child(bolt)


func _blowgun_attack(dir: Vector3) -> void:
	var dart: MagicBolt = BOLT_SCENE.instantiate()
	dart.is_arrow = true
	dart.direction = dir
	dart.damage = BLOWGUN_DAMAGE
	dart.applies_poison = true
	dart.position = global_position + CAST_OFFSET
	get_tree().current_scene.add_child(dart)


## Orbe carregável: enquanto o ataque estiver segurado (e sem recarga pendente)
## só acumula carga; dispara ao soltar o botão, com dano/estouro proporcionais.
func _update_charge_orb(delta: float) -> void:
	if _attack_cd > 0.0:
		return
	if Input.is_action_pressed("attack"):
		_orb_charge_time = minf(_orb_charge_time + delta, CHARGE_ORB_MAX_TIME)
		_moving = false
		velocity = Vector3.ZERO
	elif _orb_charge_time > 0.0:
		_fire_charged_orb(_orb_charge_time)
		_orb_charge_time = 0.0
		_set_attack_cd(ORB_COOLDOWN)


func _fire_charged_orb(charge_time: float) -> void:
	var t := charge_time / CHARGE_ORB_MAX_TIME
	var orb: MagicBolt = BOLT_SCENE.instantiate()
	orb.direction = _aim_direction()
	orb.explosion_damage = roundi(MagicBolt.EXPLOSION_DAMAGE * (1.0 + t * CHARGE_ORB_DAMAGE_BONUS))
	orb.explosion_scale = _explosion_scale() * (1.0 + t * CHARGE_ORB_EXPLOSION_BONUS)
	orb.position = global_position + CAST_OFFSET
	get_tree().current_scene.add_child(orb)


## Luva: 3 orbes fracos lado a lado (mesmo padrão espacial da flechada do arqueiro).
func _glove_attack(dir: Vector3) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	for i in GLOVE_SHOTS:
		var offset := (i - (GLOVE_SHOTS - 1) / 2.0) * GLOVE_SPACING
		var orb: MagicBolt = BOLT_SCENE.instantiate()
		orb.direction = dir
		orb.explosion_damage = GLOVE_DAMAGE
		orb.explosion_scale = _explosion_scale() * GLOVE_EXPLOSION_MULT
		orb.position = global_position + CAST_OFFSET + side * offset
		get_tree().current_scene.add_child(orb)


func _melee_attack(dir: Vector3) -> void:
	var arc := _melee_arc_deg()
	_damage_area(global_position, MELEE_RADIUS, _melee_damage(), 0.0, dir, arc)
	_slash_fx(dir, MELEE_RADIUS, arc)
	_sprite.modulate = Color(2.0, 1.6, 0.8)  # flash do golpe
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)


## Uma flecha por nível, lado a lado e paralelas (não em leque).
func _arrow_volley(dir: Vector3) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	var count := _arrow_count()
	for i in count:
		var offset := (i - (count - 1) / 2.0) * ARROW_SPACING
		var arrow: MagicBolt = BOLT_SCENE.instantiate()
		arrow.is_arrow = true
		arrow.direction = dir
		arrow.damage = ARROW_DAMAGE
		arrow.position = global_position + CAST_OFFSET + side * offset
		get_tree().current_scene.add_child(arrow)


func _orb_attack(dir: Vector3) -> void:
	var orb: MagicBolt = BOLT_SCENE.instantiate()
	orb.direction = dir
	orb.explosion_scale = _explosion_scale()
	orb.position = global_position + CAST_OFFSET
	get_tree().current_scene.add_child(orb)


## Meio-ângulo da varredura: o quanto a lâmina gira pra cada lado da mira.
## span + 2×varredura = arc_deg, então a foice cobre exatamente o cone do dano.
func _sweep_half_deg(arc_deg: float) -> float:
	return (arc_deg - SCYTHE_SPAN_DEG) / 2.0


## Foice do lutador: lâmina em crescente que varre o cone do mouse de ponta a
## ponta. O varrido bate com o raio e o arco do _damage_area — o jogador vê
## exatamente o que foi atingido.
func _slash_fx(dir: Vector3, radius: float, arc_deg: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # visível de cima sem cuidar do winding
	mat.albedo_color = Color(3.0, 0.5, 0.3, 0.95)  # gume em brasa

	var fx := MeshInstance3D.new()
	fx.mesh = _scythe_mesh(radius)
	fx.material_override = mat
	fx.position = global_position + Vector3(0, 0.06, 0)

	var aim := atan2(-dir.x, -dir.z)  # a lâmina nasce centrada no -Z
	var sweep := deg_to_rad(_sweep_half_deg(arc_deg))
	fx.rotation.y = aim - sweep
	get_tree().current_scene.add_child(fx)

	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "rotation:y", aim + sweep, SLASH_FX_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# some só no fim da varredura, senão o corte "apaga" antes de chegar na ponta
	tw.tween_property(mat, "albedo_color:a", 0.0, SLASH_FX_TIME * 0.45) \
		.set_delay(SLASH_FX_TIME * 0.55)
	tw.chain().tween_callback(fx.queue_free)


## Lâmina em crescente no plano XZ, centrada no -Z, abrindo SCYTHE_SPAN_DEG.
## O raio interno cresce de SCYTHE_INNER até SCYTHE_TIP: grossa no cabo,
## afiada na ponta — silhueta de foice, não de fatia de pizza.
func _scythe_mesh(radius: float) -> ArrayMesh:
	var half := deg_to_rad(SCYTHE_SPAN_DEG) / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SLASH_SEGMENTS:
		var t0 := float(i) / SLASH_SEGMENTS
		var t1 := float(i + 1) / SLASH_SEGMENTS
		var a0 := lerpf(-half, half, t0)
		var a1 := lerpf(-half, half, t1)
		var in0 := _arc_point(a0, radius * lerpf(SCYTHE_INNER, SCYTHE_TIP, t0))
		var in1 := _arc_point(a1, radius * lerpf(SCYTHE_INNER, SCYTHE_TIP, t1))
		var out0 := _arc_point(a0, radius)
		var out1 := _arc_point(a1, radius)
		st.add_vertex(in0)
		st.add_vertex(out1)
		st.add_vertex(out0)
		st.add_vertex(in0)
		st.add_vertex(in1)
		st.add_vertex(out1)
	return st.commit()


func _arc_point(angle: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, 0.0, -cos(angle) * radius)


## `point` está dentro do cone que sai de `center` na direção `facing`?
## arc_deg = 0 significa círculo inteiro (sem cone).
func _in_arc(center: Vector3, point: Vector3, facing: Vector3, arc_deg: float) -> bool:
	if arc_deg <= 0.0 or facing == Vector3.ZERO:
		return true
	var to_point := Iso.flat_direction(center, point)
	if to_point == Vector3.ZERO:
		return true  # em cima do centro: sempre acerta
	return to_point.angle_to(facing) <= deg_to_rad(arc_deg) / 2.0


func _regen_mana(delta: float) -> void:
	if _mana >= MAX_MANA:
		return
	var before := int(_mana)
	_mana = minf(_mana + MANA_REGEN * delta, float(MAX_MANA))
	if int(_mana) != before:
		EventBus.player_mana_changed.emit(int(_mana), MAX_MANA)


func _can_cast(slot: int) -> bool:
	return _cooldowns[slot] <= 0.0 and _mana >= SKILL_MANA[slot]


func _cast(slot: int) -> void:
	_cooldowns[slot] = SKILL_COOLDOWN[slot]
	_mana -= SKILL_MANA[slot]
	EventBus.player_mana_changed.emit(int(_mana), MAX_MANA)
	EventBus.skill_cooldown_started.emit(slot, SKILL_COOLDOWN[slot])
	EventBus.skill_cast.emit(slot, null)
	match slot:
		0: _cast_lightning()
		1: _cast_bubble()
		2: _cast_pillar()
		3: _cast_super()


func _cast_lightning() -> void:
	var lightning: Node3D = LIGHTNING_SCENE.instantiate()
	lightning.position = global_position + CAST_OFFSET
	lightning.target = Iso.mouse_ground_position(self) + Vector3(0, CAST_OFFSET.y, 0)
	lightning.player = self
	get_tree().current_scene.add_child(lightning)


func _cast_bubble() -> void:
	var bubble: Node3D = BUBBLE_SCENE.instantiate()
	bubble.position = Iso.mouse_ground_position(self)
	bubble.player = self
	get_tree().current_scene.add_child(bubble)


func _cast_pillar() -> void:
	var pillar: Node3D = PILLAR_SCENE.instantiate()
	pillar.position = Iso.mouse_ground_position(self)
	pillar.player = self
	get_tree().current_scene.add_child(pillar)


func _cast_super() -> void:
	var target_pos := Iso.mouse_ground_position(self)
	global_position = target_pos
	_damage_area(target_pos, SUPER_EXPLOSION_RADIUS, 50, SUPER_STUN_DURATION)

	# efeito visual
	_sprite.modulate = Color(1.5, 1.0, 2.0)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.3)


## Dano instantâneo em área: esfera de PhysicsShapeQuery contra os corpos dos
## inimigos, aplicado via Hurtbox (emit puro pulava take_damage). Com `facing` +
## `arc_deg` a esfera vira um cone à frente; sem eles, acerta os 360°.
func _damage_area(
	center: Vector3,
	radius: float,
	damage: int,
	stun: float,
	facing := Vector3.ZERO,
	arc_deg := 0.0,
) -> void:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), center + Vector3(0, 0.75, 0))
	query.collision_mask = ENEMY_LAYER_MASK

	for result in space_state.intersect_shape(query):
		var collider: Object = result.collider
		if not (collider is Node3D and collider.is_in_group("enemies") and collider.has_node("Hurtbox")):
			continue
		if not _in_arc(center, collider.global_position, facing, arc_deg):
			continue
		var hitbox := HitboxComponent.new()
		hitbox.damage = damage
		hitbox.stun_duration = stun
		collider.get_node("Hurtbox").take_hit(hitbox)
		hitbox.queue_free()
