extends Node
## Hub global de sinais (autoload "EventBus").
## Regra: entidades EMITEM, UI e sistemas ESCUTAM. Ninguém referencia entidade direto.

signal enemy_died(enemy_data: Resource, position: Vector3)
signal player_damaged(amount: int, current_hp: int)
signal player_health_changed(current: int, max_health: int)
signal player_mana_changed(current: int, max_mana: int)
signal skill_cooldown_started(slot: int, duration: float)
signal player_leveled_up(new_level: int)
signal xp_gained(amount: int)
signal item_dropped(item: Variant, position: Vector3)  # item: Dictionary
signal item_picked_up(item: Variant)  # item: Dictionary
signal skill_cast(slot: int, skill: Resource)
signal wave_started(wave_number: int, is_boss: bool)
signal victory
