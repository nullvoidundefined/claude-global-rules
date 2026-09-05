#!/usr/bin/env bash
# install.sh: point OpenAI Codex at the port.
#
# Symlinks the four things Codex reads from ~/.codex/ (CODEX_HOME) to their
# counterparts under ~/.claude/openai/, so a `git pull` of ~/.claude updates
# Codex at the same time:
#
#   ~/.codex/AGENTS.md  -> ~/.claude/openai/AGENTS.md  (global instructions)
#   ~/.codex/hooks.json -> ~/.claude/openai/hooks.json (the hook wiring)
#   ~/.codex/skills     -> ~/.claude/openai/skills     (skills, session procedures,
#                                                       agent dispatchers)
#   ~/.codex/agents     -> ~/.claude/openai/agents     (custom agent roles)
#
# An existing real file or directory at any of those paths is never replaced:
# the script prints the `mv` to run and stops (an existing ~/.codex/AGENTS.md
# is common; merge yours into the project-level AGENTS.md of the repos it was
# about, or keep it as AGENTS.override.md is not read globally). A symlink
# already pointing into the port is refreshed in place.
#
#   bash ~/.claude/openai/install.sh
#   bash ~/.claude/openai/install.sh --uninstall
#
# After installing, Codex asks you to review and trust each hook the first
# time it runs (`/hooks` in the CLI lists them); hooks are trusted by content
# hash, so a change to a hook or to hooks.json needs a fresh trust.
set -euo pipefail

PORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
LINKS="AGENTS.md hooks.json skills agents"

warn_location() {
  if [ "$PORT_DIR" != "$HOME/.claude/openai" ]; then
    echo "warning: this checkout is at $PORT_DIR, but hooks.json runs the adapter from ~/.claude/openai/hooks/ and AGENTS.md points at ~/.claude paths. Install the repo at ~/.claude (SETUP.md)." >&2
  fi
}

points_into_port() {
  [ -L "$1" ] || return 1
  case "$(readlink "$1")" in "$PORT_DIR"/*) return 0 ;; *) return 1 ;; esac
}

install_user_level() {
  warn_location
  mkdir -p "$CODEX_HOME"
  local name target
  for name in $LINKS; do
    target="$CODEX_HOME/$name"
    if [ -e "$target" ] && ! [ -L "$target" ]; then
      echo "refusing to replace $target: it is a real ${name##*.} that was not installed by this script." >&2
      echo "Move it aside and re-run:  mv '$target' '$target.bak'" >&2
      exit 1
    fi
    if [ -L "$target" ] && ! points_into_port "$target"; then
      echo "refusing to replace $target: it is a symlink to $(readlink "$target"), not into $PORT_DIR." >&2
      echo "Remove it and re-run:  rm '$target'" >&2
      exit 1
    fi
    ln -sfn "$PORT_DIR/$name" "$target"
    echo "linked $target -> $PORT_DIR/$name"
  done
  echo
  echo "Codex now reads the port from $CODEX_HOME. Start a session and run /hooks to review and trust the hook entries; run /skills to confirm the skills are listed."
  echo "Hooks need the 'hooks' feature, on by default since Codex 0.114; older builds: add  [features]  hooks = true  to $CODEX_HOME/config.toml."
}

uninstall_user_level() {
  local name target
  for name in $LINKS; do
    target="$CODEX_HOME/$name"
    if points_into_port "$target"; then
      rm "$target"
      echo "removed $target"
    fi
  done
}

case "${1:-}" in
  "") install_user_level ;;
  --uninstall) uninstall_user_level ;;
  *) echo "usage: install.sh [--uninstall]" >&2; exit 2 ;;
esac
