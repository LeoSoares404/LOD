class_name Explosion
extends HitboxComponent
## Estouro de dano em área que aparece, fere quem está no raio (via area_entered
## no próximo frame de física) e some. Reutilizável (meteoro, etc.).

@export var lifetime := 0.3
@export var grow_to := 0.42


func _ready() -> void:
	super()
	var flash: Sprite2D = $Flash
	flash.scale = Vector2(0.05, 0.05)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector2(grow_to, grow_to), lifetime)
	tw.tween_property(flash, "modulate:a", 0.0, lifetime)
	get_tree().create_timer(lifetime).timeout.connect(func() -> void: queue_free())
