# LOD — Arquitetura & Decisões Antecipadas

Este documento trava as decisões que **precisam ser tomadas antes de codar/desenhar**,
porque mudá-las depois custa retrabalho em cascata. Complementa o [GAME_DESIGN.md](GAME_DESIGN.md).

---

## 1. Estrutura de pastas (já criada)

```
res://
├── project.godot           # config: pixel-art, inputs, collision layers
├── scenes/
│   ├── main.tscn           # cena raiz: carrega mundo + UI
│   ├── world/              # mapas, tilemaps, spawners
│   ├── entities/
│   │   ├── player/         # player.tscn + player.gd + estados
│   │   ├── enemies/        # enemy_base.tscn + variações (herdam a cena base)
│   │   └── projectiles/    # projéteis de skills
│   ├── ui/                 # HUD (orbes, hotbar), menus, inventário
│   └── fx/                 # partículas, flashes, decals
├── scripts/
│   ├── systems/            # autoloads: EventBus, GameState, SkillDB...
│   ├── components/         # HealthComponent, Hitbox, StateMachine...
│   └── data/               # class_name dos Resources: SkillData, ItemData...
├── assets/
│   ├── sprites/            # player/ enemies/ tiles/ ui/
│   ├── audio/              # sfx/ music/
│   └── shaders/            # .gdshader
└── data/                   # instâncias .tres: skills/ items/ enemies/
```

**Regra:** cena e script da mesma entidade ficam juntos (`player.tscn` + `player.gd` lado a lado).
`scripts/` guarda só o que não pertence a uma cena específica (sistemas, componentes, classes de dados).

---

## 2. Decisões TRAVADAS (não mudar depois de começar)

| Decisão | Valor | Por que travar agora |
|---------|-------|---------------------|
| **Resolução base** | **640×360** | Escala inteira exata p/ 720p (×2), 1080p (×3), 1440p (×4). Mudar depois quebra TODA a UI e enquadramento. |
| **Tamanho de tile** | **16×16 px** | Estilo 16-bit clássico. Toda a arte de cenário deriva disso. Mudar = redesenhar tudo. |
| **Sprite do player** | 16×24 ou 16×32 (mais alto que 1 tile) | Silhueta legível em top-down. Definir antes do primeiro sprite. |
| **Pivô dos sprites** | Base dos pés (bottom-center) | Necessário pro Y-sort funcionar (quem está "atrás" renderiza antes). |
| **Filtro de textura** | Nearest (já no project.godot) | Pixel-art nítida. |
| **Física** | Só `_physics_process` para movimento | Misturar com `_process` causa jitter. |
| **Idioma do código** | Inglês (código) / PT-BR (docs) | Padrão da indústria, facilita buscar erro no Google. |

### Collision layers (nomeadas no project.godot)

| # | Layer | Quem está nela | Colide com |
|---|-------|----------------|-----------|
| 1 | `world` | Paredes, obstáculos | todos os corpos |
| 2 | `player` | Corpo do player | world |
| 3 | `enemies` | Corpos de inimigos | world, enemies |
| 4 | `player_hurtbox` | Área que RECEBE dano no player | hitboxes inimigas |
| 5 | `enemy_hurtbox` | Área que RECEBE dano nos inimigos | hitboxes do player |
| 6 | `pickups` | Itens no chão, XP | player |

**Regra de ouro:** corpo físico (empurrar/bloquear) e hurtbox (receber dano) são SEMPRE
áreas separadas. Nunca usar o CollisionShape do corpo para dano.

### Input actions (nomeadas no project.godot)

`move_click` (botão dir. do mouse — click-to-move) · `skill_1..4` (QWER e 1-4) · `attack` (botão esq. do mouse)

O **código nunca referencia tecla física** — sempre `Input.is_action_pressed("move_up")`.
Assim, trocar o esquema de controle (ou adicionar gamepad) não toca em nenhum script.

---

## 3. Contratos entre sistemas (definir antes evita refatoração)

### EventBus (autoload) — sinais globais

```gdscript
# scripts/systems/event_bus.gd
signal enemy_died(enemy_data: EnemyData, position: Vector2)
signal player_damaged(amount: int, current_hp: int)
signal player_leveled_up(new_level: int)
signal xp_gained(amount: int)
signal item_dropped(item: ItemData, position: Vector2)
signal item_picked_up(item: ItemData)
signal skill_cast(slot: int, skill: SkillData)
signal wave_started(wave_number: int)
```

**Regra de dependência:** UI e sistemas *escutam* o EventBus; entidades *emitem*.
A HUD **nunca** pega referência direta do player (`get_node("../Player")` é proibido).

### Pipeline de stats (como itens/buffs modificam atributos)

```
stat final = (base do nível + soma dos flats dos itens) × (1 + soma dos % de itens/buffs)
```

Definir isso AGORA evita o clássico "item de +10% não funciona com o de +5 flat".
`StatsComponent` é o único dono desse cálculo; ninguém mais soma dano na mão.

### Dados são Resources (.tres), nunca hardcode

Toda skill/item/inimigo é um arquivo em `data/`. Criar conteúdo novo = criar `.tres`,
sem tocar em código. Balanceamento vira editar arquivos, não caçar números em scripts.

---

## 4. Convenções de código

- Arquivos/pastas: `snake_case` → `health_component.gd`, `enemy_ghoul.tscn`
- Classes: `PascalCase` com `class_name` → `class_name HealthComponent`
- Sinais: passado (`died`, `health_changed`), nunca imperativo
- Nodes filhos acessados com `@onready var sprite: Sprite2D = %Sprite` (unique name `%`), nunca caminhos relativos longos
- Um componente = um arquivo = uma responsabilidade
- `queue_free()` de coisas em colisão sempre via `call_deferred` quando dentro de callback de física

## 5. Planejar desde já (mesmo sem implementar)

- **Save**: formato JSON em `user://save.json` — desenhar os sistemas de forma serializável desde o início (stats, inventário e progresso como dados puros, não espalhados em nodes).
- **Pausa**: usar `get_tree().paused` + `process_mode` correto nos nodes de UI desde a primeira cena, senão vira caça-bug depois.
- **Áudio**: buses `Master / Music / SFX` criados no início (volume por categoria).
- **Paleta de cores**: escolher UMA paleta (ex. 32 cores, tipo DB32/Resurrect) antes do primeiro sprite — mistura de paletas é o que faz jogo amador parecer amador.
