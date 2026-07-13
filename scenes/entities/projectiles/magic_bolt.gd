class_name MagicBolt
extends HitboxComponent
## Projétil do auto-attack: herda o dano/knockback da HitboxComponent e adiciona
## voo em linha reta no plano XZ. Duas caras:
##  · orbe arcano (mago): voa meia tela e ESTOURA ao encostar em qualquer coisa
##    (inimigo, parede ou fim do alcance). O contato direto não fere — o único
##    dano do AA é o do estouro.
##  · flecha rasante (arqueiro): mais rápida, alcance maior, dano direto, nunca estoura.

const SPEED := 13.75  # m/s (era 220 px/s)
const ARROW_SPEED := 20.0  # flecha do arqueiro voa mais rápido que o orbe

## Meia tela: com fov 25° a 25 m de distância a câmera vê ~11,1 m de altura;
## no 16:9 isso dá ~19,7 m de largura, logo metade ≈ 9,9 m.
const ORB_RANGE := 9.9  # m
const ARROW_RANGE := 14.0  # m

const EXPLOSION_SCENE := preload("res://scenes/entities/projectiles/bolt_explosion.tscn")
const EXPLOSION_DAMAGE := 6  # golpe cheio do mago, entregue pelo estouro (valor padrão)

const TRAIL_STEP := 0.5  # m entre um rastro e o outro
const TRAIL_FADE := 0.28  # s até o rastro sumir

# dano-base por tick dos debuffs da zarabatana (o Player soma o bônus de nível). O
# tempo/stacks/espalhamento moram no HealthComponent do alvo (vive além do dardo).
const POISON_DAMAGE := 2
const FIRE_DAMAGE := 2
# cor por debuff: recolore o dardo e os números dos ticks (feedback do efeito).
const DEBUFF_COLORS := {
	"veneno": Color(0.5, 2.4, 0.6),    # verde tóxico
	"lentidao": Color(0.6, 1.4, 3.0),  # azul gelo
	"fogo": Color(3.0, 1.4, 0.5),      # laranja quente
}

var direction := Vector3.RIGHT
## Definidos pelo Player ANTES do add_child (o _ready lê pra montar o visual).
var is_arrow := false
var debuff := ""             # "veneno" | "lentidao" | "fogo" (dardo da zarabatana; "" = nenhum)
var poison_dmg := POISON_DAMAGE  # dano/tick do veneno (Player soma o bônus de nível)
var poison_max_stacks := 5       # limite de stacks do veneno (Player: +1 a cada 2 níveis)
var fire_dmg := FIRE_DAMAGE      # dano/tick do fogo
var pierce := 0              # nº de inimigos que a flecha atravessa antes de sumir
var explosion_scale := 1.0  # cresce por onda (só o orbe do mago)
var explosion_damage := EXPLOSION_DAMAGE  # sobrescrito pelo orbe carregado e pela luva
var explosion_tint := Color.WHITE  # cor do estouro (orbe carregado tinge por estágio)

var _speed := SPEED
var _range := ORB_RANGE
var _traveled := 0.0
var _trail_left := TRAIL_STEP
var _spent := false  # área e parede podem disparar no mesmo frame — só some uma vez


func _ready() -> void:
	super()
	body_entered.connect(func(_body: Node3D) -> void: _vanish())  # parede
	if is_arrow:
		# a base (HitboxComponent) já aplica o dano direto no area_entered
		area_entered.connect(_on_arrow_hit)
		_become_arrow()
	else:
		# orbe: contato não fere, só dispara o estouro. Desliga o dano direto da
		# base e some (estourando) ao encostar em qualquer inimigo.
		damage = 0
		area_entered.disconnect(_on_area_entered)
		area_entered.connect(func(_area: Area3D) -> void: _vanish())
		_become_orb()


## O orbe sempre estoura; a flecha nunca.
func will_explode() -> bool:
	return not is_arrow


## A base (HitboxComponent) já aplicou o dano no area_entered. Aqui decide o fim:
## com pierce sobrando, a flecha atravessa o inimigo e segue; senão, some.
func _on_arrow_hit(area: Area3D) -> void:
	if area is HurtboxComponent:
		# lentidão vai pela própria hitbox (slow_factor/duration/stacks). Veneno e
		# fogo são dano-por-tempo aplicados soltos no HealthComponent do alvo.
		# veneno/fogo: DoT preso ao HealthComponent do alvo (vive com o inimigo; o
		# dardo some no impacto). A lentidão já foi pela hitbox (slow_* + slow_stacks).
		if area.health:
			match debuff:
				"veneno": area.health.apply_poison(poison_dmg, poison_max_stacks)  # empilha até o limite
				"fogo": area.health.apply_fire(fire_dmg, true)      # 1 stack, espalha aos vizinhos
		if pierce > 0:
			pierce -= 1
			return  # atravessa: continua voando (não estoura, não some)
	_vanish()


## Orbe do mago: esfera de energia em 3 camadas — halo roxo difuso atrás, o
## núcleo do glow no meio e um coração branco-quente na frente. Pulsa (o halo
## contra-pulsa) pra dar vida, e o coração pisca pra parecer energia instável.
func _become_orb() -> void:
	var spr: Sprite3D = $Sprite

	var halo := Sprite3D.new()
	halo.texture = spr.texture
	halo.pixel_size = spr.pixel_size
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.modulate = Color(0.5, 0.1, 1.0, 0.55)
	halo.scale = spr.scale * 2.1
	add_child(halo)
	move_child(halo, 0)  # atrás do núcleo

	# coração branco-quente na frente do núcleo roxo
	var core := Sprite3D.new()
	core.texture = spr.texture
	core.pixel_size = spr.pixel_size
	core.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	core.modulate = Color(2.8, 2.3, 3.0, 1.0)
	core.scale = spr.scale * 0.5
	add_child(core)  # depois do núcleo = desenhado por cima

	var tw := create_tween().set_loops()
	tw.set_parallel(true)
	tw.tween_property(spr, "scale", spr.scale * 1.3, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "scale", halo.scale * 0.8, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(core, "scale", core.scale * 1.35, 0.18).set_trans(Tween.TRANS_SINE)
	tw.chain().set_parallel(true)
	tw.tween_property(spr, "scale", spr.scale, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "scale", halo.scale, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(core, "scale", core.scale, 0.18).set_trans(Tween.TRANS_SINE)


## Flecha: risco dourado fino, deitado no chão e apontado na direção do voo —
## bem diferente do orbe roxo redondo e billboard do mago.
func _become_arrow() -> void:
	_speed = ARROW_SPEED
	_range = ARROW_RANGE
	var spr: Sprite3D = $Sprite
	spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# euler YXZ do Godot: o X (-90°) deita o sprite, o Y depois gira no chão
	spr.rotation = Vector3(-PI / 2.0, atan2(-direction.x, -direction.z), 0.0)
	spr.scale = Vector3(0.022, 0.115, 1.0)  # fina e comprida
	spr.modulate = Color(3.0, 2.4, 0.9, 1.0)

	# ponta branca quente na frente do risco, pra dar direção e peso à flecha
	var tip := Sprite3D.new()
	tip.texture = spr.texture
	tip.pixel_size = spr.pixel_size
	tip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tip.modulate = Color(3.0, 2.9, 2.2, 1.0)
	tip.scale = Vector3(0.03, 0.03, 1.0)
	tip.position = direction * 0.7
	add_child(tip)

	var light: OmniLight3D = $Light
	light.light_color = Color(1.0, 0.85, 0.45)
	light.omni_range = 2.5

	# dardo da zarabatana: recolore a flecha pela cor do debuff que vai aplicar
	if debuff != "":
		var col: Color = DEBUFF_COLORS.get(debuff, Color.WHITE)
		spr.modulate = col
		tip.modulate = col.lightened(0.35)
		light.light_color = Color(col.r, col.g, col.b)


func _physics_process(delta: float) -> void:
	var step := _speed * delta
	position += direction * step
	_traveled += step

	_trail_left -= step
	if _trail_left <= 0.0:
		_trail_left = TRAIL_STEP
		_spawn_trail()

	if _traveled >= _range:
		_vanish()


## Fantasma do próprio sprite, encolhendo e sumindo — serve pro orbe e pra
## flecha porque copia a pose de cada um.
func _spawn_trail() -> void:
	var spr: Sprite3D = $Sprite
	var puff := Sprite3D.new()
	puff.texture = spr.texture
	puff.pixel_size = spr.pixel_size
	puff.billboard = spr.billboard
	puff.modulate = spr.modulate * Color(1, 1, 1, 0.45)
	get_tree().current_scene.add_child(puff)
	puff.global_transform = spr.global_transform

	var tw := puff.create_tween()
	tw.set_parallel(true)
	tw.tween_property(puff, "scale", spr.scale * 0.25, TRAIL_FADE)
	tw.tween_property(puff, "modulate:a", 0.0, TRAIL_FADE)
	tw.chain().tween_callback(puff.queue_free)


## Fim do voo (acertou, bateu na parede ou chegou no alcance).
func _vanish() -> void:
	if _spent:
		return
	_spent = true
	if will_explode():
		var boom: Explosion = EXPLOSION_SCENE.instantiate()
		boom.damage = explosion_damage
		boom.tint = explosion_tint
		boom.position = global_position
		boom.scale = Vector3.ONE * explosion_scale  # a onda faz o estouro crescer
		# deferido: não dá pra mexer na árvore durante o flush das colisões
		get_tree().current_scene.add_child.call_deferred(boom)
	queue_free.call_deferred()
