class_name ArcaneNova
extends HitboxComponent
## Nova Arcana (W): dano em área ao redor do lançador. Vive brevemente — tempo
## suficiente para o area_entered pegar todos os inimigos no raio — com um anel
## de choque que expande e some.

const LIFETIME := 0.28


func _ready() -> void:
	super()
	var ring: Sprite2D = $Ring
	ring.scale = Vector2(0.05, 0.05)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(0.55, 0.55), LIFETIME)
	tw.tween_property(ring, "modulate:a", 0.0, LIFETIME)
	get_tree().create_timer(LIFETIME).timeout.connect(func() -> void: queue_free())
