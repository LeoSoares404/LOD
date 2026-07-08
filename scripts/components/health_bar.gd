class_name HealthBar
extends Node3D
## Barra de vida flutuante 3D. Dois quads sem sombreamento, inclinados no
## mesmo pitch da câmera fixa (Iso.CAM_PITCH) — sempre legíveis, sem billboard
## por eixo (que desalinha o preenchimento). Aparece só com vida incompleta.

@export var health: HealthComponent
@export var width := 1.0   # m (16 px da arte = 1 m)
@export var height := 0.12

var _fill: MeshInstance3D


func _ready() -> void:
	visible = false
	rotation_degrees.x = Iso.CAM_PITCH  # encara a câmera fixa
	_make_quad(Color(0.05, 0.08, 0.09, 0.85), 0.0)
	_fill = _make_quad(Color(0.78, 0.16, 0.18), 0.01)
	health.health_changed.connect(_on_health_changed)


func _make_quad(color: Color, z_offset: float) -> MeshInstance3D:
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
	mi.scale = Vector3(width, height, 1.0)
	mi.position.z = z_offset
	add_child(mi)
	return mi


func _on_health_changed(current: int, max_health: int) -> void:
	var ratio := float(current) / float(max_health)
	visible = ratio < 1.0
	_fill.scale = Vector3(maxf(width * ratio, 0.001), height, 1.0)
	_fill.position.x = -width / 2.0 + (width * ratio) / 2.0
