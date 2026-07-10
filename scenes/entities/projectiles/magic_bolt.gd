class_name MagicBolt
extends HitboxComponent
## Projétil do auto-attack: herda o dano/knockback da HitboxComponent e adiciona
## voo em linha reta no plano XZ. Duas caras:
##  · orbe arcano (mago): voa meia tela e ESTOURA em área. Uma instância de dano
##    só — se acertar um inimigo em cheio antes, entrega metade e NÃO estoura.
##  · flecha rasante (arqueiro): mais rápida, alcance maior, nunca estoura.

const SPEED := 13.75  # m/s (era 220 px/s)
const ARROW_SPEED := 20.0  # flecha do arqueiro voa mais rápido que o orbe

## Meia tela: com fov 25° a 25 m de distância a câmera vê ~11,1 m de altura;
## no 16:9 isso dá ~19,7 m de largura, logo metade ≈ 9,9 m.
const ORB_RANGE := 9.9  # m
const ARROW_RANGE := 14.0  # m

const EXPLOSION_SCENE := preload("res://scenes/entities/projectiles/bolt_explosion.tscn")
const EXPLOSION_DAMAGE := 6  # golpe cheio do mago, entregue pelo estouro (valor padrão)
const DIRECT_HIT_RATIO := 0.5  # acerto direto (sem estourar) vale metade

const TRAIL_STEP := 0.5  # m entre um rastro e o outro
const TRAIL_FADE := 0.28  # s até o rastro sumir

# veneno (dardo da zarabatana): dano por tempo que continua mesmo com o dardo
# já desfeito — por isso os ticks rodam soltos (await), não presos ao nó.
const POISON_DAMAGE := 1
const POISON_TICKS := 3
const POISON_TICK_INTERVAL := 1.0

var direction := Vector3.RIGHT
## Definidos pelo Player ANTES do add_child (o _ready lê pra montar o visual).
var is_arrow := false
var applies_poison := false  # dardo da zarabatana
var explosion_scale := 1.0  # cresce por onda (só o orbe do mago)
var explosion_damage := EXPLOSION_DAMAGE  # sobrescrito pelo orbe carregado e pela luva

var _speed := SPEED
var _range := ORB_RANGE
var _traveled := 0.0
var _trail_left := TRAIL_STEP
var _hit_direct := false  # acertou um inimigo em cheio: o dano já saiu, não estoura
var _spent := false  # área e parede podem disparar no mesmo frame — só some uma vez


func _ready() -> void:
	super()
	# a base (HitboxComponent) já aplicou o dano no area_entered; aqui só decide o fim
	area_entered.connect(_on_direct_hit)
	body_entered.connect(func(_body: Node3D) -> void: _vanish())  # parede
	if is_arrow:
		_become_arrow()
	else:
		damage = direct_damage()
		_become_orb()


## Acerto direto do orbe: metade do estouro, nunca zero (o dano é int).
func direct_damage() -> int:
	return maxi(1, roundi(explosion_damage * DIRECT_HIT_RATIO))


## Uma instância de dano só: ou o acerto direto, ou o estouro.
func will_explode() -> bool:
	return not is_arrow and not _hit_direct


func _on_direct_hit(area: Area3D) -> void:
	_hit_direct = true
	if applies_poison and area is HurtboxComponent and area.health:
		_apply_poison(area.health)
	_vanish()


## Ticks soltos (não presos ao dardo, que já vai sumir): seguem batendo no alvo
## mesmo depois do impacto, até acabar ou o alvo morrer/sumir.
func _apply_poison(target: HealthComponent) -> void:
	for _tick in POISON_TICKS:
		await get_tree().create_timer(POISON_TICK_INTERVAL).timeout
		if is_instance_valid(target) and target.health > 0:
			target.take_damage(POISON_DAMAGE)


## Orbe do mago: núcleo pulsante com um halo escuro atrás, pra ler como esfera
## de energia e não como bolinha chapada.
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

	var tw := create_tween().set_loops()
	tw.set_parallel(true)
	tw.tween_property(spr, "scale", spr.scale * 1.3, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "scale", halo.scale * 0.8, 0.18).set_trans(Tween.TRANS_SINE)
	tw.chain().set_parallel(true)
	tw.tween_property(spr, "scale", spr.scale, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "scale", halo.scale, 0.18).set_trans(Tween.TRANS_SINE)


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
		boom.position = global_position
		boom.scale = Vector3.ONE * explosion_scale  # a onda faz o estouro crescer
		# deferido: não dá pra mexer na árvore durante o flush das colisões
		get_tree().current_scene.add_child.call_deferred(boom)
	queue_free.call_deferred()
