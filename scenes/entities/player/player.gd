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
const ATTACK_COOLDOWN := {
	"mago": MAGE_ATTACK_CD,
	"arqueiro": MAGE_ATTACK_CD * 0.5,  # 2x mais rápido
	"lutador": MAGE_ATTACK_CD * 2.0,   # 2x mais lento — golpe pesado em arco
}

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

var _poison_zones := 0        # quantas poças estão tocando o player
var _poison_left := 0.0       # tempo restante do debuff de veneno
var _poison_tick := 0.0
var _poison_icon: Sprite3D

var _last_health := 0  # p/ virar dano em popup, venha de onde vier

# billboard HD: animação por código (bob de respirar/andar), sem spritesheet
const IDLE_BOB_SPEED := 2.6
const WALK_BOB_SPEED := 7.0
const IDLE_BOB_AMP := 0.025
const WALK_BOB_AMP := 0.05

var _anim_time := 0.0
var _base_spr_y := 0.0

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
	_base_spr_y = _sprite.position.y
	_last_health = health.health
	_build_poison_icon()
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

	for i in 4:
		if _skill_key_pressed(i) and _can_cast(i):
			_cast(i)

	if Input.is_action_pressed("attack") and _attack_cd <= 0.0:
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
	if absf(velocity.x) > 0.05:
		_sprite.flip_h = velocity.x < 0  # espelha pra encarar o lado do movimento
	_anim_time += delta
	var bob_speed := WALK_BOB_SPEED if walking else IDLE_BOB_SPEED
	var bob_amp := WALK_BOB_AMP if walking else IDLE_BOB_AMP
	_sprite.position.y = _base_spr_y + absf(sin(_anim_time * bob_speed)) * bob_amp


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


func _auto_attack() -> void:
	_attack_cd = ATTACK_COOLDOWN.get(GameState.selected_class, MAGE_ATTACK_CD)
	_moving = false
	velocity = Vector3.ZERO

	var dir := Iso.flat_direction(global_position, Iso.mouse_ground_position(self))
	if dir == Vector3.ZERO:
		dir = Vector3.FORWARD  # mouse exatamente em cima do player

	match GameState.selected_class:
		"lutador": _melee_attack(dir)
		"arqueiro": _arrow_volley(dir)
		_: _orb_attack(dir)


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
	_squash()
	match slot:
		0: _cast_lightning()
		1: _cast_bubble()
		2: _cast_pillar()
		3: _cast_super()


func _squash() -> void:
	# "tranco" ao conjurar (relativo à escala base do sprite)
	_sprite.scale = Vector3(1.12, 0.9, 1.0)
	create_tween().tween_property(_sprite, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)


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
