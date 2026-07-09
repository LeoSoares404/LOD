extends Node
## Estado global (autoload "GameState"): run atual, classe do personagem e
## configuração. A classe escolhida na tela inicial fica aqui (base do
## personagem salvo do multiplayer, que vem depois).

var current_wave: int = 0
var control_scheme: String = "mouse"  # "mouse" (click-to-move) ou "wasd"

var selected_class: String = "mago"

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

# arma inicial de cada classe — nasce equipada no inventário
const WEAPONS := {
	"mago": {"name": "Cajado Arcano", "icon": "🪄"},
	"arqueiro": {"name": "Arco Curto", "icon": "🏹"},
	"lutador": {"name": "Espada Longa", "icon": "🗡"},
}

# máximos p/ normalizar as barras de atributo (0..1)
const ATTR_MAX := {"vida": 45.0, "mana": 40.0, "dano": 11.0, "velocidade": 8.0}
const ATTR_ORDER := ["vida", "mana", "dano", "velocidade"]
const ATTR_LABEL := {"vida": "Vida", "mana": "Mana", "dano": "Dano", "velocidade": "Veloc."}


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
