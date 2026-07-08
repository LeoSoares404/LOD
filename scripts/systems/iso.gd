class_name Iso
## Utilidades do modo 2.5D (mundo 3D no plano XZ, câmera isométrica fixa).
## Convenção: 16 px da arte original = 1 m de mundo (PPM).

const PPM := 16.0
const CAM_PITCH := -55.0  # inclinação da câmera (graus) — compartilhada por rig e barras de vida


## Projeta o cursor do mouse no plano do chão (y = 0). Substitui o
## get_global_mouse_position() do 2D.
static func mouse_ground_position(node: Node3D) -> Vector3:
	var vp := node.get_viewport()
	var cam := vp.get_camera_3d()
	if cam == null:
		return node.global_position
	var mouse := vp.get_mouse_position()
	var origin := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return node.global_position
	var t := -origin.y / dir.y
	return origin + dir * t


## Distância horizontal (ignora Y) — útil para alcance de skills/IA.
static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


## Direção horizontal normalizada de a para b (y = 0).
static func flat_direction(a: Vector3, b: Vector3) -> Vector3:
	var d := b - a
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3.ZERO
