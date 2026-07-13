extends Node
## Estado global (autoload "GameState"): run atual, classe do personagem e
## configuração. A classe escolhida na tela inicial fica aqui (base do
## personagem salvo do multiplayer, que vem depois).

var current_wave: int = 0
var control_scheme: String = "mouse"  # "mouse" (click-to-move) ou "wasd"
var hell_active := false  # fase do inferno: EnemyBolt passa a aplicar "pegando fogo"

# nível do personagem: sobe ganhando XP ao matar inimigos e faz as armas
# escalarem (ver Player._upgrade_level). Persiste ao voltar ao menu — só a fase
# (WaveManager.current_wave) reseta ao recarregar a cena.
var level: int = 1
var xp: int = 0


func xp_to_next() -> int:
	return 4 + level * 2  # 6, 8, 10, ... por nível


## Concede XP e sobe de nível quantas vezes o total permitir. Emite os sinais
## que a HUD escuta (xp_gained sempre; player_leveled_up só se subiu).
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		EventBus.player_leveled_up.emit(level)  # um sinal (e um VFX) por nível
	EventBus.xp_gained.emit(amount)

var selected_class: String = "mago"
var equipped_weapon: String = ""  # "" = auto-attack padrão da classe; senão "pistola"/"zarabatana"

# Classes jogáveis e seus atributos (escala comparável p/ as barrinhas da UI).
const CLASSES := {
	"mago": {
		"nome": "Mago",
		"desc": "Conjura magias à distância. Muita mana, pouca vida.",
		"vida": 20, "mana": 40, "dano": 8, "velocidade": 5,
	},
	"arqueiro": {
		"nome": "Arqueiro",
		"desc": "Ágil e preciso. Ataques rápidos à distância.",
		"vida": 28, "mana": 20, "dano": 6, "velocidade": 8,
	},
	"lutador": {
		"nome": "Lutador",
		"desc": "Corpo a corpo resistente. Muita vida e dano.",
		"vida": 45, "mana": 10, "dano": 11, "velocidade": 5,
	},
}

# arma inicial de cada classe — nasce no slot de arma. weapon_id "" = o
# auto-attack padrão da classe (a presença da chave é o que marca "isto é arma").
const WEAPONS := {
	"mago": {"name": "Cajado Arcano", "icon": "⚡", "weapon_id": ""},
	"arqueiro": {"name": "Arco Curto", "icon": "🏹", "weapon_id": ""},
	"lutador": {"name": "Espada Longa", "icon": "🗡", "weapon_id": ""},
}

# armas dropadas por inimigos (WaveManager) — "weapon_id" é o que o Player lê
# pra trocar o auto-attack (ver EventBus.item_picked_up).
const WEAPON_ITEMS := {
	"pistola": {"name": "Pistola", "icon": "🔫", "weapon_id": "pistola"},
	"zarabatana": {"name": "Zarabatana", "icon": "💉", "weapon_id": "zarabatana"},
	"orbe": {"name": "Orbe Carregável", "icon": "🔮", "weapon_id": "orbe"},
	"luva": {"name": "Luva Arcana", "icon": "🧤", "weapon_id": "luva"},
	"martelo": {"name": "Bastão", "icon": "🏏", "weapon_id": "martelo"},
	"rapiera": {"name": "Rapieira", "icon": "🤺", "weapon_id": "rapiera"},
}

# os 2 primeiros inimigos mortos da run largam uma arma nova, nesta ordem —
# varia por classe (mago ganha orbe/luva; as outras, pistola/zarabatana).
const RANGED_WEAPON_DROPS_BY_CLASS := {
	"mago": ["orbe", "luva"],
	"lutador": ["martelo", "rapiera"],
}
const DEFAULT_RANGED_WEAPON_DROPS := ["pistola", "zarabatana"]


func ranged_weapon_drops() -> Array:
	return RANGED_WEAPON_DROPS_BY_CLASS.get(selected_class, DEFAULT_RANGED_WEAPON_DROPS)

# máximos p/ normalizar as barras de atributo (0..1)
const ATTR_MAX := {"vida": 45.0, "mana": 40.0, "dano": 11.0, "velocidade": 8.0}
const ATTR_ORDER := ["vida", "mana", "dano", "velocidade"]
const ATTR_LABEL := {"vida": "Vida", "mana": "Mana", "dano": "Dano", "velocidade": "Veloc."}


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
