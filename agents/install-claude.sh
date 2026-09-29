#!/usr/bin/env bash
#
# install-claude.sh - Instala las definiciones de agentes en Claude Code, a
#                     nivel usuario (~/.claude/agents/).
#
# Las definiciones de definitions/ estan en formato neutral. Este script las
# traduce al formato de subagente de Claude Code:
#   capabilities -> tools   (read=Read, write=Write, edit=Edit, shell=Bash,
#                            search=Grep+Glob)
#   model-tier   -> model   (fast=haiku, standard=sonnet, deep=opus)
#
# La instalacion es SIEMPRE global: los agentes quedan en ~/.claude/agents y
# estan disponibles en todos los proyectos de esta maquina. No se instala por
# proyecto, para que no queden copias viejas pisando a las del repo.
#
# Uso:
#   ./install-claude.sh                          # instala todos los agentes
#   ./install-claude.sh --list                   # lista los agentes disponibles
#   ./install-claude.sh -a java-backend-dev      # solo algunos (repetible)
#   ./install-claude.sh --dry-run                # muestra que haria, sin escribir
#
# Requiere bash. Si se invoca con `sh install-claude.sh`, se re-ejecuta solo.
#

# --- Garantiza que corramos bajo bash de verdad ---
# bash invocado como `sh` entra en modo POSIX y el bash 3.2 de macOS rechaza
# ahi construcciones como <(...). Se re-ejecuta una vez, con un centinela.
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

HERRAMIENTA="Claude Code"
DEST="$HOME/.claude/agents"
DIR_LOCAL=".claude/agents"

# Traduce una definicion neutral al formato de Claude Code.
traducir() {
  local src="$1" tools=() tier model
  tiene_capacidad "$src" read   && tools+=("Read")
  tiene_capacidad "$src" write  && tools+=("Write")
  tiene_capacidad "$src" edit   && tools+=("Edit")
  tiene_capacidad "$src" shell  && tools+=("Bash")
  tiene_capacidad "$src" search && tools+=("Grep" "Glob")

  tier="$(campo "$src" model-tier)"
  case "$tier" in
    fast)     model="haiku" ;;
    deep)     model="opus" ;;
    *)        model="sonnet" ;;
  esac

  echo "---"
  echo "name: $(campo "$src" name)"
  bloque_description "$src"
  local IFS=','
  echo "tools: ${tools[*]}" | sed 's/,/, /g'
  echo "model: $model"
  echo "---"
  cuerpo "$src"
}

parsear_args "$@"
instalar_todo

echo
echo "Listo. Los agentes quedan disponibles en todos tus proyectos de esta maquina."
echo
echo "Verificacion:"
echo "  claude --debug     # muestra que definiciones se saltaron y por que"
echo "  Pide en la sesion: \"usa el agente java-backend-dev para ...\""
echo
echo "Nota: Claude Code detecta cambios en ~/.claude/agents en segundos, pero si"
echo "      la carpeta se acaba de crear, reinicia la sesion para que los cargue."
