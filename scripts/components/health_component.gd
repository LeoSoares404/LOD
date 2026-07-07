class_name HealthComponent
extends Node
## Vida de uma entidade. Dono da regra de dano/cura/morte — ninguém altera HP
## por fora, só via take_damage/heal.

signal health_changed(current: int, max_health: int)
signal died

@export var max_health := 10

var health: int


func _ready() -> void:
	health = max_health


func take_damage(amount: int) -> void:
	if health <= 0:
		return  # já morto; ignora dano em cadáver
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()


func heal(amount: int) -> void:
	if health <= 0:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
