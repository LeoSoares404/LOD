class_name Explosion
extends HitboxComponent
## Estouro de dano em área que aparece, fere quem está no raio (via area_entered
## no próximo frame de física) e some. Reutilizável (meteoro, etc.).
##
## Burst em camadas: clarão chapado no chão + núcleo branco-quente billboard +
## anel de choque que abre pra fora + flare da luz. Tudo dentro de `lifetime`
## (a janela de dano não muda), reusando a textura de glow do $Flash.

@export var lifetime := 0.3
@export var grow_to := 0.42
var tint := Color.WHITE  # multiplica o flash/luz (orbe carregado tinge por estágio)


func _ready() -> void:
	super()
	var flash: Sprite3D = $Flash
	var col := Color(tint.r, tint.g, tint.b, 1.0)  # só clareia/esquenta: ignora o alfa
	flash.modulate *= col
	$Light.light_color *= tint

	# 1) clarão no chão: dispara rápido (ease-out) e some no fim
	flash.scale = Vector3(0.05, 0.05, 0.05)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3(grow_to, grow_to, grow_to), lifetime) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, lifetime).set_delay(lifetime * 0.3)

	_burst_core(flash.texture, col)
	_shockwave(col)
	_flare_light()

	get_tree().create_timer(lifetime).timeout.connect(func() -> void: queue_free())


## Núcleo branco-quente billboard: um pop claro no centro que estoura e some
## antes do clarão do chão — dá o "flash" do impacto.
func _burst_core(tex: Texture2D, col: Color) -> void:
	var core := Sprite3D.new()
	core.texture = tex
	core.pixel_size = 0.0625
	core.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	core.modulate = Color(col.r + 1.2, col.g + 1.0, col.b + 1.2, 1.0)  # bem quente
	core.position = Vector3(0, 0.75, 0)
	core.scale = Vector3(0.05, 0.05, 0.05)
	add_child(core)
	var tw := core.create_tween()
	tw.set_parallel(true)
	tw.tween_property(core, "scale", Vector3(0.3, 0.3, 0.3), lifetime * 0.55) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(core, "modulate:a", 0.0, lifetime * 0.85)


## Anel de choque deitado no chão que abre pra fora, no raio do estouro.
## TorusMesh já nasce no plano XZ (sem rotação = deitado).
func _shockwave(col: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(col.r, col.g, col.b, 0.85)

	var ring := TorusMesh.new()
	ring.outer_radius = 1.8       # casa com o raio de dano do estouro
	ring.inner_radius = 1.52      # anel fino

	var mi := MeshInstance3D.new()
	mi.mesh = ring
	mi.material_override = mat
	mi.position = Vector3(0, 0.06, 0)
	mi.scale = Vector3.ONE * 0.15  # nasce compacto no centro
	add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE, lifetime) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, lifetime).set_delay(lifetime * 0.35)


## Luz: dá um flare forte no impacto e decai até apagar.
func _flare_light() -> void:
	var light: OmniLight3D = $Light
	light.light_energy *= 1.9
	create_tween().tween_property(light, "light_energy", 0.0, lifetime) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
