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

## Em aberto / próximos passos possíveis

- Paredes ainda são cor sólida (placeholder) — falta textura de pedra real.
- Chão é um `PlaneMesh` totalmente plano — sem relevo de terreno como na referência.
- Vale testar em jogo (F5) o ângulo/fov da câmera depois da troca pra perspectiva; pode precisar de ajuste fino de distância/pitch.
