# LOD — Checklist de Trabalho

Base: versão **2.5D / 3D** do Felipe (merge `4c86233`) + reforma de UI e tela inicial (08/07/2026).
Tema: **dark fantasy, paleta saturada** (o ciano é só o tema da cripta atual; virão criptas de fogo/terra/veneno). UI = **pixel-art + fonte 8-bit + molduras bronze/dourado**, neutra pra qualquer cripta.

Legenda: ✅ pronto · 🟡 parcial/placeholder · 🔴 não conectado ou com bug · 💡 ideia futura

---

## 1. Motor / Base 3D
- [x] ✅ Conversão para 2.5D real (`Node3D` / `CharacterBody3D` / `Sprite3D` billboard)
- [x] ✅ Câmera isométrica com rig e suavização (`camera_rig.gd`, `Iso.CAM_PITCH = -55°`)
- [x] ✅ Utilidades ISO (`iso.gd`): mouse→chão, distância/direção no plano XZ, 16px = 1m
- [x] ✅ Movimento click-to-move **e** WASD (alterna por `GameState.control_scheme`)
- [x] ✅ Luz direcional + sombras
- [ ] 🟡 **Câmera:** doc diz que virou perspectiva (fov ~25), mas o comentário do rig fala "ortográfica" — conferir no jogo e fazer o ajuste fino de ângulo/distância/pitch (o próprio `Estado do Projeto.md` pede isso)
- [ ] 🟡 **Chão** é um `PlaneMesh` totalmente plano — sem relevo de terreno
- [ ] 🟡 **Paredes** são `BoxMesh` de cor sólida (placeholder) — falta textura de pedra

## 2. Combate & Skills
- [x] ✅ 4 skills novas: **Q Raio** (ricocheteia até 3x), **W Bolha** (atordoa em área), **E Pilar de Fogo** (dano contínuo), **R Superataque** (teleporta pro cursor + explosão AoE 50 + stun)
- [x] ✅ Cooldown + custo de mana por skill
- [x] ✅ Números de dano flutuantes (`scenes/fx/damage_number`)
- [ ] 🔴 **Trocar skill de slot não funciona de verdade:** `skills_menu` guarda a escolha em `current_equipped`, mas o `player.gd` tem um `match slot` fixo e **não lê** esse menu. → conectar o menu ao player
- [ ] 🟡 Nossas skills antigas (Bolt Mágico, Arcane Nova, Chuva de Meteoros) ainda existem como cenas mas **não são usadas** por padrão — reaproveitar via o menu de skills
- [ ] 💡 Balancear dano / cooldown / mana de tudo (números ainda no chute)

## 3. Inimigos & Ondas
- [x] ✅ **Ghoul** — perseguidor animado
- [x] ✅ **Sprinter** — rápido, pouca vida, pressiona o player (tom avermelhado)
- [x] ✅ **Boss à distância (Guardião)** — 3 padrões: tiro reto → tiro preditivo → tridente em leque
- [x] ✅ **Dash Boss** — avisa o caminho em vermelho (telegraph) e dá uma investida reta travada
- [x] ✅ `WaveManager` — 4 ondas (2 comuns com sprinters → boss → dash boss); só avança quando limpa a onda
- [ ] 🟡 Sprinter e bosses reusam sprites existentes (sem arte própria ainda)
- [ ] 💡 Escalar dificuldade / mais ondas / mais tipos de inimigo

## 4. UI / HUD & Menus
- [x] ✅ HUD: orbes HD de vida/mana (com preenchimento dinâmico `orb_fill`), hotbar Q/W/E/R com cooldown radial, contador de ondas, banner de rodada
- [x] ✅ **Fonte 8-bit** (Press Start 2P) em toda a UI via tema padrão (`assets/ui/ui_theme.tres`)
- [x] ✅ **Menu de pausa reformado (ESC):** moldura pixel-art dark-fantasy (`pause_frame.png`), 2 páginas — Pausa (Continuar / Configuração / Sair) e Configuração (Áudio + Estilo de jogo Clássico/Moderno + Voltar); conteúdo encaixado no centro da moldura
- [x] ✅ **Inventário** movido pro canto inferior direito com ícone HD de mochila (clicável ou tecla I)
- [x] ✅ **Inventário com moldura dark-fantasy** (`inventory_frame.png`): 12 slots sobre os sockets da arte, título 8-bit, gems na base, **fundo escurece ao abrir**; itens do Felipe integrados (arma inicial por classe)
- [x] ✅ **Mochila 16-bit** pixel-art no HUD (trocou a HD ciana)
- [ ] 🟡 **Aplicar a moldura + fonte nos outros menus** (Armadura, Gems, Skills) — ainda com layout/estilo antigo
- [ ] 🟡 **Estilizar os botões** (fundo/borda dark-fantasy no lugar do cinza padrão do Godot)
- [ ] 🔴 **Conflito de tecla:** Inventário **e** menu de Skills abrem ambos na tecla **I** — separar (ex.: Skills em K)
- [ ] 🟡 Gems no **Ctrl** (tecla-modificador) é ruim pra toggle — trocar por uma tecla normal (ex.: G)
- [ ] 🟡 Ícone de **Armadura (🛡 M)** ainda solto no topo-esquerdo — mover/estilizar

## 4b. Tela Inicial / Classes / Multiplayer
- [x] ✅ **Tela inicial** (`main_menu.tscn`, agora é o `run/main_scene`): título "LOD / Legends of Darkness" sobre fundo de cripta, botões Novo Jogo / Configuração / Sair
- [x] ✅ **Escolha de classe:** Mago / Arqueiro / Lutador, cada card com descrição + barras de atributo (vida/mana/dano/velocidade); "Jogar como X" entra no jogo
- [x] ✅ Classe escolhida salva em `GameState.selected_class` (+ defs em `GameState.CLASSES`)
- [ ] 🔴 **Aplicar os atributos da classe no player** — hoje a classe é guardada mas o player usa stats fixos; ligar isso faz a escolha ter efeito
- [ ] 💡 **Wallpaper** da tela inicial (arte dark-fantasy pixel sendo gerada por IA) no lugar do chão de pedra
- [ ] 💡 **Multiplayer online + save do personagem** (feature grande, adiada — "depois vemos")

## 4c. Mundo aberto / Passagens
- [x] ✅ **Porta reutilizável** (`scenes/entities/door.{gd,tscn}`): `Area3D` que troca de cena ao **clicar** (picking 3D) **ou encostar** (proximidade); arte `door.png` (arco de pedra com céu+grama = saída)
- [x] ✅ **Passagem cripta → mundo**: porta no `main.tscn` leva ao `overworld.tscn`
- [x] ✅ **Overworld** (`scenes/world/overworld.tscn`): mundo aberto novo (campo verde, luz de dia, player/câmera/HUD) com **porta de volta** pra cripta
- [ ] 🟡 **Overworld está vazio de propósito** — falta o design (hub/cidade? portais pras várias criptas? exploração?)
- [ ] 🟡 Clicar na porta também dispara o ataque (botão esq.) — cosmético; trocar por tecla de interagir se incomodar
- [ ] 💡 **Múltiplos portais** no overworld pras várias criptas (fogo/terra/veneno…)

## 5. Progressão (Inventário / Gems / Armadura)
> Todos existem como interface, mas **ainda não mexem no gameplay** — é aqui que tem mais o que ligar.
- [x] ✅ **Inventário:** `add_item`/`remove_item` de verdade (12 slots, clique num slot ocupado remove); slots mostram o ícone do item
- [x] ✅ **Arma inicial por classe:** mago nasce com Cajado Arcano 🪄, arqueiro com Arco Curto 🏹, lutador com Espada Longa 🗡 (`GameState.WEAPONS`), já cai no inventário ao entrar no jogo
- [x] ✅ **Pickup no mundo:** `scenes/entities/pickups/item_pickup.tscn` (Area3D na layer `pickups`) — player encosta, item entra no inventário via `EventBus.item_picked_up`
- [ ] 🟡 Nada ainda **spawna** um `ItemPickup` no mapa — falta ligar isso a loot de inimigo/baú
- [ ] 🔴 **Gems:** dá pra arrastar as pedras pros slots Q/W/E/R e guarda a escolha, mas os efeitos (**+25% dano**, **-25% mana**, **+2 projéteis**, **+25% tamanho**) **não são aplicados** no player
- [ ] 🔴 **Armadura:** seleciona (0–45% de redução de dano) mas a redução **não é aplicada** ao dano recebido
- [ ] 💡 Loot: inimigo dropar item/gem ao morrer
- [ ] 💡 XP / nível / ficar mais forte ao longo das ondas

## 6. Arte & Visual
- [x] ✅ Arte HD sobreviveu ao 3D: chão, emblema, boss HD, orbes, ícones de skill
- [x] ✅ **Mago pixel roxo** (`mago_walk.png`): billboard HD removido, voltou ao spritesheet 5×3 recolorido de ciano → roxo arcano
- [ ] 🟡 Ghoul ainda é pixel billboard genérico — sem arte própria
- [ ] 💡 **Arte melhorada do mago** (spritesheet dark-fantasy) — prompt/PixelLab quando quiser subir o nível do pixel
- [ ] 🟡 Mundo 3D com texturas placeholder (paredes/chão sólidos)

## 7. Repositório / Organização
- [ ] 🟡 `graphify-out/` (~8 mil linhas de análise) está versionado — avaliar mover pro `.gitignore`
- [ ] 🟡 `.gitignore` do Felipe ignora `project.godot` e os `.import` — decidir se mantém (ignorar `project.godot` é arriscado; ele guarda autoloads/inputs/config)
- [x] ✅ `docs/vault/` (Obsidian) com "Estado do Projeto" e mapa da cripta
- [x] ✅ `ERROS_GODOT.md` — relatório de erros já corrigidos (ex.: `is_key_just_pressed` → `_input(event)`)

---

### Prioridades sugeridas (ordem pra atacar)
1. 🔴 **Aplicar atributos da classe no player** (vida/mana/dano/veloc.) — faz a escolha de classe ter efeito
2. 🔴 Ligar **armadura** e **gems** ao gameplay (efeitos reais)
3. 🔴 Ligar o **menu de Skills** ao player (trocar skill de slot de verdade)
4. 🟡 Padronizar os **outros menus** com a moldura + fonte 8-bit; resolver **conflito de tecla I**
5. 🟡 Ajuste fino da **câmera** (ângulo/fov) e **textura das paredes/chão**
6. 💡 **Loot / XP** e **wallpaper** da tela inicial
