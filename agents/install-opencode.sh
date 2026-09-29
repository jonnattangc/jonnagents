#!/usr/bin/env bash
#
# install-opencode.sh - Instala las definiciones de agentes en OpenCode, a
#                       nivel usuario (~/.config/opencode/agents/).
#
# Las definiciones de definitions/ estan en formato neutral. Este script las
# traduce al formato de agente Markdown de OpenCode:
#   name         -> nombre del archivo (OpenCode no usa el campo)
#   capabilities -> permission   (sin write ni edit: edit=deny; sin shell: bash=deny)
#   model-tier   -> se omite: el agente hereda el modelo configurado en OpenCode,
#                   salvo que se indique --model <proveedor/modelo>
#   Todos se instalan con mode: subagent.
#
# La instalacion es SIEMPRE global (respeta $XDG_CONFIG_HOME). Una copia en
# .opencode/agents/ de un proyecto pisaria a la global y quedaria desactualizada.
#
# Uso:
#   ./install-opencode.sh                                # instala todos los agentes
#   ./install-opencode.sh --list                         # lista los agentes disponibles
#   ./install-opencode.sh -a cpp-dev                     # solo algunos (repetible)
#   ./install-opencode.sh --model anthropic/claude-sonnet-5-5   # fija el modelo
#   ./install-opencode.sh --dry-run                      # muestra que haria, sin escribir
#
# Requiere bash. Si se invoca con `sh install-opencode.sh`, se re-ejecuta solo.
#

# --- Garantiza que corramos bajo bash de verdad ---
if [ -z "${AGENTS_INSTALL_BASH:-}" ]; then
  if command -v bash >/dev/null 2>&1; then
    AGENTS_INSTALL_BASH=1
    export AGENTS_INSTALL_BASH
    exec bash "$0" "$@"
  fi
  echo "Error: este script requiere bash y no se encontro en el PATH." >&2
  exit 1
fi

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

HERRAMIENTA="OpenCode"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/agents"
DIR_LOCAL=".opencode/agents"
MODELO=""

opcion_extra() {
  case "$1" in
    -m|--model)
      if [[ -z "$2" ]]; then rojo "--model requiere un valor (ej. anthropic/claude-sonnet-5-5)"; exit 1; fi
      MODELO="$2"; EXTRA_N=2 ;;
  esac
}

# Traduce una definicion neutral al formato de OpenCode.
traducir() {
  local src="$1" permisos=()
  if ! tiene_capacidad "$src" write && ! tiene_capacidad "$src" edit; then
    permisos+=("  edit: deny")
  fi
  tiene_capacidad "$src" shell || permisos+=("  bash: deny")

  echo "---"
  bloque_description "$src"
  echo "mode: subagent"
  [[ -n "$MODELO" ]] && echo "model: $MODELO"
  if [[ ${#permisos[@]} -gt 0 ]]; then
    echo "permission:"
    printf '%s\n' "${permisos[@]}"
  fi
  echo "---"
  cuerpo "$src"
}

parsear_args "$@"
instalar_todo

echo
echo "Listo. Los agentes quedan disponibles en todos tus proyectos de esta maquina."
echo
echo "Verificacion: dentro de OpenCode, escribe @ para ver los subagentes disponibles,"
echo "              o invoca uno directo, por ejemplo: @java-backend-dev <tarea>"
