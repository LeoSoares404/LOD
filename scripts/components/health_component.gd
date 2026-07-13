class_name HealthComponent
extends Node
## Vida + status de dano-por-tempo (veneno/fogo). Dono da regra de dano/cura/morte —
## ninguém altera HP por fora, só via take_damage/heal/apply_poison/apply_fire.
## Os status ficam AQUI (vivem junto do inimigo) e tickam no _process — o dardo da
## zarabatana some no impacto, então prender o DoT a ele perdia os ticks.

signal health_changed(current: int, max_health: int)
signal died

const DOT_NUMBER_SCENE := preload("res://scenes/fx/damage_number.tscn")

# veneno: empilha até POISON_MAX_STACKS; dano/tick = dano-base × pilha.
const POISON_MAX_STACKS := 5
const POISON_TICK_INTERVAL := 1.0
const POISON_DURATION := 5.0
const POISON_COLOR := Color(0.5, 2.4, 0.6)

# fogo: 1 stack só (re-aplicar renova, não empilha); se espalha aos vizinhos.
const FIRE_TICK_INTERVAL := 0.5
const FIRE_DURATION := 2.5
const FIRE_COLOR := Color(3.0, 1.4, 0.5)
const FIRE_SPREAD_RADIUS := 3.5

@export var max_health := 10

var health: int

var _poison_stacks := 0
var _poison_per_stack := 0
var _poison_time := 0.0
var _poison_tick := 0.0

var _fire_time := 0.0
var _fire_tick := 0.0
var _fire_dmg := 0
var _fire_icon: Label3D   # "🔥" sobre o inimigo enquanto queima


func _ready() -> void:
	health = max_health


func _process(delta: float) -> void:
	_tick_poison(delta)
	_tick_fire(delta)


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


## Veneno (zarabatana): +1 stack até `max_stacks` (base POISON_MAX_STACKS, +1 a cada
## 2 níveis via Player) e renova a duração. O dano por tick escala com a pilha.
func apply_poison(dmg_per_stack: int, max_stacks: int) -> void:
	if _poison_stacks == 0:
		_poison_tick = POISON_TICK_INTERVAL
	_poison_stacks = mini(_poison_stacks + 1, maxi(max_stacks, POISON_MAX_STACKS))
	_poison_per_stack = dmg_per_stack
	_poison_time = POISON_DURATION


## Fogo (zarabatana): 1 stack só — renova, não empilha. Com `spread`, pega os
## inimigos próximos junto (eles NÃO re-espalham, senão viraria reação em cadeia).
func apply_fire(dmg: int, spread: bool) -> void:
	if _fire_time <= 0.0:
		_fire_tick = FIRE_TICK_INTERVAL
	_fire_dmg = dmg
	_fire_time = FIRE_DURATION
	if spread:
		_spread_fire(dmg)


func _spread_fire(dmg: int) -> void:
	var host := get_parent()
	if not (host is Node3D):
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == host or not is_instance_valid(e):
			continue
		if host.global_position.distance_to(e.global_position) > FIRE_SPREAD_RADIUS:
			continue
		var hc: HealthComponent = e.get_node_or_null("HealthComponent")
		if hc:
			hc.apply_fire(dmg, false)


func _tick_poison(delta: float) -> void:
	if _poison_stacks <= 0:
		return
	_poison_time -= delta
	if _poison_time <= 0.0:
		_poison_stacks = 0
		return
	_poison_tick -= delta
	if _poison_tick <= 0.0:
		_poison_tick = POISON_TICK_INTERVAL
		var dmg := _poison_per_stack * _poison_stacks
		take_damage(dmg)
		_dot_number(dmg, POISON_COLOR)


func _tick_fire(delta: float) -> void:
	if _fire_time <= 0.0:
		if _fire_icon:
			_fire_icon.visible = false
		return
	_fire_time -= delta
	_fire_tick -= delta
	if _fire_tick <= 0.0:
		_fire_tick = FIRE_TICK_INTERVAL
		take_damage(_fire_dmg)
		_dot_number(_fire_dmg, FIRE_COLOR)
	_show_fire_icon()


## "🔥" flutuando (pulsando) sobre o inimigo enquanto queima — a UI de "pegando fogo".
func _show_fire_icon() -> void:
	var host := get_parent()
	if not (host is Node3D):
		return
	if _fire_icon == null:
		_fire_icon = Label3D.new()
		_fire_icon.text = "🔥"
		_fire_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_fire_icon.no_depth_test = true
		_fire_icon.font_size = 40
		_fire_icon.pixel_size = 0.006
		_fire_icon.position = Vector3(0, 2.05, 0)
		host.add_child(_fire_icon)
		var tw := _fire_icon.create_tween().set_loops()
		tw.tween_property(_fire_icon, "scale", Vector3.ONE * 1.25, 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_fire_icon, "scale", Vector3.ONE * 0.85, 0.22).set_trans(Tween.TRANS_SINE)
	_fire_icon.visible = true


func _dot_number(dmg: int, tint: Color) -> void:
	var host := get_parent()
	if not (host is Node3D):
		return
	var n: Label3D = DOT_NUMBER_SCENE.instantiate()
	n.text = "-%d" % dmg
	n.modulate = tint
	n.position = host.global_position + Vector3(randf_range(-0.5, 0.5), 1.9, 0.0)
	get_tree().current_scene.add_child(n)
