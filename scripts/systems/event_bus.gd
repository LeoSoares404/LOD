extends Node
## Hub global de sinais (autoload "EventBus").
## Regra: entidades EMITEM, UI e sistemas ESCUTAM. Ninguém referencia entidade direto.

signal enemy_died(enemy_data: Resource, position: Vector2)
signal player_damaged(amount: int, current_hp: int)
signal player_leveled_up(new_level: int)
signal xp_gained(amount: int)
signal item_dropped(item: Resource, position: Vector2)
signal item_picked_up(item: Resource)
signal skill_cast(slot: int, skill: Resource)
signal wave_started(wave_number: int)
