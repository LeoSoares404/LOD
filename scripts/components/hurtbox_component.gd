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
		if hitbox.fire_damage > 0:
			health.apply_fire(hitbox.fire_damage, false)  # debuff "pegando fogo"
	hit_received.emit(hitbox)
