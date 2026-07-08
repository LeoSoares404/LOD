# Relatório de Erros — Projeto Godot (LOD)

Godot 4.7.stable · documento gerado em 07/07/2026

Este documento explica cada categoria de erro que apareceu no Output do editor, o que provavelmente as causou e o estado atual de cada uma.

---

## 1. `Missing 'id' in external resource tag` — CORRIGIDO

**Onde aparecia:** `damage_number.tscn`, `bubble.tscn`, `fire_pillar.tscn`, `lightning_bolt.tscn`, `armor_menu.tscn`, `gems_system.tscn`, `inventory_menu.tscn`, `skills_menu.tscn`.

**Causa provável:** no formato de cena de texto do Godot 4, toda tag `[ext_resource]` é obrigada a ter um atributo `id`, e as referências no corpo da cena precisam usar esse `id` — não o caminho. Os arquivos estavam assim (formato inválido):

```
[ext_resource type="Script" path="res://scenes/fx/damage_number.gd"]
...
script = ExtResource("res://scenes/fx/damage_number.gd")
```

Isso normalmente acontece quando o `.tscn` é escrito à mão (ou por uma ferramenta/gerador externo) em vez de ser salvo pelo próprio editor do Godot, que sempre grava o `id` e o `load_steps` automaticamente. É o erro-raiz de quase toda a cascata de falhas abaixo.

**Correção aplicada:** cada arquivo passou a ter `id="1_script"` na tag e `load_steps=2` no cabeçalho, com a referência trocada para `ExtResource("1_script")`:

```
[gd_scene load_steps=2 format=3 uid="..."]

[ext_resource type="Script" path="res://scenes/fx/damage_number.gd" id="1_script"]
...
script = ExtResource("1_script")
```

---

## 2. Falhas em cascata (consequência do item 1)

Vários erros não eram problemas independentes, e sim efeito dominó da tag inválida acima. Ao corrigir o item 1, estes tendem a desaparecer:

- **`Failed loading resource: ...tscn`** — a cena não carregava porque a própria tag estava malformada.
- **`Could not preload resource file "..."`** e **`Cannot infer the type of "X" constant`** — scripts como `dash_boss.gd`, `sprinter.gd`, `ghoul.gd`, `ghoul_boss.gd` e `player.gd` fazem `const X = preload("cena.tscn")`. Se a cena não carrega, o `preload` falha e o `const` fica sem tipo, quebrando o script inteiro.
- **`Parse Error / File corrupt [Resource file ...sprinter.tscn:25]`, `dash_boss.tscn:24`, `main.tscn:38`** — quando uma cena instancia/referencia outra cena ou script que falhou ao carregar, o Godot marca a cena-pai como "corrupta". No `main.tscn`, a linha 38 é o nó `ArmorMenu` que instancia `armor_menu.tscn`; como aquela cena estava quebrada, o `main` inteiro deixava de abrir (por isso o alerta "Scene file 'main.tscn' appears to be invalid/corrupt"). Não é corrupção real de arquivo — é reflexo da dependência quebrada.

Ou seja: a maioria dos ~30 erros vinha de 8 tags mal formadas.

---

## 3. `Static function "is_key_just_pressed()" not found` — PENDENTE

**Onde aparece:** `player.gd`, `settings_menu.gd`, `skills_menu.gd`, `inventory_menu.gd`, `armor_menu.gd`, `gems_system.gd`.

**Causa provável:** o código chama `Input.is_key_just_pressed(KEY_X)`, mas essa função **não existe** na API do Godot. A classe `Input` só tem:

- `Input.is_key_pressed(key)` — verdadeiro enquanto a tecla está segurada (não detecta "acabou de apertar").
- `Input.is_action_just_pressed("acao")` — detecta o exato frame do aperto, mas trabalha com **ações** do Input Map, não com constantes `KEY_*`.

Provavelmente o código foi escrito assumindo que existia um "just pressed" para teclas cruas, misturando os dois métodos. Não corrigi automaticamente porque exige uma decisão de design: o caminho recomendado é criar ações no *Project Settings → Input Map* (ex.: `toggle_inventory`) e usar `Input.is_action_just_pressed("toggle_inventory")`. Como alternativa rápida, dá para tratar a tecla dentro de `_input(event)` verificando `event is InputEventKey and event.pressed and not event.echo`.

---

## 4. Erros extras em `gems_system.gd` — PENDENTE

- **`Cannot find member "DROP_MODE_ON_ITEM" in base "Control"`** (linha 51): a constante correta pertence à classe `Tree`, não a `Control`. Para drag-and-drop em `Control` usa-se `_can_drop_data()` / `_drop_data()`, não `drop_mode`.
- **`Function "get_global_mouse_position()" not found in base self`** (linhas 73 e 81): esse método existe em `CanvasItem` (Node2D/Control). O erro costuma ser efeito colateral do script não compilar por causa dos itens acima; vale reconferir depois que o item 3 for resolvido, e confirmar que o script realmente `extends Control`/`Node2D`.

---

## Resumo

| Categoria | Origem provável | Estado |
|---|---|---|
| `Missing 'id'` em `ext_resource` (8 cenas) | `.tscn` escrito fora do editor, sem `id` | Corrigido |
| Failed loading / preload / "file corrupt" | Cascata do item acima | Resolve junto |
| `is_key_just_pressed()` | Função inexistente na API `Input` | Pendente (decisão de design) |
| `DROP_MODE_ON_ITEM` / `get_global_mouse_position` | Uso de API de classe errada + cascata | Pendente |

**Recomendação geral:** sempre que possível, salve as cenas pelo próprio editor do Godot (ou reimporte o projeto) para que `id`, `uid` e `load_steps` sejam gravados corretamente e esse tipo de erro não volte.
