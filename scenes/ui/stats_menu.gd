extends CanvasLayer
## Ficha do personagem: segure CTRL para ver, solte para fechar. Só lê o
## GameState (autoload) — nunca referencia player/entidades (ARCHITECTURE.md).
## Mostra classe, nível/XP, atributos base e a arma equipada.

@onready var panel: Control = $Panel
@onready var title: Label = %Title
@onready var body: Label = %Body


func _ready() -> void:
	panel.visible = false


## Alt esquerdo/direito compartilham o mesmo keycode. Mostra enquanto segura.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo \
			and event.physical_keycode == KEY_ALT:
		panel.visible = event.pressed
		if event.pressed:
			_refresh()


func _refresh() -> void:
	var cls: Dictionary = GameState.CLASSES.get(GameState.selected_class, {})
	title.text = "%s — Nível %d" % [cls.get("nome", "?"), GameState.level]

	var lines := ["XP: %d / %d" % [GameState.xp, GameState.xp_to_next()], ""]
	for attr: String in GameState.ATTR_ORDER:
		lines.append("%s: %d" % [GameState.ATTR_LABEL[attr], cls.get(attr, 0)])
	lines.append("")
	lines.append("Arma: %s" % _weapon_name())
	body.text = "\n".join(lines)


func _weapon_name() -> String:
	if GameState.equipped_weapon == "":
		return GameState.WEAPONS.get(GameState.selected_class, {}).get("name", "—")
	return GameState.WEAPON_ITEMS.get(GameState.equipped_weapon, {}).get("name", "—")
