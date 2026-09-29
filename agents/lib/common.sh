#!/usr/bin/env bash
#
# common.sh - Funciones compartidas por los instaladores de agentes.
#
# Se carga con `source` desde install-<herramienta>.sh. No se ejecuta solo.
#
# Cada instalador define, antes de llamar a `instalar_todo`:
#   HERRAMIENTA       nombre para mostrar (ej. "Claude Code")
#   DEST              directorio destino de las definiciones traducidas
#   DIR_LOCAL         directorio de agentes por proyecto que pisa al global
#                     (ej. ".claude/agents"), para avisar de copias locales
#   traducir <src>    funcion que imprime por stdout la definicion traducida
#

set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFS_DIR="$AGENTS_DIR/definitions"

CAPACIDADES_VALIDAS="read write edit shell search"
TIERS_VALIDOS="fast standard deep"

DRY_RUN=false
SELECTED=()

rojo()  { printf '\033[31m%s\033[0m\n' "$*"; }
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
gris()  { printf '\033[90m%s\033[0m\n' "$*"; }

# Imprime el bloque de comentarios de la cabecera del instalador como ayuda.
usage() { awk 'NR>1 { if (!/^#/) exit; sub(/^#[[:space:]]?/, ""); print }' "$0"; }

# Definiciones = todos los .md de definitions/.
listar_agentes() {
  find "$DEFS_DIR" -maxdepth 1 -name '*.md' -exec basename {} .md \; | sort
}

# --- Lectura del frontmatter -------------------------------------------------

# Imprime el frontmatter (sin los delimitadores ---).
frontmatter() {
  awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f {print}' "$1"
}

# Imprime el cuerpo (todo lo que sigue al segundo ---).
cuerpo() {
  awk 'c>=2 {print; next} /^---$/ {c++}' "$1"
}

# Valor escalar de un campo de una linea: `campo: valor`.
campo() {
  frontmatter "$1" | awk -v k="$2" '
    $0 ~ "^" k ":[[:space:]]" { sub("^" k ":[[:space:]]*", ""); print; exit }'
}

# Bloque de la description tal como esta escrito (con su clave), para copiarlo
# sin reinterpretar el YAML: la linea `description:` y sus lineas indentadas.
bloque_description() {
  frontmatter "$1" | awk '
    /^description:/ {p=1; print; next}
    p && /^[[:space:]]/ {print; next}
    p {exit}'
}

# Lista de capacidades, una por linea. Acepta `capabilities: [a, b, c]`.
capacidades() {
  campo "$1" capabilities | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d'
}

tiene_capacidad() {
  capacidades "$1" | grep -qx "$2"
}

# --- Validacion --------------------------------------------------------------

validar() {
  local archivo="$1" base name tier cap errores=0
  base="$(basename "$archivo" .md)"

  if [[ "$(head -1 "$archivo")" != "---" ]]; then
    rojo "  ✗ $base: no empieza con frontmatter YAML (---)"; return 1
  fi

  name="$(campo "$archivo" name)"
  if [[ -z "$name" ]]; then
    rojo "  ✗ $base: falta el campo 'name'"; errores=1
  elif [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    rojo "  ✗ $base: name='$name' debe ser kebab-case"; errores=1
  elif [[ "$name" != "$base" ]]; then
    rojo "  ✗ $base: name='$name' no coincide con el nombre del archivo"; errores=1
  fi

  if [[ -z "$(bloque_description "$archivo")" ]]; then
    rojo "  ✗ $base: falta el campo 'description' (es lo que el orquestador lee para elegir el agente)"; errores=1
  fi

  if [[ -z "$(capacidades "$archivo")" ]]; then
    rojo "  ✗ $base: falta 'capabilities' (valores: $CAPACIDADES_VALIDAS)"; errores=1
  else
    while IFS= read -r cap; do
      if [[ " $CAPACIDADES_VALIDAS " != *" $cap "* ]]; then
        rojo "  ✗ $base: capacidad desconocida '$cap' (valores: $CAPACIDADES_VALIDAS)"; errores=1
      fi
    done < <(capacidades "$archivo")
  fi

  tier="$(campo "$archivo" model-tier)"
  if [[ -z "$tier" ]]; then
    rojo "  ✗ $base: falta 'model-tier' (valores: $TIERS_VALIDOS)"; errores=1
  elif [[ " $TIERS_VALIDOS " != *" $tier "* ]]; then
    rojo "  ✗ $base: model-tier='$tier' invalido (valores: $TIERS_VALIDOS)"; errores=1
  fi

  # Parseo YAML real: un ':' sin comillas en la description rompe el frontmatter
  # y la herramienta se salta el archivo en silencio.
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 - "$archivo" <<'PYEOF' 2>/dev/null
import sys
try:
    import yaml
except ImportError:
    sys.exit(0)                      # sin PyYAML no se valida, pero no se bloquea
texto = open(sys.argv[1], encoding="utf-8").read()
partes = texto.split("---")
if len(partes) < 3:
    sys.exit(1)
try:
    datos = yaml.safe_load(partes[1])
except yaml.YAMLError:
    sys.exit(1)
sys.exit(0 if isinstance(datos, dict) and datos.get("name") and datos.get("description") else 1)
PYEOF
    then
      rojo "  ✗ $base: frontmatter YAML invalido"
      gris "     Causa habitual: ':' sin comillas en la description. Usa un escalar de bloque:"
      gris "       description: >-"
      gris "         texto con: dos puntos, sin problema"
      errores=1
    fi
  fi

  return $errores
}

# --- Argumentos --------------------------------------------------------------

# Procesa las opciones comunes. Las opciones propias del instalador se manejan
# con la funcion opcional `opcion_extra <arg> <siguiente>`, que aplica la opcion
# y deja en EXTRA_N cuantos argumentos consumio (0 si no la reconoce).
EXTRA_N=0
parsear_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -l|--list)    listar_agentes; exit 0 ;;
      -n|--dry-run) DRY_RUN=true; shift ;;
      -a|--agent)   SELECTED+=("${2%.md}"); shift 2 ;;
      -h|--help)    usage; exit 0 ;;
      *)
        EXTRA_N=0
        if declare -F opcion_extra >/dev/null; then opcion_extra "$1" "${2:-}"; fi
        if [[ "$EXTRA_N" -gt 0 ]]; then
          shift "$EXTRA_N"
        elif [[ "$1" == -* ]]; then
          rojo "Opcion desconocida: $1"; echo; usage; exit 1
        else
          rojo "La instalacion es global: no recibe una ruta de proyecto."
          gris "Los agentes quedan disponibles en todos tus proyectos, incluido '$1'."
          exit 1
        fi ;;
    esac
  done
}

# --- Instalacion -------------------------------------------------------------

instalar_todo() {
  local archivos=() f nombre base fallas=0

  if [[ ${#SELECTED[@]} -gt 0 ]]; then
    for nombre in "${SELECTED[@]}"; do
      if [[ -f "$DEFS_DIR/$nombre.md" ]]; then
        archivos+=("$DEFS_DIR/$nombre.md")
      else
        rojo "No existe la definicion '$nombre.md' en $DEFS_DIR."; exit 1
      fi
    done
  else
    # Los nombres son kebab-case sin espacios: el split es seguro.
    for nombre in $(listar_agentes); do archivos+=("$DEFS_DIR/$nombre.md"); done
  fi

  if [[ ${#archivos[@]} -eq 0 ]]; then rojo "No hay definiciones en $DEFS_DIR"; exit 1; fi

  echo "Validando ${#archivos[@]} definicion(es)..."
  for f in "${archivos[@]}"; do validar "$f" || fallas=$((fallas+1)); done
  if [[ $fallas -gt 0 ]]; then
    rojo "Se encontraron $fallas definicion(es) invalida(s). No se instalo nada."; exit 1
  fi
  verde "  ✓ frontmatter valido en todas"

  echo
  echo "Herramienta: $HERRAMIENTA"
  echo "Destino:     $DEST"
  $DRY_RUN && gris "(dry-run: no se escribe nada)"
  [[ "$DRY_RUN" == false ]] && mkdir -p "$DEST"

  TMP_TRADUCCION="$(mktemp)"
  trap 'rm -f "$TMP_TRADUCCION"' EXIT

  for f in "${archivos[@]}"; do
    base="$(basename "$f")"
    traducir "$f" > "$TMP_TRADUCCION"
    if [[ -f "$DEST/$base" ]] && cmp -s "$TMP_TRADUCCION" "$DEST/$base"; then
      gris "  = $base (sin cambios)"
    elif [[ -f "$DEST/$base" ]]; then
      $DRY_RUN || cp "$TMP_TRADUCCION" "$DEST/$base"
      verde "  ↻ $base (actualizado)"
    else
      $DRY_RUN || cp "$TMP_TRADUCCION" "$DEST/$base"
      verde "  + $base (instalado)"
    fi
  done

  avisar_copias_locales "${archivos[@]}"
}

# Busca hacia arriba desde $PWD un DIR_LOCAL con copias de estos agentes: la
# definicion por proyecto pisa a la global y quedaria desactualizada.
avisar_copias_locales() {
  local dir="$PWD" locales f
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/$DIR_LOCAL" && "$dir/$DIR_LOCAL" != "$DEST" ]]; then
      locales=""
      for f in "$@"; do
        [[ -f "$dir/$DIR_LOCAL/$(basename "$f")" ]] && locales="$locales $(basename "$f" .md)"
      done
      if [[ -n "$locales" ]]; then
        echo
        rojo "Atencion: '$dir/$DIR_LOCAL' tiene copias locales que PISAN a las globales:"
        for f in $locales; do gris "  - $f"; done
        gris "Borralas para que ese proyecto use las definiciones instaladas:"
        for f in $locales; do gris "  rm $dir/$DIR_LOCAL/$f.md"; done
      fi
      break
    fi
    dir="$(dirname "$dir")"
  done
}
