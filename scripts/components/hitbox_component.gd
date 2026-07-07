class_name HitboxComponent
extends Area2D
## Área que CAUSA dano (ataque, projétil, contato de inimigo).
## Configurar no editor: collision_mask = layer da hurtbox alvo
## (player_hurtbox ou enemy_hurtbox); layer própria = nenhuma.

@export var damage := 1
@export var knockback_force := 0.0
## 0 = dano só ao encostar (projétil). > 0 = também re-aplica a cada N segundos
## enquanto encostado (contato de inimigo, aura).
@export var tick_interval := 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	if tick_interval > 0.0:
		var timer := Timer.new()
		timer.wait_time = tick_interval
		timer.autostart = true
		timer.timeout.connect(_on_tick)
		add_child(timer)


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		area.take_hit(self)


func _on_tick() -> void:
	for area in get_overlapping_areas():
		if area is HurtboxComponent:
			area.take_hit(self)
