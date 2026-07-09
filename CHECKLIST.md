# LOD — Checklist de Trabalho (pós-merge da branch do Felipe)

Estado após adotar a versão **2.5D / 3D** do Felipe como base (merge `4c86233`, 08/07/2026).

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
- [x] ✅ HUD: orbes HD de vida/mana, hotbar Q/W/E/R com cooldown radial, contador de ondas, banner de rodada
- [x] ✅ Menus abrem/fecham: Inventário (**I**), Armadura (**M**), Skills, Gems (**Ctrl**), Settings (engrenagem)
- [ ] 🔴 **Conflito de tecla:** Inventário **e** menu de Skills abrem ambos na tecla **I** — separar (ex.: Skills em K)
- [ ] 🔴 **Orbes:** conferir se ainda esvaziam com vida/mana (no merge ficou a HUD do Felipe; nosso shader `orb_fill` de preenchimento dinâmico ficou de fora) — reconectar se preciso
- [ ] 🟡 Gems no **Ctrl** (tecla-modificador) é ruim pra toggle — trocar por uma tecla normal (ex.: G)

## 5. Progressão (Inventário / Gems / Armadura)
> Todos existem como interface, mas **ainda não mexem no gameplay** — é aqui que tem mais o que ligar.
- [ ] 🔴 **Inventário:** 12 slots vazios, sem itens reais nem loot
- [ ] 🔴 **Gems:** dá pra arrastar as pedras pros slots Q/W/E/R e guarda a escolha, mas os efeitos (**+25% dano**, **-25% mana**, **+2 projéteis**, **+25% tamanho**) **não são aplicados** no player
- [ ] 🔴 **Armadura:** seleciona (0–45% de redução de dano) mas a redução **não é aplicada** ao dano recebido
- [ ] 💡 Loot: inimigo dropar item/gem ao morrer
- [ ] 💡 XP / nível / ficar mais forte ao longo das ondas

## 6. Arte & Visual
- [x] ✅ Arte HD sobreviveu ao 3D: chão, emblema, boss HD, orbes, ícones de skill
- [ ] 🟡 Player e ghoul ainda são pixel billboard (contraste com o HD) — eventual upgrade pra HD
- [ ] 🟡 Mundo 3D com texturas placeholder (paredes/chão sólidos)

## 7. Repositório / Organização
- [ ] 🟡 `graphify-out/` (~8 mil linhas de análise) está versionado — avaliar mover pro `.gitignore`
- [ ] 🟡 `.gitignore` do Felipe ignora `project.godot` e os `.import` — decidir se mantém (ignorar `project.godot` é arriscado; ele guarda autoloads/inputs/config)
- [x] ✅ `docs/vault/` (Obsidian) com "Estado do Projeto" e mapa da cripta
- [x] ✅ `ERROS_GODOT.md` — relatório de erros já corrigidos (ex.: `is_key_just_pressed` → `_input(event)`)

---

### Prioridades sugeridas (ordem pra atacar)
1. 🔴 Ligar **armadura** e **gems** ao gameplay (efeitos reais) — maior "buraco" hoje
2. 🔴 Ligar o **menu de Skills** ao player (trocar skill de slot de verdade)
3. 🔴 Resolver o **conflito de tecla I** e conferir o **fill das orbes**
4. 🟡 Ajuste fino da **câmera** (ângulo/fov) e **textura das paredes/chão**
5. 💡 **Loot / XP** pra dar progressão de verdade
