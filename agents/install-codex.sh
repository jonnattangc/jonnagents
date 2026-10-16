#!/usr/bin/env bash
#
# install-codex.sh - Instala las definiciones de agentes en Codex CLI como
#                    agentes personalizados, a nivel usuario (~/.codex/agents/).
#
# Codex carga cada agente desde un archivo TOML propio. Este script traduce
# cada definicion neutral de definitions/ a ese formato:
#   name         -> name
#   description  -> description            (el bloque YAML se aplana a una linea)
#   cuerpo       -> developer_instructions (string multilinea)
#   capabilities -> sandbox_mode   (con write o edit: workspace-write;
#                                   sin ellas: read-only). Codex no permite
#                                   quitar solo la shell: 'shell' no se traduce.
#   model-tier   -> model_reasoning_effort (fast=low, standard=medium, deep=high)
#   El modelo se omite: el agente hereda el de la sesion, salvo --model <modelo>.
#
# La instalacion es SIEMPRE global (respeta $CODEX_HOME). Una copia en
# .codex/agents/ de un proyecto pisaria a la global y quedaria desactualizada.
#
# Uso:
#   ./install-codex.sh                           # instala todos los agentes
#   ./install-codex.sh --list                    # lista los agentes disponibles
#   ./install-codex.sh -a k3s-cluster-ops        # solo algunos (repetible)
#   ./install-codex.sh --model gpt-5.5           # fija el modelo de todos
#   ./install-codex.sh --dry-run                 # muestra que haria, sin escribir
#
# Requiere bash. Si se invoca con `sh install-codex.sh`, se re-ejecuta solo.
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

HERRAMIENTA="Codex"
DEST="${CODEX_HOME:-$HOME/.codex}/agents"
DIR_LOCAL=".codex/agents"
EXTENSION="toml"
MODELO=""

opcion_extra() {
  case "$1" in
    -m|--model)
      if [[ -z "$2" ]]; then rojo "--model requiere un valor (ej. gpt-5.5)"; exit 1; fi
      MODELO="$2"; EXTRA_N=2 ;;
  esac
}

# Escapa un texto para un string basico de TOML ("..." o """...""").
escapar_toml() {
  sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Description en una sola linea: acepta `description: texto` y los escalares
# de bloque (`>-`, `>`, `|`...), cuyas lineas se unen con un espacio.
description_plana() {
  bloque_description "$1" | awk -v q="'" '
    NR==1 {
      sub(/^description:[[:space:]]*/, "")
      if ($0 ~ /^[>|][-+]?[[:space:]]*$/) next
      gsub("^[\"" q "]|[\"" q "]$", "")
      texto = $0; next
    }
    { sub(/^[[:space:]]+/, ""); texto = (texto == "" ? $0 : texto " " $0) }
    END { print texto }'
}

# Traduce una definicion neutral al formato de agente personalizado de Codex.
traducir() {
  local src="$1" tier esfuerzo sandbox instrucciones

  tier="$(campo "$src" model-tier)"
  case "$tier" in
    fast) esfuerzo="low" ;;
    deep) esfuerzo="high" ;;
    *)    esfuerzo="medium" ;;
  esac

  if tiene_capacidad "$src" write || tiene_capacidad "$src" edit; then
    sandbox="workspace-write"
  else
    sandbox="read-only"
  fi

  echo "# Generado por jonnagents/agents/install-codex.sh desde $(basename "$src")."
  echo "# No editar a mano: edita la definicion y vuelve a correr el instalador."
  echo
  echo "name = \"$(campo "$src" name)\""
  echo "description = \"$(description_plana "$src" | escapar_toml)\""
  [[ -n "$MODELO" ]] && echo "model = \"$(printf '%s' "$MODELO" | escapar_toml)\""
  echo "model_reasoning_effort = \"$esfuerzo\""
  echo "sandbox_mode = \"$sandbox\""
  echo

  # String literal (''') para que el prompt quede legible tal cual; si el
  # cuerpo contiene ''' se usa un string basico escapado. El salto de linea
  # que sigue al delimitador de apertura no forma parte del valor.
  instrucciones="$(cuerpo "$src" | sed '/./,$!d')"
  if [[ "$instrucciones" != *"'''"* ]]; then
    printf "developer_instructions = '''\n%s\n'''\n" "$instrucciones"
  else
    printf 'developer_instructions = """\n%s\n"""\n' "$(printf '%s' "$instrucciones" | escapar_toml)"
  fi
}

parsear_args "$@"
instalar_todo

echo
echo "Listo. Los agentes quedan disponibles en todos tus proyectos de esta maquina."
echo
echo "Verificacion: abre una sesion nueva de Codex y pidele un subagente por nombre,"
echo "              por ejemplo: \"lanza el agente java-backend-dev para ...\""
echo "              Un archivo mal formado se ignora con un aviso al iniciar la sesion."
