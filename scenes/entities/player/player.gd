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

# arco do arqueiro (auto-attack da classe): segurar o ataque "puxa" a flecha,
# soltar dispara. Dano escala com o tempo puxado (até BOW_MAX_CHARGE); a flecha
# atravessa BOW_PIERCE inimigos antes de sumir.
const BOW_MAX_CHARGE := 2.0    # s de puxada até o dano máximo
const BOW_MIN_DAMAGE := 3      # tiro sem puxar (toque rápido)
const BOW_MAX_DAMAGE := 10     # tiro com o arco totalmente puxado
const BOW_PIERCE := 4          # nº de inimigos que a flecha atravessa
const BOW_COOLDOWN := ARCHER_ATTACK_CD  # pequena recuperação após soltar

# geometria do arco desenhado (visto de cima, no plano XZ na altura do peito):
# braços em "^" bojando pra frente (+Z = mira); corda/flecha puxam pra trás.
const BOW_APEX := Vector3(0, 0, 0.7)      # empunhadura, à frente
const BOW_TIP_L := Vector3(-0.42, 0, 0.28)  # ponta do braço esquerdo
const BOW_TIP_R := Vector3(0.42, 0, 0.28)   # ponta do braço direito
const BOW_NOCK_REST := 0.28   # z do encaixe sem puxar
const BOW_NOCK_FULL := -0.1   # z do encaixe totalmente puxado (atrás)
const BOW_ARROW_LEN := 0.95
const BOW_WOOD := Color(0.72, 0.46, 0.2)      # madeira do arco
const BOW_STRING_COL := Color(0.88, 0.86, 0.74)  # corda clara
const BOW_ARROW_COL := Color(0.6, 0.45, 0.3)     # haste de madeira
const BOW_TIP_COL := Color(1.5, 1.4, 1.05)       # ponta metálica

# raio elétrico (auto-attack do mago com o cajado): segurar canaliza um arco que
# encadeia entre inimigos (até BEAM_MAX_TARGETS), dando BEAM_DPS por segundo em
# cada um. Sem cooldown — é o AA da classe, arco redesenhado (jitter) todo frame.
const BEAM_RANGE := 8.0          # alcance até o 1º inimigo
const BEAM_BOUNCE_RANGE := 6.0   # alcance de cada salto pro próximo
const BEAM_MAX_TARGETS := 3      # rebate em no máximo 3 inimigos
const BEAM_DPS := 1.0            # dano por segundo em cada alvo do arco
const BEAM_COLOR := Color(1.3, 1.9, 3.2)   # arco elétrico azul (HDR p/ o glow)

const PISTOL_DAMAGE := 5                         # 75% do dano do arco (6 × 0,75 = 4,5 → 5)
const PISTOL_COOLDOWN := 0.9                     # recarga de CADA carga, independente uma da outra
const BLOWGUN_DAMAGE := 3                        # 50% do dano do arco
const BLOWGUN_COOLDOWN := ARCHER_ATTACK_CD / 0.75  # atira a 75% da velocidade do arco

# orbe carregável (mago): segurar o ataque carrega em 3 estágios de 1.5s;
# soltar dispara. Estágio N = N× o dano E o estouro base do cajado (máx 3×).
const CHARGE_ORB_STAGE_TIME := 1.5
const CHARGE_ORB_STAGES := 3
const CHARGE_ORB_MAX_TIME := CHARGE_ORB_STAGE_TIME * CHARGE_ORB_STAGES  # 4.5s p/ o 3º estágio
const ORB_COOLDOWN := MAGE_ATTACK_CD      # recarga própria após o disparo

# VFX da carga: bola de energia crescente na frente do peito. A cor salta a cada
# estágio (mesma cor vai pro estouro), o tamanho cresce contínuo até a carga máx.
const CHARGE_FX_COLORS := [
	Color(0.6, 0.35, 1.0, 0.70),   # estágio 1 — roxo suave
	Color(1.0, 0.35, 1.0, 0.85),   # estágio 2 — magenta forte
	Color(1.6, 1.2, 0.7, 1.0),     # estágio 3 — branco-quente (carga máxima)
]
const CHARGE_FX_MIN_SCALE := 0.5
const CHARGE_FX_MAX_SCALE := 2.0
const CHARGE_ORBITERS := 3           # faíscas girando ao redor do núcleo
const CHARGE_MOTE_INTERVAL := 0.05   # s entre motes que convergem pra dentro

# tint do estouro por estágio (multiplica o flash roxo — só clareia/esquenta,
# nunca escurece; junto com o tamanho 3× deixa o blast bem "condizente" à carga).
const CHARGE_BLAST_TINTS := [
	Color(1.0, 1.0, 1.0),      # estágio 1 — blast base
	Color(1.15, 0.95, 1.2),    # estágio 2 — magenta mais forte
	Color(1.4, 1.15, 1.0),     # estágio 3 — clarão quente
]

# luva (mago): rajada rápida — segurar cospe orbes fracos em fluxo contínuo.
const GLOVE_DAMAGE := 2               # cada orbe é fraco; o volume de tiros é que conta
const GLOVE_EXPLOSION_MULT := 0.3     # estouro pequeno por orbe
const GLOVE_FIRE_INTERVAL := 0.15     # s entre um orbe e o outro enquanto segura

# martelo (lutador): golpe pesado, dano baixo mas atordoa forte. Clique = 1 golpe.
const HAMMER_DAMAGE := 2
const HAMMER_STUN := 2.0
const HAMMER_COOLDOWN := 1.8

# rapiera (lutador): segurar o ataque = estocadas rápidas de dano baixo; cada
# acerto renova (não acumula) um slow de 20% no alvo. Dano 0,5 vira acumulador
# (o dano do jogo é int): a cada 2 estocadas sai 1 de dano.
const RAPIER_DAMAGE := 0.5
const RAPIER_INTERVAL := 0.12         # s entre estocadas (~8/s)
const RAPIER_RADIUS := 3.0            # alcance médio do estoque
const RAPIER_ARC_DEG := 40.0          # cone estreito à frente
const RAPIER_SLOW := 0.2              # 20% mais lento
const RAPIER_SLOW_DURATION := 1.0     # s; cada estocada renova

# baque do martelo: impacto pontual à frente — coluna do golpe + anel de choque
# radial + estrela de rachaduras no chão + clarão, com tremor de câmera.
const HAMMER_FX_TIME := 0.34
const HAMMER_FX_COLOR := Color(2.4, 1.95, 1.05, 0.95)  # dourado quente, pesado
const HAMMER_CRACKS := 7        # raios da estrela de impacto no chão
const HAMMER_SHAKE := 0.22      # amplitude do tremor de câmera (m)

# estocada da rapieira: lâmina fina que dispara à frente e recolhe.
const RAPIER_FX_TIME := 0.14
const RAPIER_FX_COLOR := Color(2.0, 2.2, 2.8, 0.95)  # aço gélido

# ícone da arma atual (mesmo emoji do GameState), flutuando na frente do
# personagem e seguindo a direção da mira.
const WEAPON_ICON_OFFSET := 0.6  # m à frente do peito
const PISTOL_ICON_SPREAD := 0.28  # m: afasta as 2 pistolas para os lados da mira

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
# 2ª barra + 2º ícone: só a pistola usa (2 canos, cada um com sua recarga/UI)
var _attack_bar2: Node3D
var _attack_bar_fill2: MeshInstance3D

# 2 cargas de pistola, cada uma recarrega sozinha (valor = s restantes; 0 = pronta)
var _pistol_cd := [0.0, 0.0]
var _pistol_was_pressed := false  # p/ detectar o toque (borda): 1 tiro por clique

var _glove_cd := 0.0           # s até o próximo orbe da rajada da luva (0 = pronto)

var _rapier_cd := 0.0          # s até a próxima estocada da rapiera (0 = pronto)
var _rapier_accum := 0.0       # acumulador de dano fracionário (0,5 por estocada)

var _bow_charge_time := 0.0    # s que o arco está sendo puxado (0 = solto)
var _bow_fx: Node3D            # pivô do arco (braços + corda + flecha), mira o mouse
var _bow_string_l: MeshInstance3D  # corda: metade esquerda (tip → encaixe)
var _bow_string_r: MeshInstance3D  # corda: metade direita
var _bow_arrow: MeshInstance3D     # haste da flecha encaixada
var _bow_tip: MeshInstance3D       # ponta da flecha

var _beam_tick_left := 0.0     # s até o próximo tick de dano do raio (acumula segurado)
var _beam_fx: MeshInstance3D   # arcos elétricos (ImmediateMesh redesenhado por frame)
var _beam_muzzle: Sprite3D     # brilho na ponta do cajado enquanto canaliza

var _orb_charge_time := 0.0    # 0 = sem carga em andamento
var _charge_fx: Sprite3D       # bola de energia (núcleo) visível enquanto carrega
var _charge_core: Sprite3D     # coração branco-quente no centro
var _charge_halo: Sprite3D     # halo difuso atrás
var _charge_orbiters: Array[Sprite3D] = []  # faíscas orbitando
var _charge_mote_left := 0.0   # s até o próximo mote convergir
var _charge_stage_shown := 0   # último estágio que já deu o pulso de subida

var _poison_zones := 0        # quantas poças estão tocando o player
var _poison_left := 0.0       # tempo restante do debuff de veneno
var _poison_tick := 0.0
var _poison_icon: Sprite3D

var _weapon_icon: Label3D
var _weapon_icon2: Label3D  # 2ª pistola (só visível com a pistola equipada)

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
	_build_charge_fx()
	_build_bow_fx()
	_build_beam_fx()
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
	_pistol_cd[0] = 0.0     # trocar de arma deixa as 2 cargas da pistola prontas
	_pistol_cd[1] = 0.0
	_glove_cd = 0.0         # ...e a luva pronta pra rajar na hora
	_rapier_cd = 0.0        # ...e a rapiera pronta pra estocar na hora
	_rapier_accum = 0.0     # ...zerando o dano fracionário acumulado
	_orb_charge_time = 0.0  # ...e também cancela carga de orbe pendente
	_hide_charge_fx()
	_bow_charge_time = 0.0  # ...e cancela a puxada do arco
	_bow_fx.visible = false
	_beam_fx.visible = false  # ...e desliga o raio elétrico
	_beam_muzzle.visible = false
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
	_regen_mana(delta)
	_update_poison(delta)
	_update_weapon_icon()
	_update_attack_bar()

	for i in 4:
		if _skill_key_pressed(i) and _can_cast(i):
			_cast(i)

	if GameState.equipped_weapon == "orbe":
		_update_charge_orb(delta)
	elif GameState.equipped_weapon == "pistola":
		_update_pistol(delta)
	elif GameState.equipped_weapon == "luva":
		_update_glove(delta)
	elif GameState.equipped_weapon == "rapiera":
		_update_rapier(delta)
	elif GameState.equipped_weapon == "" and GameState.selected_class == "arqueiro":
		_update_bow(delta)
	elif GameState.equipped_weapon == "" and GameState.selected_class == "mago":
		_update_beam(delta)
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


func _is_pistol() -> bool:
	return GameState.equipped_weapon == "pistola"


## Só o emoji mesmo (sem sprite dedicado), igual ao ItemPickup no chão.
func _build_weapon_icon() -> void:
	_weapon_icon = _make_weapon_icon()
	_weapon_icon2 = _make_weapon_icon()


func _make_weapon_icon() -> Label3D:
	var icon := Label3D.new()
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.outline_size = 8
	icon.font_size = 48
	icon.visible = false
	add_child(icon)
	return icon


## Reposiciona o ícone na frente do personagem, na direção da mira — chamado
## todo frame porque a mira muda mesmo sem atacar. A pistola são 2 armas, então
## mostra 2 emojis, um de cada lado da mira.
func _update_weapon_icon() -> void:
	var icon := _current_weapon_icon()
	if icon == "":
		_weapon_icon.visible = false
		_weapon_icon2.visible = false
		return
	var front := CAST_OFFSET + _aim_direction() * WEAPON_ICON_OFFSET
	_weapon_icon.text = icon
	_weapon_icon.visible = true
	if _is_pistol():
		var side := _aim_direction().cross(Vector3.UP).normalized() * PISTOL_ICON_SPREAD
		_weapon_icon.position = front + side
		_weapon_icon2.text = icon
		_weapon_icon2.visible = true
		_weapon_icon2.position = front - side
	else:
		_weapon_icon.position = front
		_weapon_icon2.visible = false


## Trilho escuro + preenchimento branco translúcido, no mesmo pitch da câmera
## fixa que a HealthBar usa (billboard por eixo desalinharia o preenchimento).
func _build_attack_bar() -> void:
	var bar := Node3D.new()
	bar.position.y = ATTACK_BAR_HEIGHT
	bar.rotation_degrees.x = Iso.CAM_PITCH
	add_child(bar)
	_make_bar_quad(bar, ATTACK_BAR_TRACK, 0.0)
	_attack_bar_fill = _make_bar_quad(bar, ATTACK_BAR_FILL, 0.01)

	# 2ª barra empilhada logo acima: só a pistola (2 canos) a mostra
	_attack_bar2 = Node3D.new()
	_attack_bar2.position.y = ATTACK_BAR_HEIGHT + ATTACK_BAR_THICKNESS + 0.02
	_attack_bar2.rotation_degrees.x = Iso.CAM_PITCH
	_attack_bar2.visible = false
	add_child(_attack_bar2)
	_make_bar_quad(_attack_bar2, ATTACK_BAR_TRACK, 0.0)
	_attack_bar_fill2 = _make_bar_quad(_attack_bar2, ATTACK_BAR_FILL, 0.01)


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
## Pistola: 2 barras, uma por cano, cada uma seguindo sua própria recarga.
func _update_attack_bar() -> void:
	if _is_pistol():
		_attack_bar2.visible = true
		_fill_bar(_attack_bar_fill, 1.0 - _pistol_cd[0] / PISTOL_COOLDOWN)
		_fill_bar(_attack_bar_fill2, 1.0 - _pistol_cd[1] / PISTOL_COOLDOWN)
		return
	_attack_bar2.visible = false
	var ratio := 1.0
	if _attack_cd > 0.0:
		ratio = 1.0 - _attack_cd / _attack_cd_total
	_fill_bar(_attack_bar_fill, ratio)


func _fill_bar(fill: MeshInstance3D, ratio: float) -> void:
	var filled := ATTACK_BAR_WIDTH * clampf(ratio, 0.0, 1.0)
	fill.scale = Vector3(maxf(filled, 0.001), ATTACK_BAR_THICKNESS, 1.0)
	fill.position.x = -ATTACK_BAR_WIDTH / 2.0 + filled / 2.0


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
	# (pistola e orbe têm fluxo próprio no _physics_process, não passam por aqui)
	match GameState.equipped_weapon:
		"zarabatana":
			_set_attack_cd(BLOWGUN_COOLDOWN)
			_blowgun_attack(dir)
			return
		"martelo":
			_set_attack_cd(HAMMER_COOLDOWN)
			_hammer_attack(dir)
			return

	_set_attack_cd(ATTACK_COOLDOWN.get(GameState.selected_class, MAGE_ATTACK_CD))
	match GameState.selected_class:
		"lutador": _melee_attack(dir)
		"arqueiro": _arrow_volley(dir)
		_: _orb_attack(dir)


## Pistola: 2 canos independentes, cada um com sua recarga de 0,9s. Um tiro por
## clique (o primeiro cano pronto) — não sai rajada segurando. Como são 2 canos,
## clicar 2x bem rápido dispara os dois em sequência antes de qualquer recarga.
func _update_pistol(delta: float) -> void:
	for i in _pistol_cd.size():
		if _pistol_cd[i] > 0.0:
			_pistol_cd[i] -= delta
	# as 2 barras seguem cada _pistol_cd direto (ver _update_attack_bar)

	var pressed := Input.is_action_pressed("attack")
	var just_clicked := pressed and not _pistol_was_pressed
	_pistol_was_pressed = pressed
	if not just_clicked:
		return
	for i in _pistol_cd.size():
		if _pistol_cd[i] <= 0.0:
			_moving = false
			velocity = Vector3.ZERO
			_fire_pistol_shot(_aim_direction(), i)
			_pistol_cd[i] = PISTOL_COOLDOWN
			return  # 1 tiro por clique


## Cada cano dispara do seu lado (mesmo afastamento dos 2 ícones da pistola).
func _fire_pistol_shot(dir: Vector3, barrel: int) -> void:
	var side := dir.cross(Vector3.UP).normalized() * PISTOL_ICON_SPREAD
	var bolt: MagicBolt = BOLT_SCENE.instantiate()
	bolt.is_arrow = true
	bolt.direction = dir
	bolt.damage = PISTOL_DAMAGE
	bolt.position = global_position + CAST_OFFSET + (side if barrel == 0 else -side)
	get_tree().current_scene.add_child(bolt)


func _blowgun_attack(dir: Vector3) -> void:
	var dart: MagicBolt = BOLT_SCENE.instantiate()
	dart.is_arrow = true
	dart.direction = dir
	dart.damage = BLOWGUN_DAMAGE
	dart.applies_poison = true
	dart.position = global_position + CAST_OFFSET
	get_tree().current_scene.add_child(dart)


## Esfera de energia da carga, em camadas: halo difuso atrás, núcleo (bola
## principal), coração branco-quente na frente e faíscas orbitando. Tudo
## billboard e escondido até começar a carregar.
func _build_charge_fx() -> void:
	_charge_halo = _make_charge_sprite(0.05)
	_charge_fx = _make_charge_sprite(0.03)
	_charge_core = _make_charge_sprite(0.016)
	for _i in CHARGE_ORBITERS:
		_charge_orbiters.append(_make_charge_sprite(0.012))
	_hide_charge_fx()


func _make_charge_sprite(px: float) -> Sprite3D:
	var spr := Sprite3D.new()
	spr.texture = GLOW_TEX
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.pixel_size = px
	spr.visible = false
	add_child(spr)
	return spr


## Esconde todas as camadas da carga e zera o estado do efeito.
func _hide_charge_fx() -> void:
	_charge_halo.visible = false
	_charge_fx.visible = false
	_charge_core.visible = false
	for o in _charge_orbiters:
		o.visible = false
	_charge_stage_shown = 0
	_charge_mote_left = 0.0


## Orbe carregável: enquanto o ataque estiver segurado (e sem recarga pendente)
## só acumula carga; dispara ao soltar o botão, com dano/estouro proporcionais.
func _update_charge_orb(delta: float) -> void:
	if _attack_cd > 0.0:
		_hide_charge_fx()
		return
	if Input.is_action_pressed("attack"):
		_orb_charge_time = minf(_orb_charge_time + delta, CHARGE_ORB_MAX_TIME)
		_moving = false
		velocity = Vector3.ZERO
		_show_charge_fx(delta)
	elif _orb_charge_time > 0.0:
		_fire_charged_orb(_orb_charge_time)
		_orb_charge_time = 0.0
		_hide_charge_fx()
		_set_attack_cd(ORB_COOLDOWN)
	else:
		_hide_charge_fx()


## Esfera de energia que cresce com a carga, troca de cor por estágio e junta
## poder: halo + núcleo + coração quente + faíscas orbitando (que convergem
## conforme carrega), motes vindo de fora pra dentro e um pulso a cada estágio.
func _show_charge_fx(delta: float) -> void:
	var stage := _orb_charge_stage(_orb_charge_time)
	var frac := _orb_charge_time / CHARGE_ORB_MAX_TIME
	var color: Color = CHARGE_FX_COLORS[stage - 1]
	var pos := CAST_OFFSET + _aim_direction() * WEAPON_ICON_OFFSET
	var s := lerpf(CHARGE_FX_MIN_SCALE, CHARGE_FX_MAX_SCALE, frac)
	s *= 1.0 + 0.08 * sin(Time.get_ticks_msec() / 60.0)  # pulsa

	_charge_fx.visible = true
	_charge_fx.position = pos
	_charge_fx.scale = Vector3.ONE * s
	_charge_fx.modulate = color

	_charge_halo.visible = true
	_charge_halo.position = pos
	_charge_halo.scale = Vector3.ONE * s * 1.5
	_charge_halo.modulate = Color(color.r, color.g, color.b, 0.4)

	_charge_core.visible = true
	_charge_core.position = pos
	_charge_core.scale = Vector3.ONE * s * 0.8
	_charge_core.modulate = Color(2.6, 2.4, 3.0, 1.0)  # branco-quente

	# faíscas orbitando: giram e o raio encolhe conforme a carga sobe (convergem)
	var t := Time.get_ticks_msec() / 1000.0
	var radius := lerpf(0.5, 0.12, frac)
	for i in _charge_orbiters.size():
		var o := _charge_orbiters[i]
		var ang := t * 6.0 + i * TAU / _charge_orbiters.size()
		o.visible = true
		o.position = pos + Vector3(cos(ang) * radius, sin(ang) * radius, 0.0)
		o.scale = Vector3.ONE * s * 0.35
		o.modulate = color

	# motes convergindo de fora pra dentro — "juntando energia"
	_charge_mote_left -= delta
	if _charge_mote_left <= 0.0:
		_charge_mote_left = CHARGE_MOTE_INTERVAL
		_spawn_charge_mote(pos, color)

	# subiu de estágio: pulso de choque na cor nova
	if stage > _charge_stage_shown:
		_charge_stage_shown = stage
		_charge_stage_burst(pos, color)


## Mote que nasce afastado e é sugado pra dentro do núcleo enquanto some.
func _spawn_charge_mote(center: Vector3, color: Color) -> void:
	var mote := _make_charge_sprite(0.012)
	var ang := randf() * TAU
	var dist := randf_range(0.6, 1.1)
	mote.position = center + Vector3(cos(ang) * dist, sin(ang) * dist, randf_range(-0.3, 0.3))
	mote.modulate = color
	mote.scale = Vector3.ONE * 0.5
	mote.visible = true
	var tw := mote.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mote, "position", center, CHARGE_MOTE_INTERVAL * 5.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mote, "scale", Vector3.ONE * 0.9, CHARGE_MOTE_INTERVAL * 5.0)
	tw.chain().tween_callback(mote.queue_free)


## Pulso de choque no núcleo ao subir de estágio: um glow que abre e some rápido.
func _charge_stage_burst(center: Vector3, color: Color) -> void:
	var ring := _make_charge_sprite(0.03)
	ring.position = center
	ring.modulate = Color(color.r, color.g, color.b, 0.9)
	ring.scale = Vector3.ONE * 0.4
	ring.visible = true
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * 2.6, 0.3) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(ring.queue_free)


func _fire_charged_orb(charge_time: float) -> void:
	var stage := _orb_charge_stage(charge_time)   # 1..3
	var orb: MagicBolt = BOLT_SCENE.instantiate()
	orb.direction = _aim_direction()
	orb.explosion_damage = MagicBolt.EXPLOSION_DAMAGE * stage   # estágio 3 = 3× o dano base
	orb.explosion_scale = _explosion_scale() * stage            # ...e estouro 3× maior
	orb.explosion_tint = CHARGE_BLAST_TINTS[stage - 1]          # blast na cor da carga
	orb.position = global_position + CAST_OFFSET
	get_tree().current_scene.add_child(orb)


## Estágio de carga alcançado: cada CHARGE_ORB_STAGE_TIME sobe 1, de 1 (ao soltar)
## até CHARGE_ORB_STAGES. Discreto de propósito — carga parcial não conta.
func _orb_charge_stage(charge_time: float) -> int:
	return clampi(int(charge_time / CHARGE_ORB_STAGE_TIME) + 1, 1, CHARGE_ORB_STAGES)


## Luva: rajada rápida. Segurando o ataque, cospe um orbe fraco a cada
## GLOVE_FIRE_INTERVAL — fluxo contínuo enquanto o botão fica pressionado.
func _update_glove(delta: float) -> void:
	if _glove_cd > 0.0:
		_glove_cd -= delta
	_attack_cd = maxf(_glove_cd, 0.0)     # barra fantasma acompanha o próximo orbe
	_attack_cd_total = GLOVE_FIRE_INTERVAL
	if Input.is_action_pressed("attack") and _glove_cd <= 0.0:
		_moving = false
		velocity = Vector3.ZERO
		_fire_glove_orb(_aim_direction())
		_glove_cd = GLOVE_FIRE_INTERVAL


## Luva: espeto de 3 orbes em leque, como o tridente do boss (ghoul_boss._shoot_trident).
func _fire_glove_orb(dir: Vector3) -> void:
	for angle_offset in [-0.4, 0.0, 0.4]:
		var orb: MagicBolt = BOLT_SCENE.instantiate()
		orb.direction = dir.rotated(Vector3.UP, angle_offset)
		orb.explosion_damage = GLOVE_DAMAGE
		orb.explosion_scale = _explosion_scale() * GLOVE_EXPLOSION_MULT
		orb.position = global_position + CAST_OFFSET
		get_tree().current_scene.add_child(orb)


func _melee_attack(dir: Vector3) -> void:
	var arc := _melee_arc_deg()
	_damage_area(global_position, MELEE_RADIUS, _melee_damage(), 0.0, dir, arc)
	_slash_fx(dir, MELEE_RADIUS, arc)
	_sprite.modulate = Color(2.0, 1.6, 0.8)  # flash do golpe
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)


## Martelo (lutador): golpe pesado e lento, dano baixo mas atordoa por HAMMER_STUN.
## Reaproveita a varredura da foice como VFX do impacto.
func _hammer_attack(dir: Vector3) -> void:
	var arc := _melee_arc_deg()
	_damage_area(global_position, MELEE_RADIUS, HAMMER_DAMAGE, HAMMER_STUN, dir, arc)
	_hammer_fx(dir)
	_sprite.modulate = Color(1.4, 1.2, 2.2)  # flash azulado do baque
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)


## Rapiera (lutador): segurando o ataque, estoca a cada RAPIER_INTERVAL — fluxo
## rápido de dano baixo. Cada estocada renova o slow no alvo (não acumula).
func _update_rapier(delta: float) -> void:
	if _rapier_cd > 0.0:
		_rapier_cd -= delta
	_attack_cd = maxf(_rapier_cd, 0.0)     # barra fantasma acompanha a próxima estocada
	_attack_cd_total = RAPIER_INTERVAL
	if Input.is_action_pressed("attack") and _rapier_cd <= 0.0:
		_moving = false
		velocity = Vector3.ZERO
		_rapier_strike(_aim_direction())
		_rapier_cd = RAPIER_INTERVAL


## Dano 0,5 acumulado: sai como int (0 ou 1) a cada estocada, mas o slow é sempre
## aplicado (hits de 0 não mostram número — ver guarda no _on_hit_received dos inimigos).
func _rapier_strike(dir: Vector3) -> void:
	_rapier_accum += RAPIER_DAMAGE
	var dmg := int(_rapier_accum)
	_rapier_accum -= dmg
	_damage_area(
		global_position, RAPIER_RADIUS, dmg, 0.0, dir, RAPIER_ARC_DEG,
		RAPIER_SLOW, RAPIER_SLOW_DURATION,
	)
	_rapier_fx(dir, RAPIER_RADIUS)
	_sprite.modulate = Color(1.7, 1.7, 2.0)  # brilho rápido do estoque
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.08)


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


## Arco (auto-attack do arqueiro): segurar puxa a flecha (acumula dano), soltar
## dispara. Espelha o fluxo do orbe carregável.
func _update_bow(delta: float) -> void:
	if _attack_cd > 0.0:
		_bow_fx.visible = false
		return
	if Input.is_action_pressed("attack"):
		_bow_charge_time = minf(_bow_charge_time + delta, BOW_MAX_CHARGE)
		_moving = false
		velocity = Vector3.ZERO
		_show_bow_fx()
	elif _bow_charge_time > 0.0:
		_fire_bow_arrow(_aim_direction(), _bow_damage(_bow_charge_time))
		_bow_charge_time = 0.0
		_bow_fx.visible = false
		_set_attack_cd(BOW_COOLDOWN)
	else:
		_bow_fx.visible = false


## Dano da flecha: escala linear de BOW_MIN_DAMAGE (toque) a BOW_MAX_DAMAGE (2 s).
func _bow_damage(charge: float) -> int:
	var frac := charge / BOW_MAX_CHARGE
	return int(round(lerpf(BOW_MIN_DAMAGE, BOW_MAX_DAMAGE, frac)))


## Flecha carregada: atravessa BOW_PIERCE inimigos antes de sumir.
func _fire_bow_arrow(dir: Vector3, damage: int) -> void:
	var arrow: MagicBolt = BOLT_SCENE.instantiate()
	arrow.is_arrow = true
	arrow.direction = dir
	arrow.damage = damage
	arrow.pierce = BOW_PIERCE
	arrow.position = global_position + CAST_OFFSET
	get_tree().current_scene.add_child(arrow)


## Arco desenhado: pivô na altura do peito com os dois braços de madeira (fixos),
## a corda em "V" e a flecha encaixada (atualizados na puxada). Visto de cima.
func _build_bow_fx() -> void:
	_bow_fx = Node3D.new()
	_bow_fx.visible = false
	add_child(_bow_fx)
	# braços (estáticos): dois gomos formando o "^" que boja pra frente
	_bow_limb(BOW_TIP_L, BOW_APEX)
	_bow_limb(BOW_TIP_R, BOW_APEX)
	# corda (2 metades) + flecha (haste + ponta): movem com a puxada
	_bow_string_l = _bow_seg_node(BOW_STRING_COL)
	_bow_string_r = _bow_seg_node(BOW_STRING_COL)
	_bow_arrow = _bow_seg_node(BOW_ARROW_COL)
	_bow_tip = _bow_seg_node(BOW_TIP_COL)


func _bow_seg_node(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mi.material_override = mat
	_bow_fx.add_child(mi)
	return mi


func _bow_limb(from: Vector3, to: Vector3) -> void:
	_orient_segment(_bow_seg_node(BOW_WOOD), from, to, 0.05)


## Estica um box fino entre dois pontos no plano XZ local (só gira em Y).
func _orient_segment(mi: MeshInstance3D, from: Vector3, to: Vector3, thick: float) -> void:
	var d := to - from
	var length := maxf(d.length(), 0.001)
	mi.position = (from + to) * 0.5
	mi.rotation = Vector3(0, atan2(d.x, d.z), 0)  # +Z do box aponta pra `to`
	mi.scale = Vector3(thick, thick, length)


## Puxada: mira o pivô no mouse e recua o encaixe (corda em V + flecha) com a carga.
func _show_bow_fx() -> void:
	var frac := _bow_charge_time / BOW_MAX_CHARGE
	var aim := _aim_direction()
	_bow_fx.visible = true
	_bow_fx.position = CAST_OFFSET
	_bow_fx.rotation.y = atan2(aim.x, aim.z)

	var nock := Vector3(0, 0, lerpf(BOW_NOCK_REST, BOW_NOCK_FULL, frac))  # recua ao puxar
	_orient_segment(_bow_string_l, BOW_TIP_L, nock, 0.02)
	_orient_segment(_bow_string_r, BOW_TIP_R, nock, 0.02)
	var head := nock + Vector3(0, 0, BOW_ARROW_LEN)
	_orient_segment(_bow_arrow, nock, head, 0.03)
	_orient_segment(_bow_tip, head - Vector3(0, 0, 0.13), head, 0.06)


## Raio elétrico (AA do mago): segurar canaliza um arco que encadeia entre até
## BEAM_MAX_TARGETS inimigos, dando BEAM_DPS por segundo em cada. Sem cooldown.
func _update_beam(delta: float) -> void:
	if not Input.is_action_pressed("attack"):
		_beam_fx.visible = false
		_beam_muzzle.visible = false
		return
	_moving = false
	velocity = Vector3.ZERO
	var chain := _lightning_targets()
	_show_beam_fx(chain)

	# 1 de dano por segundo em cada alvo: acumula o tempo segurado (não zera ao
	# soltar, então tapear não dá dano de graça).
	_beam_tick_left -= delta
	if _beam_tick_left <= 0.0:
		_beam_tick_left += 1.0 / BEAM_DPS
		for enemy in chain:
			_zap(enemy)


## Cadeia de alvos: o mais próximo do player (até BEAM_RANGE), depois saltos
## pro mais próximo ainda não atingido (até BEAM_BOUNCE_RANGE), no máx 3.
func _lightning_targets() -> Array:
	var chain: Array = []
	var enemies := get_tree().get_nodes_in_group("enemies")
	var from := global_position
	var reach := BEAM_RANGE
	while chain.size() < BEAM_MAX_TARGETS:
		var best: Node3D = null
		var best_d := reach * reach
		for e in enemies:
			if not is_instance_valid(e) or e in chain:
				continue
			var d: float = from.distance_squared_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		chain.append(best)
		from = best.global_position
		reach = BEAM_BOUNCE_RANGE  # depois do 1º alvo, usa o alcance de salto
	return chain


## Aplica 1 de dano no inimigo pela Hurtbox (mesmo caminho do _damage_area).
func _zap(enemy: Node) -> void:
	if not (is_instance_valid(enemy) and enemy.has_node("Hurtbox")):
		return
	var hb := HitboxComponent.new()
	hb.damage = 1
	enemy.get_node("Hurtbox").take_hit(hb)
	hb.queue_free()


## Arcos elétricos: uma line-strip com jitter por elo (player → alvo1 → alvo2…),
## redesenhada todo frame pra "tremular". Brilho na ponta do cajado sempre visível.
func _show_beam_fx(chain: Array) -> void:
	_beam_muzzle.visible = true
	_beam_muzzle.position = CAST_OFFSET + _aim_direction() * 0.3
	_beam_muzzle.scale = Vector3.ONE * (0.9 + 0.25 * randf())

	var im: ImmediateMesh = _beam_fx.mesh
	im.clear_surfaces()
	if chain.is_empty():
		_beam_fx.visible = false
		return
	_beam_fx.visible = true
	var prev := CAST_OFFSET  # local: peito do player
	for enemy in chain:
		var target: Vector3 = enemy.global_position - global_position + Vector3(0, 0.9, 0)
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in _bolt_points(prev, target):
			im.surface_add_vertex(p)
		im.surface_end()
		prev = target


## Pontos de um raio de A a B com desvio perpendicular aleatório no meio.
func _bolt_points(a: Vector3, b: Vector3) -> PackedVector3Array:
	const SEGS := 6
	var perp := (b - a).cross(Vector3.UP)
	perp = perp.normalized() if perp.length() > 0.001 else Vector3.RIGHT
	var pts := PackedVector3Array()
	for i in range(SEGS + 1):
		var p := a.lerp(b, float(i) / SEGS)
		if i != 0 and i != SEGS:
			p += perp * randf_range(-0.3, 0.3) + Vector3.UP * randf_range(-0.25, 0.25)
		pts.append(p)
	return pts


## Arco elétrico (ImmediateMesh) + brilho de ponta do cajado; escondidos até canalizar.
func _build_beam_fx() -> void:
	_beam_fx = MeshInstance3D.new()
	_beam_fx.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = BEAM_COLOR
	_beam_fx.material_override = mat
	_beam_fx.visible = false
	add_child(_beam_fx)

	_beam_muzzle = Sprite3D.new()
	_beam_muzzle.texture = GLOW_TEX
	_beam_muzzle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_beam_muzzle.pixel_size = 0.025
	_beam_muzzle.modulate = BEAM_COLOR
	_beam_muzzle.visible = false
	add_child(_beam_muzzle)


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


## Baque do martelo: impacto pontual à frente (onde a cabeça cai, na direção da
## mira). Coluna vertical do golpe + clarão + anel de choque radial + estrela de
## rachaduras no chão + tremor de câmera — pesado, não um grito em cone.
func _hammer_fx(dir: Vector3) -> void:
	var impact := global_position + dir * (MELEE_RADIUS * 0.55) + Vector3(0, 0.05, 0)
	_hammer_column(impact)
	_hammer_flash(impact)
	_hammer_ring(impact)
	_hammer_cracks(impact, dir)

	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(HAMMER_SHAKE, HAMMER_FX_TIME * 0.7)


## Material de mesh comum do baque (unshaded, aditivo-ish via cor > 1).
func _hammer_mat(alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(HAMMER_FX_COLOR.r, HAMMER_FX_COLOR.g, HAMMER_FX_COLOR.b, alpha)
	return mat


## Coluna vertical de luz no impacto: nasce alta e clara e desaba (encolhe pra
## baixo, pivô no chão) enquanto some — o peso do golpe descendo.
func _hammer_column(pos: Vector3) -> void:
	var mat := _hammer_mat(0.9)
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 3.2, 0.55)
	var pivot := Node3D.new()
	pivot.position = pos
	get_tree().current_scene.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position.y = 1.6  # base no chão
	pivot.add_child(mi)
	pivot.scale = Vector3(1.3, 1.0, 1.3)
	var tw := pivot.create_tween()
	tw.set_parallel(true)
	tw.tween_property(pivot, "scale:y", 0.0, HAMMER_FX_TIME * 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mat, "albedo_color:a", 0.0, HAMMER_FX_TIME * 0.8)
	tw.chain().tween_callback(pivot.queue_free)


## Clarão quente billboard no ponto do impacto — o "boom".
func _hammer_flash(pos: Vector3) -> void:
	var flash := Sprite3D.new()
	flash.texture = GLOW_TEX
	flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flash.pixel_size = 0.05
	flash.position = pos + Vector3(0, 0.6, 0)
	flash.modulate = Color(3.0, 2.4, 1.4, 1.0)
	flash.scale = Vector3.ONE * 0.4
	get_tree().current_scene.add_child(flash)
	var tw := flash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * 1.6, HAMMER_FX_TIME * 0.5) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, HAMMER_FX_TIME * 0.7)
	tw.chain().tween_callback(flash.queue_free)


## Anel de choque radial no chão, abrindo do impacto pra fora.
func _hammer_ring(pos: Vector3) -> void:
	var mat := _hammer_mat(0.9)
	var ring := TorusMesh.new()
	ring.outer_radius = MELEE_RADIUS * 0.95
	ring.inner_radius = MELEE_RADIUS * 0.72  # anel grosso, "onda de choque"
	var mi := MeshInstance3D.new()
	mi.mesh = ring
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3.ONE * 0.15
	get_tree().current_scene.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE, HAMMER_FX_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, HAMMER_FX_TIME).set_delay(HAMMER_FX_TIME * 0.35)
	tw.chain().tween_callback(mi.queue_free)


## Rachaduras: raios finos deitados no chão saindo do impacto em todas as
## direções, estendendo-se num piscar — a estrela de impacto do martelo.
func _hammer_cracks(pos: Vector3, dir: Vector3) -> void:
	var base_ang := atan2(dir.x, dir.z)
	for i in HAMMER_CRACKS:
		var mat := _hammer_mat(0.95)
		var length := MELEE_RADIUS * randf_range(0.7, 1.15)
		var crack := BoxMesh.new()
		crack.size = Vector3(0.09, 0.04, length)
		var pivot := Node3D.new()
		pivot.position = pos
		pivot.rotation.y = base_ang + i * TAU / HAMMER_CRACKS + randf_range(-0.18, 0.18)
		get_tree().current_scene.add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = crack
		mi.material_override = mat
		mi.position.z = length / 2.0  # cresce do centro pra fora
		pivot.add_child(mi)
		pivot.scale = Vector3(1, 1, 0.1)
		var tw := pivot.create_tween()
		tw.tween_property(pivot, "scale", Vector3.ONE, HAMMER_FX_TIME * 0.35) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, HAMMER_FX_TIME) \
			.set_delay(HAMMER_FX_TIME * 0.3)
		tw.chain().tween_callback(pivot.queue_free)


## Estocada da rapieira: lâmina fina que dispara à frente na direção da mira e
## recolhe num piscar — o alongar rápido dá o gesto de "estoque".
func _rapier_fx(dir: Vector3, length: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = RAPIER_FX_COLOR

	# pivô no peito, girado pra que o +Z aponte na direção da mira
	var pivot := Node3D.new()
	pivot.position = global_position + CAST_OFFSET
	pivot.rotation.y = atan2(dir.x, dir.z)
	get_tree().current_scene.add_child(pivot)

	var blade := BoxMesh.new()
	blade.size = Vector3(0.1, 0.1, length)  # fina, comprida no eixo Z
	var fx := MeshInstance3D.new()
	fx.mesh = blade
	fx.material_override = mat
	fx.position.z = length / 2.0  # cresce pra frente a partir do pivô
	pivot.add_child(fx)

	pivot.scale = Vector3(1, 1, 0.15)  # começa recolhida
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "scale", Vector3.ONE, RAPIER_FX_TIME * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)  # dispara à frente
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, RAPIER_FX_TIME) \
		.set_delay(RAPIER_FX_TIME * 0.4)
	tw.chain().tween_callback(pivot.queue_free)


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
	const SUPER_ORB_SCENE := preload("res://scenes/entities/projectiles/super_orb.tscn")
	var orb: SuperOrb = SUPER_ORB_SCENE.instantiate()
	orb.position = global_position + CAST_OFFSET
	orb.target = Iso.mouse_ground_position(self)
	orb.damage = 50
	orb.stun_duration = SUPER_STUN_DURATION
	get_tree().current_scene.add_child(orb)

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
	slow_factor := 0.0,
	slow_duration := 0.0,
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
		hitbox.slow_factor = slow_factor
		hitbox.slow_duration = slow_duration
		collider.get_node("Hurtbox").take_hit(hitbox)
		hitbox.queue_free()
