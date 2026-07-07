class_name HitboxComponent
extends Area2D
## Área que CAUSA dano (ataque, projétil, contato de inimigo).
## Configurar no editor: collision_mask = layer da hurtbox alvo
## (player_hurtbox ou enemy_hurtbox); layer própria = nenhuma.

@export var damage := 1
@export var knockback_force := 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		area.take_hit(self)
