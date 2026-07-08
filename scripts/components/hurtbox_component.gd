class_name HurtboxComponent
extends Area3D
## Área que RECEBE dano. Separada do corpo físico (regra de ouro do projeto).
## Configurar no editor: collision_layer = player_hurtbox ou enemy_hurtbox,
## monitoring desligado (quem detecta é a hitbox).

signal hit_received(hitbox: HitboxComponent)

@export var health: HealthComponent


func take_hit(hitbox: HitboxComponent) -> void:
	if health:
		health.take_damage(hitbox.damage)
	hit_received.emit(hitbox)
