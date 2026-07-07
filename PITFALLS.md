# LOD — Erros Comuns (e como já estamos evitando)

Lista dos erros mais frequentes em projetos ARPG pixel-art no Godot, por categoria.
✅ = já prevenido pela configuração/arquitetura atual. ⚠️ = precisa de disciplina contínua.

---

## 🎨 Visual / Pixel-art

### 1. Pixel-art borrada ✅
**Sintoma:** sprites ficam "manchados"/suaves em vez de nítidos.
**Causa:** filtro de textura Linear (padrão do Godot).
**Prevenção:** `default_texture_filter = Nearest` — **já setado no project.godot**.

### 2. Jitter/tremida de sprites em movimento ✅
**Sintoma:** sprite "vibra" ao andar, principalmente com câmera seguindo.
**Causa:** posições fracionárias (ex. x=10.37) renderizadas entre pixels.
**Prevenção:** `snap_2d_transforms_to_pixel = true` — **já setado**. E mover corpos só em `_physics_process`.

### 3. Escala não-inteira deformando pixels
**Sintoma:** alguns pixels ficam maiores que outros (arte "capenga").
**Causa:** resolução base que não divide a tela (ex. 800×450 em 1080p = escala 2.4×).
**Prevenção:** base 640×360 escala inteira p/ 720p/1080p/1440p — **já setado**. ⚠️ Nunca posicionar UI/sprites em coordenadas quebradas.

### 4. Player renderizando na frente/atrás errado (profundidade)
**Sintoma:** player "em cima" de uma árvore que deveria cobri-lo.
**Causa:** esquecer Y-sort em jogo top-down.
**Prevenção:** ⚠️ ativar `y_sort_enabled` no node do mundo E nos TileMapLayers; pivô dos sprites na base dos pés (ver ARCHITECTURE.md).

### 5. Misturar tamanhos/paletas de arte
**Sintoma:** jogo parece colagem de assets aleatórios.
**Prevenção:** ⚠️ tile 16×16 fixo + uma única paleta de cores definida antes do primeiro sprite.

---

## ⚙️ Godot — armadilhas técnicas

### 6. Mover CharacterBody2D no `_process` ✅ (convenção)
**Sintoma:** atravessa paredes em FPS baixo, jitter.
**Prevenção:** física SEMPRE em `_physics_process`, movimento SEMPRE com `move_and_slide()` e velocidade × `delta` onde aplicável.

### 7. `queue_free()` dentro de callback de colisão
**Sintoma:** erro `Can't change this state while flushing queries`.
**Causa:** deletar/mover corpos durante o processamento de física (ex. no `body_entered`).
**Prevenção:** ⚠️ `call_deferred("queue_free")` ou `set_deferred(...)` nesses callbacks.

### 8. Caminhos de node frágeis (`get_node("../../HUD/Bar")`)
**Sintoma:** reorganizou a cena → 20 scripts quebram silenciosamente.
**Prevenção:** ✅ (convenção) unique names `%Node`, `@export var` para referências, EventBus para comunicação entre sistemas. **Proibido** subir na árvore com `../`.

### 9. Sinal conectado duas vezes
**Sintoma:** dano aplicado 2×, som tocando dobrado.
**Causa:** conectar no editor E no código, ou reconectar ao re-instanciar.
**Prevenção:** ⚠️ conectar sinais em UM lugar só (preferir código, no `_ready`).

### 10. Commitar a pasta `.godot/` ✅
**Sintoma:** repo gigante, conflitos de merge sem sentido.
**Prevenção:** já está no `.gitignore`.

### 11. Referência circular de preload
**Sintoma:** erro críptico `Cyclic reference` ao rodar.
**Causa:** `player.gd` faz preload de `enemy.tscn` que faz preload de `player.tscn`.
**Prevenção:** ⚠️ entidades não se referenciam diretamente; spawns via `load()` em sistemas, dados via Resources.

---

## 🏗️ Arquitetura

### 12. Herança profunda em vez de composição
**Sintoma:** `Ghoul extends UndeadEnemy extends MeleeEnemy extends Enemy extends Entity` → mudar qualquer coisa quebra tudo.
**Prevenção:** ✅ (arquitetura) componentes como nodes filhos (`HealthComponent`, `Hitbox`). Herança de cena só 1 nível (`enemy_base.tscn` → variações).

### 13. Stats/balanceamento hardcoded
**Sintoma:** "onde mesmo que eu coloquei o dano da fireball?" espalhado em 12 arquivos.
**Prevenção:** ✅ (arquitetura) todo número de balanceamento vive em `.tres` na pasta `data/`.

### 14. UI acoplada ao gameplay
**Sintoma:** HUD quebra quando o player morre/troca de cena; testes impossíveis.
**Prevenção:** ✅ (arquitetura) HUD escuta EventBus, nunca referencia entidades.

### 15. Save system deixado para o fim
**Sintoma:** na hora de salvar, o estado do jogo está espalhado em 40 nodes impossíveis de serializar.
**Prevenção:** ⚠️ desde já, progresso/inventário/stats vivem em dados puros (Resources/dicts) — nodes só *exibem* estado.

---

## 🚀 Performance (importa cedo em jogo de horda)

### 16. Pathfinding de todos os inimigos todo frame
**Sintoma:** 50 ghouls na tela = jogo a 15 FPS.
**Prevenção:** ⚠️ recalcular rota em timer (0.2–0.5s) com offset aleatório por inimigo (stagger), não em `_physics_process`.

### 17. Instanciar cena a cada projétil/partícula
**Sintoma:** stutter ao castar skills rápido.
**Prevenção:** ⚠️ object pooling para projéteis e números de dano quando o volume crescer (não otimizar antes de medir, mas desenhar o spawner de forma que trocar por pool seja fácil).

### 18. Sons empilhando
**Sintoma:** 30 hits no mesmo frame = explosão de áudio distorcido.
**Prevenção:** ⚠️ limitar instâncias simultâneas do mesmo SFX + variar pitch (±10%).

---

## 📅 Processo (os que matam projetos de verdade)

### 19. Escopo infinito ("vai ter crafting, pets, multiplayer...")
**O erro nº 1 que mata projetos indie.**
**Prevenção:** ⚠️ meta fixa do GAME_DESIGN.md: vertical slice = 1 mapa, 1 player, 2 inimigos, 3 skills, loot básico. Nada novo entra antes disso rodar.

### 20. Polir arte antes do gameplay funcionar
**Sintoma:** 3 semanas animando capa de spell, jogo ainda não tem colisão.
**Prevenção:** ⚠️ prototipar com retângulos coloridos/assets do Kenney. Arte própria só depois do loop de combate estar divertido.

### 21. Multiplayer "depois a gente adiciona"
Netcode retrofitted em jogo singleplayer = reescrever o jogo.
**Prevenção:** ✅ decisão consciente no GAME_DESIGN.md: é singleplayer. Se um dia mudar, é outro projeto.

### 22. Não testar em build exportada
**Sintoma:** roda no editor, quebra no .exe (caminhos, `load()` dinâmico de arquivos fora do .pck).
**Prevenção:** ⚠️ exportar um build de teste a cada milestone, não só no fim.
