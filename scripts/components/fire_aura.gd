class_name FireAura
extends HitboxComponent
## Aura de fogo dos inimigos melee do inferno: re-aplica o debuff de "pegando fogo"
## no player enquanto ele estiver dentro do raio (75% do alcance da rapieira). Sem
## dano direto — o dano vem do DoT do próprio fogo. Adicionada em código como filha
## do inimigo (WaveManager), então carrega junto a lógica de fogo E o visual.

const RADIUS := 2.625   # 0,75 × RAPIER_RADIUS (3.5)
const TICK := 0.5       # s entre renovar o fogo em quem está dentro
const GLOW_TEX := preload("res://assets/sprites/props/glow_gradient.tres")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 8      # player_hurtbox (layer 4)
	monitoring = true
	damage = 0
	fire_damage = EnemyBolt.HELL_FIRE_DAMAGE
	tick_interval = TICK

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	shape.position.y = 0.75
	add_child(shape)

	_add_visual()
	super()  # HitboxComponent._ready: liga area_entered + timer de tick


## Brasa alaranjada no chão + luz pulsando — a "aura pequena de fogo" visível.
func _add_visual() -> void:
	var glow := Sprite3D.new()
	glow.texture = GLOW_TEX
	glow.modulate = Color(2.4, 0.8, 0.25, 0.55)
	glow.rotation_degrees.x = -90.0
	glow.pixel_size = (RADIUS * 2.0) / float(GLOW_TEX.get_width())  # cobre o diâmetro
	glow.position.y = 0.03
	add_child(glow)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.15)
	light.light_energy = 1.2
	light.omni_range = RADIUS + 1.0
	light.position.y = 0.8
	add_child(light)
	var tw := create_tween().set_loops()
	tw.tween_property(light, "light_energy", 1.9, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "light_energy", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
