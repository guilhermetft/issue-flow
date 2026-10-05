#!/usr/bin/env bash
# Instala as skills no Claude Code.
#
# Uso:
#   ./install.sh               # global: ~/.claude/skills
#   ./install.sh --project     # só no projeto atual: ./.claude/skills
#   ./install.sh --force       # sobrescreve sem perguntar
#
# Direto do GitHub:
#   curl -fsSL https://raw.githubusercontent.com/guilhermetft/claude-code-issue-workflow/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --project
set -euo pipefail

REPO="${SKILLS_REPO:-guilhermetft/claude-code-issue-workflow}"
BRANCH="${SKILLS_BRANCH:-main}"
SKILLS=(create-pr issue-new issue-work issue-work-multi issue-ship)

DEST="$HOME/.claude/skills"
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --project) DEST="$PWD/.claude/skills" ;;
    --force|-f) FORCE=1 ;;
    -h|--help) sed -n '2,11p' "${BASH_SOURCE[0]:-$0}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Opção desconhecida: $arg" >&2; exit 1 ;;
  esac
done

# Origem: pasta do próprio script (clone) ou tarball do GitHub (curl | bash).
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -f "$here/skills/${SKILLS[0]}/SKILL.md" ] && SRC="$here/skills"
fi
if [ -z "$SRC" ]; then
  command -v curl >/dev/null || { echo "curl é necessário." >&2; exit 1; }
  command -v tar  >/dev/null || { echo "tar é necessário." >&2; exit 1; }
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "Baixando $REPO@$BRANCH..."
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$TMP" --strip-components=1
  SRC="$TMP/skills"
fi

mkdir -p "$DEST"
for s in "${SKILLS[@]}"; do
  [ -f "$SRC/$s/SKILL.md" ] || { echo "Skill ausente na origem: $s" >&2; exit 1; }
  if [ -e "$DEST/$s" ] && [ "$FORCE" -ne 1 ]; then
    if [ -t 0 ]; then
      read -r -p "$s já existe em $DEST. Sobrescrever? [s/N] " ans
      [[ "$ans" =~ ^[sSyY]$ ]] || { echo "  pulado: $s"; continue; }
    else
      echo "  pulado: $s (já existe; use --force)"; continue
    fi
  fi
  rm -rf "$DEST/$s"
  cp -r "$SRC/$s" "$DEST/$s"
  echo "  instalado: $s"
done

echo
echo "Pronto em $DEST. Reinicie o Claude Code."
command -v gh >/dev/null || echo "Aviso: GitHub CLI (gh) não encontrado. Instale em https://cli.github.com/ e rode: gh auth login && gh auth refresh -s project"
