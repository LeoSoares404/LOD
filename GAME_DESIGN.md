# LOD — Plano de Desenvolvimento

**Gênero:** ARPG top-down pixel-art (mistura de Diablo + League of Legends)
**Engine:** Godot 4.x (renderizador Forward+ ou Mobile)
**Linguagem:** GDScript (com opção de C# para hot-paths se necessário)
**Estilo visual:** Pixel-art 16-bit, câmera top-down, glow/bloom para magias

---

## 1. Pilares de design

| Pilar | Referência | O que significa |
|-------|-----------|-----------------|
| Combate de habilidades | League of Legends | Hotbar de skills com cooldown + custo de mana, mira/alvo, combos |
| Loot & progressão | Diablo | Itens caem no chão, raridades, equipamento, XP e níveis |
| Hordas | Diablo/Survivors | Ondas de inimigos (ex: "Ghoul Swarm") escalando em dificuldade |
| Fantasia sombria | Diablo | Cripta/santuário, demônios, atmosfera com iluminação dramática |

---

## 2. Arquitetura técnica (Godot)

### Estrutura de pastas
```
res://
├── scenes/
│   ├── main.tscn              # cena raiz / bootstrap
│   ├── world/                 # mapas, tilemaps, câmera
│   ├── entities/
│   │   ├── player/            # Player.tscn + Player.gd
│   │   ├── enemies/           # Enemy base + variações (ghoul, imp)
│   │   └── projectiles/
│   ├── ui/                    # HUD, hotbar, orbes, inventário
│   └── fx/                    # partículas, hit flashes, luzes
├── scripts/
│   ├── systems/               # autoloads (singletons)
│   ├── data/                  # Resources: SkillData, ItemData, EnemyData
│   └── components/            # HealthComponent, HitboxComponent, etc.
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── shaders/
└── data/                      # arquivos .tres de skills, itens, inimigos
```

### Autoloads (singletons)
- `GameState` — pausa, run atual, wave counter.
- `EventBus` — sinais globais (desacoplamento): `enemy_died`, `player_leveled_up`, `item_picked_up`.
- `SkillDB` / `ItemDB` — carregam os Resources de dados.
- `AudioManager` — SFX e música.

### Padrão de composição (chave para escalar)
Usar **componentes reutilizáveis** como Nodes filhos em vez de herança pesada:
- `HealthComponent` — hp, dano, morte, sinal `died`.
- `HitboxComponent` / `HurtboxComponent` — Area2D para dano.
- `StatsComponent` — atributos (força, vida, velocidade) somando itens.
- `StateMachine` — estados (idle, move, attack, cast, dead) para player e inimigos.

### Dados como Resources (`.tres`)
Cada skill/item/inimigo é um `Resource` editável no inspector:
```gdscript
class_name SkillData extends Resource
@export var name: String
@export var icon: Texture2D
@export var cooldown: float
@export var mana_cost: int
@export var damage: int
@export var projectile_scene: PackedScene
@export var cast_type: int  # projectile / aoe / self / dash
```
Isso deixa criar 50 skills/itens sem escrever 50 scripts.

---

## 3. Sistemas — ordem de implementação (milestones)

### M0 — Fundação (prototype jogável)
- [ ] Projeto Godot + estrutura de pastas + autoloads vazios.
- [ ] TileMap de um mapa de teste.
- [x] Player (`CharacterBody2D`) com movimento.
  - ✅ DECIDIDO: **click-to-move no botão direito** (Diablo/LoL) — segurar segue o cursor. Teclas ficam reservadas para skills (QWER + 1-4). Por ora movimento direto ao ponto (`move_and_slide` desliza nos obstáculos); `NavigationAgent2D` (desvio de obstáculos) entra junto com o pathfinding dos inimigos no M1.
- [ ] `Camera2D` seguindo o player com smoothing + limites.

### M1 — Combate base
- [ ] `HealthComponent` + `Hurtbox`/`Hitbox`.
- [ ] StateMachine do player.
- [ ] 1 skill funcional: projétil com cooldown e custo de mana.
- [ ] 1 inimigo (`Ghoul`) que persegue o player (`NavigationAgent2D`) e ataca por contato.
- [ ] Dano, knockback, hit-flash (shader), morte.

### M2 — HUD (as orbes e a hotbar do screenshot)
- [ ] Orbe de vida (vermelha) e mana (azul) — shader de preenchimento.
- [ ] Hotbar com 6+ slots de skill, ícones, overlay de cooldown radial.
- [ ] Barra de XP + indicador de nível.
- [ ] Barras de vida flutuantes sobre inimigos ("GHOUL SWARM", "DEMON IMP").

### M3 — Progressão & spawning
- [ ] XP ao matar, level-up, escala de atributos.
- [ ] Spawner de ondas (waves) com dificuldade crescente.
- [ ] Segundo tipo de inimigo (Demon Imp — ranged/voador).
- [ ] Sistema de múltiplas skills equipadas + troca.

### M4 — Loot & inventário
- [ ] Drop de itens no chão com pickup.
- [ ] `ItemData` com raridades (comum/raro/épico/lendário) e cor.
- [ ] Inventário + equipamento afetando `StatsComponent`.
- [ ] Geração de atributos aleatórios (affixes) estilo Diablo.

### M5 — Polish visual (o "efeito" que você quer)
- [ ] WorldEnvironment com **Glow/Bloom** para magias e itens brilharem.
- [ ] `PointLight2D` no player, projéteis e tochas (iluminação dinâmica).
- [ ] `GPUParticles2D`: rastros de magia, sangue, poeira, explosões.
- [ ] Shaders: dissolve na morte, outline em hover, hit-flash branco.
- [ ] Screen shake, hit-stop (freeze frame no impacto), damage numbers.
- [ ] Normal maps nos sprites para reagir às luzes.

### M6 — Conteúdo & meta
- [ ] Árvore de talentos / runas.
- [ ] Múltiplos mapas / andares (procedural opcional).
- [ ] Boss.
- [ ] Menu, save/load, áudio completo.

---

## 4. O visual bonito — como conseguir (técnico)

O "glow" do screenshot vem de 3 camadas combinadas:

1. **HDR + Glow** no `WorldEnvironment`:
   - `glow_enabled = true`, `glow_bloom`, `glow_hdr_threshold` baixo.
   - Sprites de magia com cores acima de 1.0 (HDR) "estouram" em brilho.
2. **Luzes 2D** (`PointLight2D`) com texturas de gradiente radial + normal maps nos tiles/sprites → profundidade e sombra dinâmica.
3. **Partículas + shaders** para movimento e impacto (game feel).

Regra de ouro do "game juice": **todo hit precisa de** flash + partícula + som + shake + knockback. É isso que faz parecer AAA mesmo em pixel-art.

---

## 5. Assets & ferramentas

- **Pixel-art:** Aseprite (pago, padrão) ou LibreSprite/Piskel (grátis).
- **Assets prototype:** itch.io, Kenney.nl (top-down packs gratuitos) para não travar no desenho.
- **Áudio:** freesound.org, sfxr/jsfxr para SFX retrô.
- **Tiles:** Tiled ou o TileMap nativo do Godot 4.

---

## 6. Mundo — mapa grande de exploração

✅ DECIDIDO: o mundo é um **mapa grande contínuo de exploração, com várias zonas**
(ex.: cripta, floresta sombria, ruínas...), não fases separadas.

- A **cripta atual é a primeira zona** / protótipo — o layout dela vai crescer.
- Cada zona tem paleta e tiles próprios, mas todas no mesmo TileMap/mundo.
- Implicações técnicas (tratar quando o mapa crescer, não antes):
  - Limites da câmera devem vir do mapa, não fixos no player.
  - Spawners de inimigos por zona (waves locais, não globais).
  - Se a performance sentir, pintar tiles por chunk conforme o player anda.

## 7. Riscos / decisões em aberto

- **Controle:** ✅ decidido em M0 — click-to-move (botão direito) + skills nas teclas QWER/1-4.
- **Netcode:** singleplayer primeiro. Multiplayer (LoL-like) é 10x o trabalho — deixar como fase futura, mas já desacoplar via `EventBus`.
- **Escopo:** ARPG é gênero grande. Meta realista do primeiro marco: **um mapa, um player, 2 inimigos, 3 skills, loot básico** = vertical slice jogável.
