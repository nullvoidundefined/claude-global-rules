#!/usr/bin/env bash
# install.sh: point Cursor at the port.
#
# User-level install (default): symlinks the five things Cursor reads from
# ~/.cursor/ to their counterparts under ~/.claude/cursor/, so a `git pull` of
# ~/.claude updates Cursor at the same time:
#
#   ~/.cursor/rules      -> ~/.claude/cursor/rules      (.mdc rules)
#   ~/.cursor/hooks.json -> ~/.claude/cursor/hooks.json (the hook wiring)
#   ~/.cursor/agents     -> ~/.claude/cursor/agents     (subagents)
#   ~/.cursor/commands   -> ~/.claude/cursor/commands   (slash commands)
#   ~/.cursor/skills     -> ~/.claude/cursor/skills     (the two skill overrides;
#                           the rest load from ~/.claude/skills/ directly)
#
# An existing real directory or file at any of those paths is never replaced:
# the script prints the `mv` to run and stops, the same contract as
# hooks/install-git-hooks.sh. A symlink already pointing into the port is
# refreshed in place.
#
# Project-level install: `--project <repo>` copies the rules and hooks.json into
# <repo>/.cursor/ for a checkout where the user-level directory is not read
# (or for a teammate without ~/.claude). Copies are snapshots; re-run after a
# pull. The rule bodies still reference ~/.claude paths, so the repo must be
# installed there for the on-demand reads to resolve.
#
#   bash ~/.claude/cursor/install.sh
#   bash ~/.claude/cursor/install.sh --uninstall
#   bash ~/.claude/cursor/install.sh --project ~/code/some-repo
set -euo pipefail

PORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURSOR_HOME="${CURSOR_HOME:-$HOME/.cursor}"
LINKS="rules hooks.json agents commands skills"

warn_location() {
  # hooks.json names the adapter by its ~/.claude path (Cursor resolves a
  # command relative to the hooks.json it came from, which differs between the
  # user and project locations, so only an absolute path works in both).
  if [ "$PORT_DIR" != "$HOME/.claude/cursor" ]; then
    echo "warning: this checkout is at $PORT_DIR, but hooks.json runs the adapter from ~/.claude/cursor/hooks/. Install the repo at ~/.claude (SETUP.md) or edit the commands in hooks.json." >&2
  fi
}

points_into_port() {
  [ -L "$1" ] || return 1
  case "$(readlink "$1")" in "$PORT_DIR"/*) return 0 ;; *) return 1 ;; esac
}

install_user_level() {
  warn_location
  mkdir -p "$CURSOR_HOME"
  local name target
  for name in $LINKS; do
    target="$CURSOR_HOME/$name"
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
  echo "Cursor now reads the port from ~/.cursor. Restart Cursor (or reload the window) so it re-scans rules, hooks, agents, commands, and skills."
  echo "Verify in Cursor: Settings > Rules should list the .mdc rules; Settings > Hooks should list the 8 events from hooks.json."
  echo "If the rules do not appear, this Cursor build does not read a global rules directory: install per project instead with  bash $PORT_DIR/install.sh --project <repo>"
}

uninstall_user_level() {
  local name target
  for name in $LINKS; do
    target="$CURSOR_HOME/$name"
    if points_into_port "$target"; then
      rm "$target"
      echo "removed $target"
    fi
  done
}

install_project_level() {
  local repo="$1"
  [ -d "$repo" ] || { echo "no such directory: $repo" >&2; exit 1; }
  warn_location
  mkdir -p "$repo/.cursor/rules"
  cp "$PORT_DIR"/rules/*.mdc "$repo/.cursor/rules/"
  echo "copied $(ls "$PORT_DIR"/rules/*.mdc | wc -l | tr -d ' ') rules into $repo/.cursor/rules/"
  if [ -e "$repo/.cursor/hooks.json" ]; then
    echo "left $repo/.cursor/hooks.json in place; merge the entries from $PORT_DIR/hooks.json by hand." >&2
  else
    cp "$PORT_DIR/hooks.json" "$repo/.cursor/hooks.json"
    echo "copied hooks.json into $repo/.cursor/"
  fi
  echo "Agents, commands, and skills stay user-level; run this script without --project for those."
}

case "${1:-}" in
  "") install_user_level ;;
  --uninstall) uninstall_user_level ;;
  --project) install_project_level "${2:?--project needs a repo path}" ;;
  *) echo "usage: install.sh [--uninstall | --project <repo>]" >&2; exit 2 ;;
esac
