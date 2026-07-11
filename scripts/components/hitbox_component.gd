class_name HitboxComponent
extends Area3D
## Área que CAUSA dano (ataque, projétil, contato de inimigo).
## Configurar no editor: collision_mask = layer da hurtbox alvo
## (player_hurtbox ou enemy_hurtbox); layer própria = nenhuma.

@export var damage := 1
@export var knockback_force := 0.0
@export var stun_duration := 0.0  # s de atordoamento aplicado ao alvo (0 = nenhum)
@export var slow_factor := 0.0     # fração de velocidade removida do alvo (0.2 = 20% + lento)
@export var slow_duration := 0.0   # s que o slow dura; re-aplicar renova, não acumula
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


func _on_area_entered(area: Area3D) -> void:
	if area is HurtboxComponent:
		area.take_hit(self)


func _on_tick() -> void:
	for area in get_overlapping_areas():
		if area is HurtboxComponent:
			area.take_hit(self)
