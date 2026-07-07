# LOD — Ambiente de Desenvolvimento (Windows)

Tudo o que precisa ser instalado para desenvolver o jogo. Marque conforme instalar.

---

## 1. Essencial (obrigatório)

| Ferramenta | O que é | Como instalar |
|-----------|---------|---------------|
| **Godot 4.x — Standard** | A engine. Versão "Standard" (GDScript). NÃO precisa da .NET a menos que usemos C#. | [godotengine.org/download](https://godotengine.org/download) ou `winget install GodotEngine.GodotEngine` |
| **Git** | Controle de versão | ✅ Já instalado (2.55) |
| **GitHub CLI (`gh`)** | Criar/enviar repositório pro GitHub via terminal | `winget install GitHub.cli` |

### Comandos (PowerShell)
```powershell
winget install GodotEngine.GodotEngine
winget install GitHub.cli
# Reinicie o terminal depois para o PATH atualizar
```

> **Godot Standard vs .NET/Mono:** Começamos com **Standard** (GDScript, mais simples e suficiente).
> Só troque pela build **.NET** se decidirmos escrever partes em C# por performance.

---

## 2. Arte pixel (necessário para os assets)

| Ferramenta | O que é | Como instalar |
|-----------|---------|---------------|
| **Aseprite** | Editor de pixel-art padrão da indústria (pago, ~US$20) | Steam ou [aseprite.org](https://www.aseprite.org) |
| **LibreSprite** | Fork gratuito do Aseprite | `winget install LibreSprite.LibreSprite` |
| **Piskel** | Editor pixel-art no navegador (grátis) | [piskelapp.com](https://www.piskelapp.com) |

*Escolha um. Aseprite se puder pagar; LibreSprite/Piskel se quiser grátis.*

---

## 3. Recomendado (produtividade)

| Ferramenta | O que é | Como instalar |
|-----------|---------|---------------|
| **VS Code** | Editor externo para GDScript (autocomplete, debug) | `winget install Microsoft.VisualStudioCode` |
| **Extensão godot-tools** | Suporte a GDScript no VS Code | Marketplace do VS Code |
| **Tiled** | Editor de mapas/tilemaps (opcional, o Godot já tem TileMap nativo) | `winget install MapEditor.Tiled` |

---

## 4. Áudio (mais pra frente — M5)

| Ferramenta | O que é | Onde |
|-----------|---------|------|
| **jsfxr / sfxr** | Gerador de efeitos sonoros retrô 8/16-bit | [sfxr.me](https://sfxr.me) (navegador) |
| **Audacity** | Editor de áudio | `winget install Audacity.Audacity` |
| **freesound.org** | Banco de sons grátis (CC) | site |

---

## 5. Assets grátis para prototipar (não trava no desenho)

- **Kenney.nl** — packs top-down gratuitos ([kenney.nl/assets](https://kenney.nl/assets))
- **itch.io** — busque "top down pixel art" com filtro de licença
- **OpenGameArt.org** — sprites e tiles com licença aberta

---

## Setup mínimo para começar HOJE

Só isso já basta para o primeiro protótipo (M0):

```powershell
winget install GodotEngine.GodotEngine
winget install GitHub.cli
```

Depois é só abrir o `project.godot` (que vou criar) no Godot.
