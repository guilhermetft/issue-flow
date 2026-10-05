#!/usr/bin/env bash
# Remove as skills do Claude Code (só as deste repo; não toca em outras).
#
# Uso:
#   ./uninstall.sh             # global: ~/.claude/skills
#   ./uninstall.sh --project   # projeto atual: ./.claude/skills
#   ./uninstall.sh --yes       # sem confirmação
set -euo pipefail

SKILLS=(create-pr issue-new issue-work issue-work-multi issue-ship)

DEST="$HOME/.claude/skills"
YES=0
for arg in "$@"; do
  case "$arg" in
    --project) DEST="$PWD/.claude/skills" ;;
    --yes|-y) YES=1 ;;
    -h|--help) sed -n '2,7p' "${BASH_SOURCE[0]:-$0}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Opção desconhecida: $arg" >&2; exit 1 ;;
  esac
done

found=()
for s in "${SKILLS[@]}"; do
  [ -d "$DEST/$s" ] && found+=("$s")
done

if [ ${#found[@]} -eq 0 ]; then
  echo "Nenhuma skill encontrada em $DEST."
  exit 0
fi

echo "Serão removidas de $DEST: ${found[*]}"
if [ "$YES" -ne 1 ]; then
  if [ -t 0 ]; then
    read -r -p "Continuar? [s/N] " ans
    [[ "$ans" =~ ^[sSyY]$ ]] || { echo "Cancelado."; exit 0; }
  else
    echo "Sem terminal interativo; use --yes." >&2; exit 1
  fi
fi

for s in "${found[@]}"; do
  rm -rf "${DEST:?}/$s"
  echo "  removido: $s"
done
echo "Pronto. Reinicie o Claude Code."
