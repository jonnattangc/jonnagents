# jonnagents

Definiciones de agentes de código por stack, **autocontenidas** (no dependen de
repositorios externos de estándares) y escritas en un **formato neutral**, para
instalarse en cualquier agente de código: Claude Code, OpenCode, Codex, Kiro,
Aider, etc.

No están atadas a ninguna organización: el proyecto concreto aporta sus reglas
propias en su `AGENTS.md` / `CLAUDE.md`, que siempre tiene precedencia.

## Estructura

```
jonnagents/
├── README.md
├── CLAUDE.md                    ← guía de arquitectura: agentes, skills y plugins
├── LICENSE
└── agents/
    ├── definitions/             ← una definición por agente, en formato neutral
    ├── install-claude.sh        ← traduce e instala en ~/.claude/agents/
    ├── install-opencode.sh      ← traduce e instala en ~/.config/opencode/agents/
    └── lib/common.sh            ← listado, validación, traducción idempotente
```

Un archivo de `agents/definitions/` **no está activo** por sí solo: hay que correr el
instalador de la herramienta. Editar una definición no actualiza las copias ya
instaladas: vuelve a correr el instalador.

## Agentes disponibles

| Agente | Para qué sirve |
|---|---|
| `java-backend-dev` | Backend Java 21 / Spring Boot: Controller → Service → ServiceImpl → Repository, JPA, Liquibase, JUnit 5 + Mockito. |
| `python-backend-dev` | Backend Python / FastAPI: Router → Service (Protocol) → ServiceImpl → Repository, Pydantic v2, SQLAlchemy 2, Alembic, pytest. |
| `cpp-dev` | C++17 con clang++ en Linux y macOS: CMake, RAII, concurrencia, GoogleTest bajo sanitizers. |
| `frontend-web-dev` | React 19 / TypeScript / Vite con Feature-Sliced Design, React Query, RTK, RHF + Yup, Testing Library + MSW. |
| `mobile-android-dev` | Android en Kotlin (SDK y apps): MVI + Compose + Hilt en proyectos nuevos, respeto del régimen existente. |
| `mobile-ios-dev` | iOS en Swift (SDK y apps): MVVM + SwiftUI + SPM en proyectos nuevos, respeto del régimen existente. |
| `k3s-cluster-ops` | Clusters k3s: manifiestos (Kustomize / HelmChart), Traefik, local-path, config de nodos, upgrades, snapshots y diagnóstico. |
| `github-actions-dev` | CI/CD con GitHub Actions: workflows seguros (permisos mínimos, actions por SHA, OIDC), caché, reusable workflows, environments. |
| `cloudflared-tunnel-ops` | Cloudflare Tunnel: `config.yml` e ingress, rutas DNS y de red privada, cloudflared en systemd o k3s, Cloudflare Access. |

Los tres agentes de infraestructura (`k3s-cluster-ops`, `github-actions-dev`,
`cloudflared-tunnel-ops`) separan comandos de **solo lectura** (libres) de los
que **mutan estado** (requieren aprobación explícita, mostrando antes el diff o
el comando) y de los **destructivos** (requieren confirmación que nombre el
recurso).

Todos comparten los mismos principios transversales: respuestas en español,
código en inglés, **sin tildes ni ñ dentro de archivos de código**, preguntar
antes de asumir, seguridad y secretos, cobertura mínima (80/70/90), Arrange →
Act → Assert, ADRs, nunca `git push` y ninguna operación Git sin instrucción.

Ninguno delega en otros agentes: la orquestación queda en el hilo principal.

## Formato neutral

```markdown
---
name: java-backend-dev           # kebab-case, igual al nombre del archivo
description: >-                  # "Usar para… / NO usar para…": lo que el orquestador lee para elegir
  ...
capabilities: [read, write, edit, shell, search]
model-tier: standard             # fast | standard | deep
---

# Rol
...system prompt en Markdown, sin nombres de herramientas de una plataforma...
```

- `capabilities` y `model-tier` son **abstractos**: cada instalador los traduce
  a lo que entiende su herramienta.
- El cuerpo no nombra herramientas propias (`Read`, `Bash`…): dice "lee",
  "ejecuta". Así sirve igual como system prompt de subagente, como sección de
  `AGENTS.md` o como archivo de convenciones.
- Usa `description: >-` (escalar de bloque): un `:` sin comillas rompe el YAML y
  la herramienta se salta el archivo en silencio.

### Traducción por herramienta

| Neutral | Claude Code | OpenCode |
|---|---|---|
| `name` | `name` | nombre del archivo |
| `description` | `description` | `description` |
| `capabilities` | `tools`: read→`Read`, write→`Write`, edit→`Edit`, shell→`Bash`, search→`Grep`, `Glob` | `permission`: sin write ni edit → `edit: deny`; sin shell → `bash: deny` |
| `model-tier` | `model`: fast→`haiku`, standard→`sonnet`, deep→`opus` | se omite (hereda el modelo configurado) o `--model` |
| — | — | `mode: subagent` |
| cuerpo | igual | igual |

## Instalación

Ambos instaladores son globales (a nivel usuario), idempotentes (reportan cada
agente como instalado `+`, actualizado `↻` o sin cambios `=`) y validan el
frontmatter antes de escribir: si una definición es inválida, no instalan nada.

### Claude Code

```bash
./agents/install-claude.sh                    # instala todos en ~/.claude/agents/
./agents/install-claude.sh --list             # lista las definiciones
./agents/install-claude.sh -a cpp-dev         # solo algunos (repetible)
./agents/install-claude.sh --dry-run          # muestra qué haría, sin escribir
```

Si el proyecto donde estás parado tiene copias en `.claude/agents/`, el
instalador avisa: la copia del proyecto pisa a la global.

### OpenCode

```bash
./agents/install-opencode.sh                                  # instala en ~/.config/opencode/agents/
./agents/install-opencode.sh --model anthropic/claude-sonnet-5-5   # fija el modelo de todos
./agents/install-opencode.sh -a mobile-ios-dev --dry-run
```

Respeta `$XDG_CONFIG_HOME`. Avisa si hay copias en `.opencode/agents/` del
proyecto. En OpenCode se invocan con `@<agente>`.

### Otras herramientas (manual)

| Herramienta | Cómo usar una definición |
|---|---|
| Codex | Copia el cuerpo (sin frontmatter) como sección del `AGENTS.md` del repo, o como perfil/agente si tu versión lo soporta. |
| Kiro | Como steering en `.kiro/steering/<agente>.md`, o como agente personalizado con el cuerpo como prompt. |
| Aider | `aider --read agents/definitions/<agente>.md` (lo carga como convenciones de solo lectura). |

Para automatizar una herramienta nueva basta un `agents/install-<herramienta>.sh`
que cargue `lib/common.sh`, defina `HERRAMIENTA`, `DEST`, `DIR_LOCAL` y una función
`traducir` que imprima la definición en el formato de esa herramienta.

## Agregar un agente

1. Crea `agents/definitions/<nombre>.md` con el frontmatter neutral.
2. En el cuerpo sé concreto: rol, precedencia, principios transversales (copia el
   bloque de un agente existente), stack, arquitectura, protocolo, checklist,
   reglas duras y qué reportar.
3. Declara solo las capacidades que el agente necesita.
4. Valida con `./agents/install-claude.sh --dry-run`.
