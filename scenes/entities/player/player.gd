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
const ARCHER_ATTACK_CD := MAGE_ATTACK_CD * 0.5  # 2x mais rápido (base da zarabatana)
const ARCHER_VOLLEY_CD := 3.0  # arqueiro dispara uma salva de flechas a cada 3 s
const ATTACK_COOLDOWN := {
	"mago": MAGE_ATTACK_CD,
	"arqueiro": ARCHER_VOLLEY_CD,
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
# os arcos ficam num semicírculo ao redor do player, sempre virado pra mira do
# mouse; ao soltar, disparam um a um de cima pra baixo.
const BOW_FORMATION_RADIUS := 1.0   # m: raio do semicírculo ao redor do player (bem colado)
const BOW_ARC_SPAN := PI            # abertura do leque (PI = semicírculo, centrado na mira)
const BOW_VOLLEY_STEP := 0.05       # s entre cada flecha ao soltar

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
const BEAM_MAX_TARGETS := 3      # rebate em no máximo 3 inimigos (+1 por nível)
const BEAM_DPS := 1.0            # ticks de choque por segundo em cada alvo do arco
const BEAM_DAMAGE := 5           # dano CHEIO do choque = 100% (+1 por nível)
const BEAM_TICK_PCT := 0.2       # cada tick (1 s) entrega 20% do dano cheio
const BEAM_SUPER_TIME := 3.0     # s de choque contínuo no MESMO alvo até o superchoque
const BEAM_SUPER_PCT := 1.0      # superchoque = 100% do dano cheio
const BEAM_STUN := 0.2           # s de atordoamento a cada tick
const BEAM_SUPER_STUN := 0.5     # atordoamento maior no superchoque
const BEAM_COLOR := Color(1.3, 1.9, 3.2)   # arco elétrico azul (HDR p/ o glow)

const PISTOL_DAMAGE := 5                         # 75% do dano do arco (6 × 0,75 = 4,5 → 5)
const PISTOL_COOLDOWN := 0.9                     # recarga de CADA carga, independente uma da outra
const PISTOL_AUTO_INTERVAL := 0.1               # segurar = rajada a cada 0,1 s (respeita a recarga de cada cano)
const PISTOL_MAX_SLOTS := 7                     # máx de disparos sequenciais na rajada; acima disso os canos se agrupam
const BLOWGUN_DAMAGE := 0                        # zarabatana: 0 de dano, vive dos debuffs
const BLOWGUN_COOLDOWN := 0.5                    # cadência fixa de 0,5 s
const ZARA_SLOW := 0.25            # lentidão por stack (empilha; +20% no nível 5)
const ZARA_SLOW_DURATION := 2.0    # s de lentidão antes de expirar a pilha
# rótulo do modo atual (índice = _zara_mode), mostrado sobre a cabeça só com a zarabatana
const ZARA_MODE_LABELS := ["🧪 Veneno", "🧊 Gelo", "🔥 Fogo", "🔀 Alternado"]

# orbe carregável (mago): segurar o ataque carrega em 3 estágios de 1.5s;
# soltar dispara. Estágio N = N× o dano E o estouro base do cajado (máx 3×).
const CHARGE_ORB_STAGE_TIME := 1.5
const CHARGE_ORB_STAGES := 3
const CHARGE_ORB_MAX_TIME := CHARGE_ORB_STAGE_TIME * CHARGE_ORB_STAGES  # 4.5s p/ o 3º estágio
const ORB_COOLDOWN := MAGE_ATTACK_CD      # recarga própria após o disparo
const ORB_NERF := 0.5              # orbe nerfada a 50% (dano e tamanho do estouro)
const ORB_LEVEL_BONUS := 0.20      # +20% por nível na carga e nos status da orbe

# VFX da carga: bola de energia crescente na frente do peito. A cor salta a cada
# estágio (mesma cor vai pro estouro), o tamanho cresce contínuo até a carga máx.
const CHARGE_FX_COLORS := [
	Color(0.6, 0.35, 1.0, 0.70),   # estágio 1 — roxo suave
	Color(1.0, 0.35, 1.0, 0.85),   # estágio 2 — magenta forte
	Color(1.6, 1.2, 0.7, 1.0),     # estágio 3 — branco-quente (carga máxima)
]
const CHARGE_FX_MIN_SCALE := 0.5
const CHARGE_FX_MAX_SCALE := 2.0
const CHARGE_FX_SIZE_MULT := 0.25   # vfx da carga a 25% (só a camada interior)
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
const GLOVE_FIRE_INTERVAL := 1.0      # s de recarga entre rajadas
const GLOVE_PROJECTILES := 2          # orbes por rajada (+1 por nível)
const GLOVE_SPREAD := 0.15            # rad entre os orbes — leque apertado, concentrado na mira

# martelo (lutador): golpe pesado, dano baixo mas atordoa forte. Clique = combo
# de N batidas (N = nível) com HAMMER_MULTI_INTERVAL entre elas; a recarga só
# começa a contar quando a última batida sai.
const HAMMER_DAMAGE := 2
const HAMMER_STUN := 2.0
const HAMMER_COOLDOWN := 1.8
const HAMMER_MULTI_INTERVAL := 0.2   # s entre batidas consecutivas do combo

# espada longa (lutador): cada nível corta 10% da recarga (compõe).
const SWORD_COOLDOWN_REDUCTION := 0.10

# rapiera (lutador): segurar o ataque = estocadas rápidas de dano baixo; cada
# acerto renova (não acumula) um slow de 20% no alvo. Dano 0,5 vira acumulador
# (o dano do jogo é int): a cada 2 estocadas sai 1 de dano.
const RAPIER_DAMAGE := 1.5
const RAPIER_INTERVAL := 0.12         # s entre estocadas no nível 1 (~8/s); o nível multiplica a cadência
const RAPIER_RADIUS := 3.5            # alcance do estoque (comprimento da lâmina)
const RAPIER_HIT_RADIUS := 1.6        # raio da esfera de acerto ao longo da lâmina (largura do estoque)
const RAPIER_SLOW := 0.2              # 20% mais lento
const RAPIER_SLOW_DURATION := 1.0     # s; cada estocada renova
const RAPIER_JITTER_DEG := 9.0        # oscilação da inclinação por estocada (mira em pontos diferentes, sem perder o foco)

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
const PISTOL_RING_RADIUS := 0.7  # m: raio do círculo de pistolas ao redor do player

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
const MAGE_EXPLOSION_AREA_MULT := 0.5  # área de TODO estouro do mago cortada em 50%
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
# barras extras empilhadas: só a pistola usa (1 barra por cano além do 1º)
var _pistol_rows: Array = []   # cada item: {"node": Node3D, "fill": MeshInstance3D}

# cargas de pistola (2 + nível), cada uma recarrega sozinha (valor = s restantes; 0 = pronta)
var _pistol_cd := [0.0, 0.0]
var _pistol_auto_cd := 0.0     # intervalo mínimo entre tiros da rajada (segurar o ataque)
var _pistol_slot := 0          # slot da rajada que dispara agora (rodízio, evita starvation)

var _glove_cd := 0.0           # s até o próximo orbe da rajada da luva (0 = pronto)

var _blowgun_shot := 0         # rodízio do modo alternado da zarabatana (1 debuff por tiro)
var _zara_mode := 0            # modo de tiro: 0=veneno 1=gelo 2=fogo 3=alternado (botão do meio cicla)
var _zara_mode_label: Label3D # rótulo do modo sobre a cabeça (só com a zarabatana)

var _rapier_cd := 0.0          # s até a próxima estocada da rapiera (0 = pronto)
var _rapier_accum := 0.0       # acumulador de dano fracionário (0,5 por estocada)

var _bow_charge_time := 0.0    # s que o arco está sendo puxado (0 = solto)
var _bows: Array = []          # um arco puxado por flecha (nível); cada item é
							   # um Dictionary com o pivô e os segmentos móveis

var _spr_base_y := 0.0         # y original do sprite (base do recuo da pistola)
var _pistol_recoil_tw: Tween   # recuo da pistola: mata o anterior pra não empilhar

var _beam_tick_left := 0.0     # s até o próximo tick de dano do raio (acumula segurado)
var _beam_fx: MeshInstance3D   # arcos elétricos (ImmediateMesh redesenhado por frame)
var _beam_muzzle: Sprite3D     # brilho na ponta do cajado enquanto canaliza
var _beam_shock_time := {}     # instance_id do inimigo → s de choque contínuo (p/ o superchoque)

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

var _weapon_icons: Array = []  # pool de emojis da arma: pistola=2, arqueiro=1/flecha

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
	EventBus.player_leveled_up.connect(_on_leveled_up)
	_last_health = health.health
	_spr_base_y = _sprite.position.y  # base do recuo da pistola
	_build_poison_icon()
	_build_weapon_icon()
	_build_charge_fx()
	_build_bow_fx()
	_build_beam_fx()
	_build_attack_bar()
	_build_zara_label()
	_emit_initial_status.call_deferred()  # deferido: garante que a HUD já conectou


func _emit_initial_status() -> void:
	EventBus.player_health_changed.emit(health.health, health.max_health)
	EventBus.player_mana_changed.emit(int(_mana), MAX_MANA)


## VFX ao subir de nível: flash dourado no sprite + anel de aura que sobe do
## chão e se abre. Puramente visual (escuta EventBus.player_leveled_up).
func _on_leveled_up(_new_level: int) -> void:
	_sprite.modulate = Color(2.2, 1.9, 1.0)  # flash quente dourado
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.35)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.8, 1.45, 0.5, 0.9)  # ouro brilhante (aditivo)
	var ring := TorusMesh.new()
	ring.outer_radius = 0.55
	ring.inner_radius = 0.42
	var mi := MeshInstance3D.new()
	mi.mesh = ring
	mi.material_override = mat
	mi.position = global_position + Vector3(0, 0.1, 0)
	mi.scale = Vector3.ONE * 0.35
	get_tree().current_scene.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 3.0, 0.6) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)  # abre
	tw.tween_property(mi, "position:y", 2.2, 0.6).set_trans(Tween.TRANS_SINE)  # sobe
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6).set_delay(0.15)  # some
	tw.chain().tween_callback(mi.queue_free)


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
	for i in _pistol_cd.size():
		_pistol_cd[i] = 0.0  # trocar de arma deixa todas as cargas da pistola prontas
	_pistol_slot = 0        # ...e reinicia o rodízio da rajada
	_glove_cd = 0.0         # ...e a luva pronta pra rajar na hora
	_rapier_cd = 0.0        # ...e a rapiera pronta pra estocar na hora
	_rapier_accum = 0.0     # ...zerando o dano fracionário acumulado
	_orb_charge_time = 0.0  # ...e também cancela carga de orbe pendente
	_hide_charge_fx()
	_bow_charge_time = 0.0  # ...e cancela a puxada do arco
	_hide_bow_fx()
	_beam_fx.visible = false  # ...e desliga o raio elétrico
	_beam_muzzle.visible = false
	_beam_shock_time.clear()  # ...zerando o acúmulo do superchoque
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


## Botão do meio do mouse cicla o modo de tiro da zarabatana (só quando equipada).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_MIDDLE \
			and GameState.equipped_weapon == "zarabatana":
		_zara_mode = (_zara_mode + 1) % 4
		_blowgun_shot = 0  # recomeça o rodízio do modo alternado


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
	_update_zara_label()
	_update_attack_bar()

	for i in 4:
		if _skill_key_pressed(i) and _can_cast(i):
			_cast(i)

	if _key_just_pressed(KEY_PERIOD):  # debug: "." sobe um nível na hora
		GameState.add_xp(GameState.xp_to_next() - GameState.xp)

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
	_weapon_icons = [_make_weapon_icon(), _make_weapon_icon()]


## Rótulo flutuante do modo da zarabatana (sobre a cabeça), escondido por padrão.
func _build_zara_label() -> void:
	_zara_mode_label = Label3D.new()
	_zara_mode_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zara_mode_label.no_depth_test = true
	_zara_mode_label.outline_size = 8
	_zara_mode_label.font_size = 40
	_zara_mode_label.pixel_size = 0.0075
	_zara_mode_label.position.y = 2.4
	_zara_mode_label.visible = false
	add_child(_zara_mode_label)


## Mostra o modo atual só com a zarabatana equipada; some com qualquer outra arma.
func _update_zara_label() -> void:
	if GameState.equipped_weapon != "zarabatana":
		_zara_mode_label.visible = false
		return
	_zara_mode_label.visible = true
	_zara_mode_label.text = ZARA_MODE_LABELS[_zara_mode]


func _make_weapon_icon() -> Label3D:
	var icon := Label3D.new()
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.outline_size = 8
	icon.font_size = 48
	icon.visible = false
	add_child(icon)
	return icon


## Quantos emojis mostrar: pistola = 1 por cano (2 + nível); o arqueiro mostra um
## arco por flecha (nível); o resto, 1.
func _weapon_icon_count() -> int:
	if _is_pistol():
		return _pistol_count()
	if GameState.equipped_weapon == "" and GameState.selected_class == "arqueiro":
		return _arrow_count()
	return 1


## Reposiciona os ícones na frente do personagem, na direção da mira — chamado
## todo frame porque a mira muda mesmo sem atacar. Vários emojis ficam lado a
## lado, centrados na mira (pistola nas laterais, arqueiro na fila da salva).
func _update_weapon_icon() -> void:
	var icon := _current_weapon_icon()
	var count := _weapon_icon_count()
	if icon == "":
		for lbl: Label3D in _weapon_icons:
			lbl.visible = false
		return
	while _weapon_icons.size() < count:
		_weapon_icons.append(_make_weapon_icon())

	# pistola: emojis num círculo fixo ao redor do player (o tiro é que mira o mouse)
	if _is_pistol():
		for i in _weapon_icons.size():
			var lbl: Label3D = _weapon_icons[i]
			if i >= count:
				lbl.visible = false
				continue
			lbl.text = icon
			lbl.visible = true
			var ang := TAU * i / count
			lbl.position = CAST_OFFSET + Vector3(cos(ang), 0.0, sin(ang)) * PISTOL_RING_RADIUS
		return

	# arqueiro: ícones no MESMO semicírculo em que os arcos nascem (segue a mira);
	# escondidos enquanto puxa, pois aí os arcos desenhados tomam o lugar deles.
	if GameState.equipped_weapon == "" and GameState.selected_class == "arqueiro":
		var aim_ang := atan2(_aim_direction().x, _aim_direction().z)
		for i in _weapon_icons.size():
			var lbl: Label3D = _weapon_icons[i]
			lbl.visible = i < count and _bow_charge_time <= 0.0
			if not lbl.visible:
				continue
			lbl.text = icon
			lbl.position = _bow_slot_position(i, count, aim_ang)
		return

	var aim := _aim_direction()
	var front := CAST_OFFSET + aim * WEAPON_ICON_OFFSET
	var side := aim.cross(Vector3.UP).normalized()
	for i in _weapon_icons.size():
		var lbl: Label3D = _weapon_icons[i]
		if i >= count:
			lbl.visible = false
			continue
		lbl.text = icon
		lbl.visible = true
		lbl.position = front + side * (i - (count - 1) / 2.0) * ARROW_SPACING


## Trilho escuro + preenchimento branco translúcido, no mesmo pitch da câmera
## fixa que a HealthBar usa (billboard por eixo desalinharia o preenchimento).
func _build_attack_bar() -> void:
	var bar := Node3D.new()
	bar.position.y = ATTACK_BAR_HEIGHT
	bar.rotation_degrees.x = Iso.CAM_PITCH
	add_child(bar)
	_make_bar_quad(bar, ATTACK_BAR_TRACK, 0.0)
	_attack_bar_fill = _make_bar_quad(bar, ATTACK_BAR_FILL, 0.01)


## Cria uma barra de recarga empilhada acima da base (cano `index` da pistola) e
## guarda a referência em _pistol_rows. Sob demanda: mais canos = mais barras.
func _make_pistol_row(index: int) -> void:
	var bar := Node3D.new()
	bar.position.y = ATTACK_BAR_HEIGHT + index * (ATTACK_BAR_THICKNESS + 0.02)
	bar.rotation_degrees.x = Iso.CAM_PITCH
	add_child(bar)
	_make_bar_quad(bar, ATTACK_BAR_TRACK, 0.0)
	var fill := _make_bar_quad(bar, ATTACK_BAR_FILL, 0.01)
	_pistol_rows.append({"node": bar, "fill": fill})


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
		# 1 barra por cano: base = cano 0; as extras empilham acima (criadas sob demanda)
		while _pistol_rows.size() < _pistol_cd.size() - 1:
			_make_pistol_row(_pistol_rows.size() + 1)
		_fill_bar(_attack_bar_fill, 1.0 - _pistol_cd[0] / PISTOL_COOLDOWN)
		for i in _pistol_rows.size():
			var row: Dictionary = _pistol_rows[i]
			var shown: bool = i + 1 < _pistol_cd.size()
			row["node"].visible = shown
			if shown:
				_fill_bar(row["fill"], 1.0 - _pistol_cd[i + 1] / PISTOL_COOLDOWN)
		return
	for row: Dictionary in _pistol_rows:
		row["node"].visible = false
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
## Escala pelo nível do personagem (XP de kills). Nível 1 = base (bônus 0).
func _upgrade_level() -> int:
	return maxi(GameState.level - 1, 0)


func _melee_damage() -> int:
	return MELEE_DAMAGE + WAVE_MELEE_DAMAGE_BONUS * _upgrade_level()


func _melee_arc_deg() -> float:
	var arc := MELEE_ARC_DEG * (1.0 + WAVE_MELEE_ARC_BONUS * _upgrade_level())
	return minf(arc, 360.0)  # além disso a foice daria a volta em si mesma


func _arrow_count() -> int:
	return 1 + _upgrade_level()


## Escala do estouro de TODA arma do mago (orbe, carga, luva). MAGE_EXPLOSION_AREA_MULT
## corta a área pela metade — como todos passam por aqui, é um ponto só.
func _explosion_scale() -> float:
	return (1.0 + WAVE_ORB_EXPLOSION_BONUS * _upgrade_level()) * MAGE_EXPLOSION_AREA_MULT


## Choque do cetro: dano base +1 por nível; encadeia em +1 alvo por nível.
func _beam_damage() -> int:
	return BEAM_DAMAGE + _upgrade_level()


func _beam_max_targets() -> int:
	return BEAM_MAX_TARGETS + _upgrade_level()


## Multiplicador da orbe: 50% de nerf na base, +20% por nível (dano e estouro).
func _orb_power() -> float:
	return ORB_NERF * (1.0 + ORB_LEVEL_BONUS * _upgrade_level())


## Tempo de cada estágio de carga: encurta 20% por nível (carrega mais rápido).
func _orb_stage_time() -> float:
	return CHARGE_ORB_STAGE_TIME / (1.0 + ORB_LEVEL_BONUS * _upgrade_level())


func _orb_max_time() -> float:
	return _orb_stage_time() * CHARGE_ORB_STAGES


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
			_hammer_combo(dir)
			return

	var cd: float = ATTACK_COOLDOWN.get(GameState.selected_class, MAGE_ATTACK_CD)
	if GameState.selected_class == "lutador":
		cd *= pow(1.0 - SWORD_COOLDOWN_REDUCTION, _upgrade_level())  # espada longa acelera por nível
	_set_attack_cd(cd)
	match GameState.selected_class:
		"lutador": _melee_attack(dir)
		"arqueiro": _arrow_volley(dir)
		_: _orb_attack(dir)


## Nº de canos da pistola: 2 na base, +1 por nível.
func _pistol_count() -> int:
	return 2 + _upgrade_level()


## Garante um slot de recarga por cano (nunca encolhe — o nível só sobe).
func _ensure_pistol_slots() -> void:
	while _pistol_cd.size() < _pistol_count():
		_pistol_cd.append(0.0)  # cano novo já entra pronto


## Pistola: N canos (2 + nível). Segurar dispara em rajada, um SLOT por
## PISTOL_AUTO_INTERVAL, em rodízio (o slot atual avança sempre — nunca varre do 0,
## então nenhum cano é starved: antes travava no 7º e não chegava no 8º).
## A rajada tem no máx PISTOL_MAX_SLOTS (7) disparos; passando disso os canos extras
## se agrupam por slot (distribuição uniforme): 8 canos = 1 slot atira 2 + 6 atiram 1;
## 15 = 1 slot atira 3 + 6 atiram 2. Cada cano disparado respeita sua recarga de 0,9s.
func _update_pistol(delta: float) -> void:
	_ensure_pistol_slots()
	for i in _pistol_cd.size():
		if _pistol_cd[i] > 0.0:
			_pistol_cd[i] -= delta
	if _pistol_auto_cd > 0.0:
		_pistol_auto_cd -= delta

	if not Input.is_action_pressed("attack") or _pistol_auto_cd > 0.0:
		return

	var count := _pistol_count()
	var slots := mini(count, PISTOL_MAX_SLOTS)
	var s := _pistol_slot % slots
	var base := count / slots          # canos por slot (piso)
	var rem := count % slots           # os primeiros `rem` slots levam +1 cano
	var start := s * base + mini(s, rem)
	var group := base + (1 if s < rem else 0)

	if _pistol_cd[start] > 0.0:
		return  # este slot ainda recarrega — segura o ritmo sem pular o rodízio
	_moving = false
	velocity = Vector3.ZERO
	var dir := _aim_direction()
	for b in group:                    # todos os canos do slot saem JUNTOS
		_fire_pistol_shot(dir, start + b)
		_pistol_cd[start + b] = PISTOL_COOLDOWN
	_pistol_slot = (s + 1) % slots
	_pistol_auto_cd = PISTOL_AUTO_INTERVAL


## Cada cano fica num ponto do círculo ao redor do player; o tiro sempre voa na
## direção do mouse (o círculo é fixo, não gira com a mira).
func _fire_pistol_shot(dir: Vector3, barrel: int) -> void:
	var count := _pistol_count()
	var ang := TAU * barrel / count
	var muzzle := CAST_OFFSET + Vector3(cos(ang), 0.0, sin(ang)) * PISTOL_RING_RADIUS
	var bolt: MagicBolt = BOLT_SCENE.instantiate()
	bolt.is_arrow = true
	bolt.direction = dir
	bolt.damage = PISTOL_DAMAGE
	bolt.position = global_position + muzzle
	get_tree().current_scene.add_child(bolt)
	_pistol_recoil()


## Recuo do tiro: o sprite dá um leve pulinho pra cima e volta — o coice da pistola.
## Sempre termina na base (_spr_base_y), então tiros em rajada não acumulam offset.
func _pistol_recoil() -> void:
	if _pistol_recoil_tw and _pistol_recoil_tw.is_running():
		_pistol_recoil_tw.kill()
	_pistol_recoil_tw = create_tween()
	_pistol_recoil_tw.tween_property(_sprite, "position:y", _spr_base_y + 0.12, 0.04) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pistol_recoil_tw.tween_property(_sprite, "position:y", _spr_base_y, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Zarabatana: dardo de 0 de dano que aplica UM debuff por tiro, alternando entre
## os desbloqueados pelo nível (1 veneno; 2 +lentidão; 3 +fogo).
func _blowgun_attack(dir: Vector3) -> void:
	var dart: MagicBolt = BOLT_SCENE.instantiate()
	dart.is_arrow = true
	dart.direction = dir
	dart.damage = BLOWGUN_DAMAGE
	_blowgun_apply_debuff(dart, _blowgun_next_debuff())
	dart.position = global_position + CAST_OFFSET
	get_tree().current_scene.add_child(dart)


## Debuff do próximo tiro conforme o modo (botão do meio cicla): 0=veneno, 1=gelo,
## 2=fogo (elemento fixo) e 3=alternado (revez entre os três a cada tiro).
func _blowgun_next_debuff() -> String:
	const ELEMENTS := ["veneno", "lentidao", "fogo"]
	if _zara_mode < ELEMENTS.size():
		return ELEMENTS[_zara_mode]  # modo de 1 elemento fixo
	var d: String = ELEMENTS[_blowgun_shot % ELEMENTS.size()]  # modo alternado
	_blowgun_shot += 1
	return d


## Configura o dardo pro debuff, com o bônus de eficácia por nível: nível 4 → veneno
## +25% dano · nível 5 → lentidão +20% · nível 6 → fogo +25% dano.
func _blowgun_apply_debuff(dart: MagicBolt, debuff: String) -> void:
	dart.debuff = debuff
	match debuff:
		"veneno":
			var boost := 1.25 if GameState.level >= 4 else 1.0
			dart.poison_dmg = int(round(MagicBolt.POISON_DAMAGE * boost))
			dart.poison_max_stacks = HealthComponent.POISON_MAX_STACKS + GameState.level / 2  # +1 a cada 2 níveis
		"lentidao":
			var boost := 1.20 if GameState.level >= 5 else 1.0
			dart.slow_factor = ZARA_SLOW * boost
			dart.slow_duration = ZARA_SLOW_DURATION
			dart.slow_stacks = true
		"fogo":
			var boost := 1.25 if GameState.level >= 6 else 1.0
			dart.fire_dmg = int(round(MagicBolt.FIRE_DAMAGE * boost))


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
		_orb_charge_time = minf(_orb_charge_time + delta, _orb_max_time())
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


## ponytail: só a camada interior da bola de energia, a 25% do tamanho (halo,
## coração, faíscas e motes cortados — as camadas empilhadas ficavam grandes e
## poluídas). Cresce com a carga e troca de cor por estágio.
func _show_charge_fx(_delta: float) -> void:
	var stage := _orb_charge_stage(_orb_charge_time)
	var frac := _orb_charge_time / _orb_max_time()
	var color: Color = CHARGE_FX_COLORS[stage - 1]
	var pos := CAST_OFFSET + _aim_direction() * WEAPON_ICON_OFFSET
	var s := lerpf(CHARGE_FX_MIN_SCALE, CHARGE_FX_MAX_SCALE, frac) * CHARGE_FX_SIZE_MULT
	s *= 1.0 + 0.08 * sin(Time.get_ticks_msec() / 60.0)  # pulsa

	_charge_fx.visible = true
	_charge_fx.position = pos
	_charge_fx.scale = Vector3.ONE * s
	_charge_fx.modulate = color


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
	orb.explosion_damage = int(MagicBolt.EXPLOSION_DAMAGE * stage * _orb_power())  # nerf 50% +20%/nível
	orb.explosion_scale = _explosion_scale() * stage * _orb_power()  # estouro menor (nerf + vfx reduzido)
	orb.explosion_tint = CHARGE_BLAST_TINTS[stage - 1]          # blast na cor da carga
	orb.position = global_position + CAST_OFFSET
	get_tree().current_scene.add_child(orb)


## Estágio de carga alcançado: cada CHARGE_ORB_STAGE_TIME sobe 1, de 1 (ao soltar)
## até CHARGE_ORB_STAGES. Discreto de propósito — carga parcial não conta.
func _orb_charge_stage(charge_time: float) -> int:
	return clampi(int(charge_time / _orb_stage_time()) + 1, 1, CHARGE_ORB_STAGES)


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


## Luva: leque de orbes (GLOVE_PROJECTILES na base, +1 por nível), como o tridente
## do boss (ghoul_boss._shoot_trident).
func _fire_glove_orb(dir: Vector3) -> void:
	var count := GLOVE_PROJECTILES + _upgrade_level()
	for i in count:
		var offset := (i - (count - 1) / 2.0) * GLOVE_SPREAD
		var orb: MagicBolt = BOLT_SCENE.instantiate()
		orb.direction = dir.rotated(Vector3.UP, offset)
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


## Combo do martelo: N batidas (N = 1 + nível) com HAMMER_MULTI_INTERVAL entre
## elas. A recarga é armada já no início cobrindo TODAS as batidas + HAMMER_COOLDOWN,
## então a contagem só "vale" depois da última batida (e trava o AA durante o combo).
func _hammer_combo(dir: Vector3) -> void:
	var hits := 1 + _upgrade_level()
	# lock = tempo até a última batida + recarga → recarga efetivamente pós-combo
	_set_attack_cd((hits - 1) * HAMMER_MULTI_INTERVAL + HAMMER_COOLDOWN)
	for i in hits:
		_hammer_attack(dir)
		if i < hits - 1:
			await get_tree().create_timer(HAMMER_MULTI_INTERVAL).timeout
			if not is_instance_valid(self):
				return  # player morreu no meio do combo (cena recarregou)


## Martelo (lutador): golpe pesado e lento, dano baixo mas atordoa por HAMMER_STUN.
## Reaproveita a varredura da foice como VFX do impacto.
func _hammer_attack(dir: Vector3) -> void:
	var arc := _melee_arc_deg()
	_damage_area(global_position, MELEE_RADIUS, _hammer_damage(), HAMMER_STUN, dir, arc)
	_hammer_fx(dir)
	_sprite.modulate = Color(1.4, 1.2, 2.2)  # flash azulado do baque
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)


## Dano do bastão: base + 0,5 por nível (dano do jogo é int, então arredonda —
## cresce 2, 3, 3, 4, 4… em média +0,5 por nível).
func _hammer_damage() -> int:
	return roundi(HAMMER_DAMAGE + 0.5 * _upgrade_level())


## Rapiera (lutador): segurando o ataque, uma única estocada que sai a cada
## _rapier_interval(). Subir de nível NÃO adiciona lâminas — acelera a cadência
## (nível 1 = 1× base, nível 2 = 2×, nível 3 = 3×…). Cada acerto renova o slow.
func _update_rapier(delta: float) -> void:
	if _rapier_cd > 0.0:
		_rapier_cd -= delta
	var interval := _rapier_interval()
	_attack_cd = maxf(_rapier_cd, 0.0)     # barra fantasma acompanha a próxima estocada
	_attack_cd_total = interval
	if Input.is_action_pressed("attack") and _rapier_cd <= 0.0:
		_moving = false
		velocity = Vector3.ZERO
		_rapier_strike(_aim_direction())
		_rapier_cd = interval


## Cadência da estocada: nível multiplica a velocidade (1 + nível → 1×, 2×, 3×…),
## encurtando o intervalo. É assim que subir de nível deixa a rapieira mais forte.
func _rapier_interval() -> float:
	return RAPIER_INTERVAL / float(1 + _upgrade_level())


## Estocada única na mira, com uma leve oscilação de inclinação a cada golpe — como
## se buscasse pontos diferentes sem perder o foco no mouse. Hitbox projetada à frente
## na linha da lâmina (esfera no meio dela): cobre a ponta que o jogador vê estocar e,
## já deslocada pra frente, dispensa filtro de cone (não pega quem está atrás).
## Dano 0,5 acumula (o dano do jogo é int); o slow é sempre aplicado.
func _rapier_strike(dir: Vector3) -> void:
	_rapier_accum += RAPIER_DAMAGE
	var dmg := int(_rapier_accum)
	_rapier_accum -= dmg
	var jitter := deg_to_rad(randf_range(-RAPIER_JITTER_DEG, RAPIER_JITTER_DEG))
	var aim := dir.rotated(Vector3.UP, jitter)
	var hit_center := global_position + aim * (RAPIER_RADIUS * 0.5)
	_damage_area(
		hit_center, RAPIER_HIT_RADIUS, dmg, 0.0,
		Vector3.ZERO, 0.0, RAPIER_SLOW, RAPIER_SLOW_DURATION,
	)
	_rapier_fx(aim, RAPIER_RADIUS)
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
	# os arcos só aparecem ao preparar a flecha (segurando o ataque); soltos, somem
	if _attack_cd <= 0.0 and Input.is_action_pressed("attack"):
		_bow_charge_time = minf(_bow_charge_time + delta, BOW_MAX_CHARGE)
		_moving = false
		velocity = Vector3.ZERO
		_bow_formation()
	elif _bow_charge_time > 0.0:
		_release_bow_volley(_bow_damage(_bow_charge_time))
		_bow_charge_time = 0.0
		_set_attack_cd(ARCHER_VOLLEY_CD)
		_hide_bow_fx()
	else:
		_hide_bow_fx()


## Dano da flecha: escala linear de BOW_MIN_DAMAGE (toque) a BOW_MAX_DAMAGE (2 s).
func _bow_damage(charge: float) -> int:
	var frac := charge / BOW_MAX_CHARGE
	return int(round(lerpf(BOW_MIN_DAMAGE, BOW_MAX_DAMAGE, frac)))


## Ao soltar: as flechas saem UMA POR VEZ, de cima pra baixo na tela, com
## BOW_VOLLEY_STEP entre elas — cada uma parte do seu arco na formação e voa focada
## na mira do mouse (recalculada por flecha, então persegue o cursor que se mexe).
func _release_bow_volley(damage: int) -> void:
	var count := mini(_arrow_count(), _bows.size())
	var cam := get_viewport().get_camera_3d()
	var pivots: Array[Node3D] = []
	for i in count:
		pivots.append(_bows[i]["pivot"])
	if cam:  # ordena de cima (menor y na tela) pra baixo
		pivots.sort_custom(func(a: Node3D, b: Node3D) -> bool: return cam.unproject_position(a.global_position).y < cam.unproject_position(b.global_position).y)
	for pivot in pivots:
		if not is_instance_valid(self):
			return
		var from := pivot.global_position
		var dir := Iso.flat_direction(from, Iso.mouse_ground_position(self))
		if dir == Vector3.ZERO:
			dir = _aim_direction()
		var arrow: MagicBolt = BOLT_SCENE.instantiate()
		arrow.is_arrow = true
		arrow.direction = dir
		arrow.damage = damage
		arrow.pierce = BOW_PIERCE
		arrow.position = from
		get_tree().current_scene.add_child(arrow)
		await get_tree().create_timer(BOW_VOLLEY_STEP).timeout


## Arco desenhado: pivô na altura do peito com os dois braços de madeira (fixos),
## a corda em "V" e a flecha encaixada (atualizados na puxada). Visto de cima.
## Um arco por flecha (nível): construídos sob demanda em _bow_formation.
func _build_bow_fx() -> void:
	_bows = []
	_bows.append(_make_bow())  # deixa um pronto (nível 1)


## Monta um arco completo (pivô + braços fixos + corda/flecha móveis) e devolve
## as referências dos segmentos que a puxada anima.
func _make_bow() -> Dictionary:
	var pivot := Node3D.new()
	pivot.visible = false
	add_child(pivot)
	_bow_limb(pivot, BOW_TIP_L, BOW_APEX)  # braços "^" estáticos
	_bow_limb(pivot, BOW_TIP_R, BOW_APEX)
	return {
		"pivot": pivot,
		"string_l": _bow_seg_node(pivot, BOW_STRING_COL),
		"string_r": _bow_seg_node(pivot, BOW_STRING_COL),
		"arrow": _bow_seg_node(pivot, BOW_ARROW_COL),
		"tip": _bow_seg_node(pivot, BOW_TIP_COL),
	}


func _bow_seg_node(parent: Node3D, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _bow_limb(parent: Node3D, from: Vector3, to: Vector3) -> void:
	_orient_segment(_bow_seg_node(parent, BOW_WOOD), from, to, 0.05)


func _hide_bow_fx() -> void:
	for bow: Dictionary in _bows:
		bow["pivot"].visible = false


## Estica um box fino entre dois pontos no plano XZ local (só gira em Y).
func _orient_segment(mi: MeshInstance3D, from: Vector3, to: Vector3, thick: float) -> void:
	var d := to - from
	var length := maxf(d.length(), 0.001)
	mi.position = (from + to) * 0.5
	mi.rotation = Vector3(0, atan2(d.x, d.z), 0)  # +Z do box aponta pra `to`
	mi.scale = Vector3(thick, thick, length)


## Posição local do arco/ícone nº i no semicírculo virado pra mira (1 = direto na
## mira; vários = leque de -span/2 a +span/2). Ponto único pros arcos E os ícones,
## pra o ícone imitar exatamente onde o arco nasce.
func _bow_slot_position(i: int, count: int, aim_ang: float) -> Vector3:
	var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
	var a := aim_ang + t * BOW_ARC_SPAN
	return Vector3(sin(a), 0.0, cos(a)) * BOW_FORMATION_RADIUS + Vector3(0, CAST_OFFSET.y, 0)


## Os N arcos ficam num semicírculo ao redor do player, sempre centrado na mira do
## mouse (a formação inteira gira pra seguir o cursor). Cada arco aponta pra mira. A
## puxada recua corda+flecha (frac) — carregam juntos; soltar dispara um a um.
func _bow_formation() -> void:
	var count := _arrow_count()
	while _bows.size() < count:  # cria arcos extras sob demanda ao subir de nível
		_bows.append(_make_bow())

	var mouse := Iso.mouse_ground_position(self)
	var aim_ang := atan2(_aim_direction().x, _aim_direction().z)
	var frac := _bow_charge_time / BOW_MAX_CHARGE
	var nock := Vector3(0, 0, lerpf(BOW_NOCK_REST, BOW_NOCK_FULL, frac))  # recua ao puxar
	var head := nock + Vector3(0, 0, BOW_ARROW_LEN)
	for i in _bows.size():
		var bow: Dictionary = _bows[i]
		var pivot: Node3D = bow["pivot"]
		if i >= count:
			pivot.visible = false
			continue
		pivot.visible = true
		pivot.position = _bow_slot_position(i, count, aim_ang)
		var to_mouse := Iso.flat_direction(pivot.global_position, mouse)
		if to_mouse != Vector3.ZERO:
			# mira presa a ±90° da direção do mouse: nunca gira mais de 180° pra apontar
			var desired := atan2(to_mouse.x, to_mouse.z)
			pivot.rotation.y = aim_ang + clampf(angle_difference(aim_ang, desired), -PI / 2.0, PI / 2.0)
		_orient_segment(bow["string_l"], BOW_TIP_L, nock, 0.02)
		_orient_segment(bow["string_r"], BOW_TIP_R, nock, 0.02)
		_orient_segment(bow["arrow"], nock, head, 0.03)
		_orient_segment(bow["tip"], head - Vector3(0, 0, 0.13), head, 0.06)


## Raio elétrico (AA do mago): segurar canaliza um arco que encadeia entre até
## BEAM_MAX_TARGETS inimigos. Cada tick (1 s) dá 20% do dano; quem leva choque
## contínuo por BEAM_SUPER_TIME s toma um superchoque de 100%. Sem cooldown.
func _update_beam(delta: float) -> void:
	if not Input.is_action_pressed("attack"):
		_beam_fx.visible = false
		_beam_muzzle.visible = false
		_beam_shock_time.clear()  # soltar o raio zera o acúmulo pro superchoque
		return
	_moving = false
	velocity = Vector3.ZERO
	var chain := _lightning_targets()
	_show_beam_fx(chain)

	_beam_tick_left -= delta
	if _beam_tick_left <= 0.0:
		_beam_tick_left += 1.0 / BEAM_DPS
		_beam_tick(chain)


## Um tick do raio (1/s): 20% do dano em cada alvo. O tempo de choque contínuo é
## somado por inimigo; ao chegar em BEAM_SUPER_TIME ele leva 100% (superchoque) e
## seu contador zera. Quem saiu do arco neste tick perde o acúmulo.
func _beam_tick(chain: Array) -> void:
	var full := _beam_damage()
	var tick_dmg := maxi(1, roundi(full * BEAM_TICK_PCT))
	var still := {}
	for enemy in chain:
		var id: int = enemy.get_instance_id()
		var t: float = float(_beam_shock_time.get(id, 0.0)) + 1.0 / BEAM_DPS
		if t >= BEAM_SUPER_TIME:
			_zap(enemy, maxi(1, roundi(full * BEAM_SUPER_PCT)), BEAM_SUPER_STUN)
			_super_shock_fx(enemy)
			t = 0.0
		else:
			_zap(enemy, tick_dmg, BEAM_STUN)
		still[id] = t
	_beam_shock_time = still


## Cadeia de alvos: o mais próximo do player (até BEAM_RANGE), depois saltos
## pro mais próximo ainda não atingido (até BEAM_BOUNCE_RANGE), no máx 3.
func _lightning_targets() -> Array:
	var chain: Array = []
	var enemies := get_tree().get_nodes_in_group("enemies")
	var from := global_position
	var reach := BEAM_RANGE
	while chain.size() < _beam_max_targets():
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


## Aplica um choque no inimigo pela Hurtbox: dano + stun conforme o tick/superchoque.
func _zap(enemy: Node, dmg: int, stun: float) -> void:
	if not (is_instance_valid(enemy) and enemy.has_node("Hurtbox")):
		return
	var hb := HitboxComponent.new()
	hb.damage = dmg
	hb.stun_duration = stun
	enemy.get_node("Hurtbox").take_hit(hb)
	hb.queue_free()


## Estouro elétrico no alvo do superchoque: clarão azul que abre e some.
func _super_shock_fx(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	var flash := Sprite3D.new()
	flash.texture = GLOW_TEX
	flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flash.pixel_size = 0.06
	flash.modulate = BEAM_COLOR
	flash.position = enemy.global_position + Vector3(0, 0.9, 0)
	get_tree().current_scene.add_child(flash)
	var tw := flash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * 2.4, 0.3) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(flash.queue_free)


## Arcos elétricos: uma line-strip com jitter por elo (player → alvo1 → alvo2…),
## redesenhada todo frame pra "tremular". Brilho na ponta do cajado sempre visível.
func _show_beam_fx(chain: Array) -> void:
	# faísca elétrica na ponta do cetro: pulso suave (sem o pisca-pisca branco).
	_beam_muzzle.visible = true
	_beam_muzzle.position = CAST_OFFSET + _aim_direction() * 0.3
	_beam_muzzle.scale = Vector3.ONE * (0.85 + 0.12 * sin(Time.get_ticks_msec() / 90.0))

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
