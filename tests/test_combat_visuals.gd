extends Node
## Check dos visuais de combate. Roda como cena (precisa dos autoloads e da
## árvore montada para o _ready dos projéteis e o global_transform):
##   godot --headless --path . res://tests/test_combat_visuals.tscn
## Sai com código 1 se algo quebrar.

const BOLT := preload("res://scenes/entities/projectiles/magic_bolt.tscn")
const SWAMP := preload("res://scenes/world/swamp_map.tscn")

var _failures := 0


func _ready() -> void:
	_test_arrow_aims_at_direction()
	_test_orb_stays_billboard()
	_test_pool_image_is_pixel_blob()

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

	var palette: Array = swamp.POOL_PALETTE + [swamp.POOL_BUBBLE]
	var off_palette := 0
	for y in size:
		for x in size:
			var px := img.get_pixel(x, y)
			if px.a > 0.01 and not px in palette:
				off_palette += 1
	_check(off_palette == 0, "%d pixels fora da paleta 16 bits" % off_palette)

	_check(img.get_data() != swamp._pool_image(999).get_data(), "poças saíram idênticas")
	swamp.free()
