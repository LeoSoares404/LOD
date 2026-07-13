class_name HellMap
extends Node3D
## Arena do inferno (60x34 m, compatível com o WaveManager): chão carbonizado
## avermelhado, paredes escuras e poças de lava só decorativas (brilho). Tinge o
## WorldEnvironment de vermelho ao entrar. Construída em código, sem .tscn.

const MAP_W := 60.0
const MAP_H := 34.0
const WALL := 1.0
const WALL_HEIGHT := 4.0

const FLOOR_TEX := preload("res://image/chao2.jpg")
const FLOOR_TILE_WORLD := 7.5
const GLOW_TEX := preload("res://assets/sprites/props/glow_gradient.tres")

# [centro, raio] de cada poça de lava (só brilho), longe do spawn do player (30, 25)
const LAVA := [
	[Vector3(12, 0, 8), 3.0], [Vector3(48, 0, 9), 2.6],
	[Vector3(10, 0, 27), 2.8], [Vector3(50, 0, 26), 3.2],
	[Vector3(30, 0, 7), 2.4], [Vector3(22, 0, 29), 2.2],
]


func _ready() -> void:
	_add_floor()
	_add_borders()
	for l in LAVA:
		_add_lava(l[0], l[1])
	_tint_environment()


func _add_floor() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_W, MAP_H)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = FLOOR_TEX
	mat.albedo_color = Color(0.42, 0.11, 0.08)  # chão carbonizado, avermelhado
	mat.uv1_scale = Vector3(MAP_W / FLOOR_TILE_WORLD, MAP_H / FLOOR_TILE_WORLD, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	plane.material = mat
	mi.mesh = plane
	mi.position = Vector3(MAP_W / 2.0, 0.0, MAP_H / 2.0)
	add_child(mi)


func _add_borders() -> void:
	var half_h := WALL_HEIGHT / 2.0
	_add_wall(Vector3(MAP_W / 2.0, half_h, WALL / 2.0), Vector3(MAP_W, WALL_HEIGHT, WALL))
	_add_wall(Vector3(MAP_W / 2.0, half_h, MAP_H - WALL / 2.0), Vector3(MAP_W, WALL_HEIGHT, WALL))
	_add_wall(Vector3(WALL / 2.0, half_h, MAP_H / 2.0), Vector3(WALL, WALL_HEIGHT, MAP_H))
	_add_wall(Vector3(MAP_W - WALL / 2.0, half_h, MAP_H / 2.0), Vector3(WALL, WALL_HEIGHT, MAP_H))


func _add_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = center
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.06, 0.06)  # rocha escura
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)


## Poça de lava: brasa alaranjada deitada no chão + luz pulsando. Sem colisão nem
## dano — é ambientação (o perigo de fogo vem das auras dos inimigos).
func _add_lava(center: Vector3, radius: float) -> void:
	var glow := Sprite3D.new()
	glow.texture = GLOW_TEX
	glow.modulate = Color(3.0, 1.1, 0.2, 0.9)
	glow.rotation_degrees.x = -90.0
	glow.pixel_size = (radius * 2.0) / float(GLOW_TEX.get_width())
	glow.position = center + Vector3(0, 0.02, 0)
	add_child(glow)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.12)
	light.light_energy = 1.6
	light.omni_range = radius + 3.0
	light.position = center + Vector3(0, 0.6, 0)
	add_child(light)
	var tw := create_tween().set_loops()
	tw.tween_property(light, "light_energy", 2.4, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "light_energy", 1.6, 1.3).set_trans(Tween.TRANS_SINE)


## Deixa o ambiente da cena inteira vermelho-quente (o WorldEnvironment é do Main).
func _tint_environment() -> void:
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var e := we.environment
		e.background_color = Color(0.06, 0.01, 0.01)
		e.ambient_light_color = Color(1.0, 0.5, 0.32)
		e.ambient_light_energy = 1.0
