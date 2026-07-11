---
title: Estado do Projeto — LOD
tags:
  - lod
  - godot
  - status
aliases:
  - LOD status
---

# LOD — estado atual

Jogo em Godot 4, estilo **2.5D isométrico** (Diablo-like): mundo em 3D real (`Node3D`/`CharacterBody3D`) no plano XZ, personagens como sprites `Sprite3D` billboard, câmera fixa em ângulo. Ver [[Mapa da Cripta]] para o layout da fase atual.

## O que já existe (por commits)

- **Core de movimento/câmera**: player com click-to-move e modo WASD, `CameraRig` seguindo com suavização (`scenes/world/camera_rig.gd`), utilidades isométricas centralizadas em `Iso` (`scripts/systems/iso.gd`).
- **Combate**: `HealthComponent` + `HitboxComponent`/`HurtboxComponent`, barras de vida que "encaram" a câmera fixa sem billboard completo (`health_bar.gd`).
- **Skills do player** (Q/W/E/R): raio com ricochete, bolha de atordoamento em área, pilar de fogo, superataque em área (dano + stun). Cooldown e mana geridos em `player.gd`.
- **Inimigos**: ghoul perseguidor animado, boss "Guardião da Cripta" com arte HD e ataque à distância.
- **Sistema de rodadas**: `wave_manager.gd`, ondas configuráveis (4/6/8), horda extra com mecânica de boss nova (commit `1552708`).
- **UI**: HUD (orbes de vida/mana, hotbar com cooldown), menus de armadura, inventário, skills, gems, settings.
- **Progressão**: sistema de armadura, inventário e gems (commit `185e14e`).
- **Graphify**: `graphify-out/` na raiz — grafo de conhecimento do próprio código, gerado pelo skill `/graphify`.

## Mudanças desta sessão — de "parecia 2D" para profundidade real

O código já era 3D de verdade (`Node3D`, `CharacterBody3D`, `Sprite3D`), mas visualmente lia como um jogo 2D top-down. Causa raiz, em 3 partes, todas em `scenes/main.tscn` e `scenes/world/crypt_map.gd`:

1. **Câmera ortográfica** (`projection = 1`) → sem perspectiva, zero profundidade percebida. Trocada para perspectiva (`fov = 25`).
2. **Nenhuma luz direcional** → só `ambient_light` chapada no `WorldEnvironment`, então nada projetava sombra. Adicionado `DirectionalLight3D` com `shadow_enabled = true`.
3. **Paredes sem malha visual** → `_add_wall()` só criava `StaticBody3D` de colisão, invisível. Adicionado `MeshInstance3D` (`BoxMesh`) do mesmo tamanho da colisão, com material sólido — dá pra *ver* o volume das bordas do mapa agora.

Referência visual usada como alvo: `referencia.jpeg` (isométrico com perspectiva visível, sombras fortes, terreno com relevo).

## Sessão de UI + tela inicial (Leo + Claude, 08/07/2026)

Depois de adotar esta branch na `main` (merge), o foco foi identidade visual da UI e a tela inicial.

- **Direção de arte fixada:** o **ciano/teal é só o tema desta cripta** — o jogo terá várias criptas (fogo/terra/veneno...). Tema geral = **dark fantasy, paleta saturada**. Por isso a UI é **neutra**: molduras **bronze/dourado sobre escuro**, não teal.
- **Fonte 8-bit** (Press Start 2P) em toda a UI via tema padrão do projeto (`assets/ui/ui_theme.tres`, `gui/theme/custom`).
- **Menu de pausa (ESC)** reformado: usa uma **moldura pixel-art** dark-fantasy (`assets/sprites/ui/pause_frame.png`, recortada de arte de IA) como fundo; duas páginas — **Pausa** (Continuar / Configuração / Sair) e **Configuração** (Áudio + Estilo de jogo Clássico[mouse]/Moderno[WASD]). Conteúdo medido e encaixado no centro da moldura.
- **Inventário** movido pro canto inferior direito com **ícone HD de mochila**; o antigo botão de settings saiu do HUD (virou a Configuração dentro da pausa).
- **Tela inicial** (`scenes/ui/main_menu.tscn`, agora é o `run/main_scene`): título "LOD / Legends of Darkness", **Novo Jogo / Configuração / Sair**.
- **Classes:** Novo Jogo abre a **escolha de classe** — Mago / Arqueiro / Lutador, cada card com descrição + barras de atributo. Definições em `GameState.CLASSES`; a escolhida vai pra `GameState.selected_class`. É a **base do personagem salvo do multiplayer** (rede/save ainda não implementados).

### Pendências desta frente
- **Aplicar os atributos da classe no player** (hoje só guarda a classe).
- Padronizar os **outros menus** (armadura/gems/skills/inventário) com a mesma moldura + fonte.
- **Estilizar os botões** (ainda no cinza padrão do Godot).
- **Wallpaper** dark-fantasy pixel na tela inicial (em geração por IA).

## Sessão inventário / pickup / arma inicial (09/07/2026)

Foco: dar função real ao inventário (até então só 12 slots visuais sem lógica) e fazer cada classe nascer com sua arma.

- **`GameState.WEAPONS`** (`scripts/systems/game_state.gd`): dict com a arma inicial de cada classe — mago → Cajado Arcano 🪄, arqueiro → Arco Curto 🏹, lutador → Espada Longa 🗡.
- **`inventory_menu.gd`** ganhou `add_item(item)` (ocupa o 1º slot vazio, retorna o índice ou -1 se cheio) e `remove_item(slot_index)` (limpa o slot). Slot mostra o ícone do item; clique num slot ocupado remove (drop rápido). No `_ready()`, o player já entra com a arma da própria classe no inventário.
- **Pickup no mundo** (`scenes/entities/pickups/item_pickup.gd` + `.tscn`): `Area3D` na collision layer `pickups` (já reservada no `project.godot`, layer 6, nunca usada até agora). Player encosta → emite `EventBus.item_picked_up(item)` → o inventário escuta e chama `add_item` — sem referência direta entre mundo e UI, seguindo a regra "entidades emitem, UI escuta" do `ARCHITECTURE.md`.
- **`EventBus.item_dropped`/`item_picked_up`** estavam tipados como `Resource` (nunca implementado) — mudei pra `Variant`, já que aqui os itens são `Dictionary`, igual ao padrão já usado em `skills_menu.gd`/`gems_system.gd` (o projeto nunca chegou a adotar os Resources `.tres` que o `ARCHITECTURE.md` original planejava para itens).

### Pendências desta frente
- Nada spawna um `ItemPickup` no mapa ainda — falta ligar a loot de inimigo morto ou baú.
- Arma equipada não muda o combate — hoje o ataque (flecha/orbe/foice) já é escolhido por `GameState.selected_class`, então visualmente já "bate" com a arma certa, mas não há de fato uma leitura do item equipado.
- Gems e Armadura seguem com o mesmo problema antigo: interface pronta, efeito não aplicado no gameplay (ver `CHECKLIST.md` seção 5).

## Sessão merge Felipe + arte pixel + passagem pro mundo (Leo + Claude, 10/07/2026)

Puxamos a branch do **Felipe** pra `main` e seguimos com arte e um novo mundo.

- **Merge da branch do Felipe** (`origin/Felipe` → `main`): entrou **auto-attack por classe** (foice em cone do lutador, flechas do arqueiro, orbe explosivo do mago; escala por onda), **mapa de lodo/ácido** (`swamp_map`, agora é o mapa do `main.tscn`) com **poças de veneno** (slow + dano por tempo + caveirinha), **números de dano** do player e refactor de `_cast_super` → `_damage_area`. Conflitos resolvidos à mão: `player.gd` (mantido auto-attack + a nossa animação) e `inventory_menu.gd` (mantida a nossa moldura + a lógica de itens dele).
- **Moldura do inventário** (`assets/sprites/ui/inventory_frame.png`, recortada de IA): reconstruído `inventory_menu` com a moldura de fundo, 12 slots sobre os sockets da arte, título 8-bit e gems na faixa de baixo. **Fundo escurece** ao abrir (`ColorRect` 82%); clicar fora / I / ESC fecha.
- **Mochila 16-bit** (`inventory_backpack.png`): trocada a arte HD ciana por pixel-art dark-fantasy (dourado/fogo), casando com a moldura e a fonte.
- **Mago pixel roxo**: o **billboard HD foi removido**; o player voltou ao **sprite pixel spritesheet** (animação por frame 5×3) mantendo o auto-attack do Felipe. `mago_walk.png` = `player_walk` recolorido (ciano → roxo arcano) por rotação de matiz.
- **Passagem cripta ↔ mundo**: `scenes/entities/door.{gd,tscn}` — `Area3D` reutilizável que troca de cena ao **clicar** (picking 3D) **ou encostar** (`body_entered`). Arte `door.png` = arco de pedra pixel com céu+grama na abertura. `main.tscn` tem a porta pro **`scenes/world/overworld.tscn`** (mundo aberto novo: campo verde, luz de dia, player/câmera/HUD) e o overworld tem porta de volta. `hud.gd` agora acha o inventário na cena atual (funciona nos dois mundos).

### Pendências desta frente
- **Overworld é um campo verde vazio** de propósito — é a tela em branco pro design (hub/cidade? portais pras várias criptas? exploração?).
- Clicar na porta também dispara o ataque (botão esquerdo = atacar) — cosmético; o natural é andar até ela. Dá pra trocar por tecla de interagir se incomodar.
- Atributos da classe ainda **não** aplicados no player (só vida/mana/dano/veloc. guardados em `GameState`).

## Em aberto / próximos passos possíveis

- Paredes ainda são cor sólida (placeholder) — falta textura de pedra real.
- Chão é um `PlaneMesh` totalmente plano — sem relevo de terreno como na referência.
- Vale testar em jogo (F5) o ângulo/fov da câmera depois da troca pra perspectiva; pode precisar de ajuste fino de distância/pitch.
