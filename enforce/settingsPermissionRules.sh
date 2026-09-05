#!/usr/bin/env bash
# settingsPermissionRules.sh: sourced helper, not a hook. Evaluates the
# Bash(...) and Read(...) permission rules of ~/.claude/settings.json the way
# Claude Code does, for the tools that do not read that file (the Cursor and
# Codex hook adapters). A rule is a literal prefix with "*" as the only
# wildcard; each becomes an anchored ERE over one command segment (compound
# commands are split on &&, ||, ; and |) or over the file path.
#
# Provides:
#   matching_bash_rule deny|ask "<command>"   prints the first matching rule
#   read_is_denied "<file path>"              exit 0 when a Read(...) deny rule matches
# Reads $CLAUDE_SETTINGS_FILE (default ~/.claude/settings.json).

SETTINGS_PERMISSION_FILE="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"

bash_rule_regexes() {
  [ -f "$SETTINGS_PERMISSION_FILE" ] || return 0
  jq -r --arg k "$1" '.permissions[$k][]? | select(startswith("Bash(")) | .[5:-1]' "$SETTINGS_PERMISSION_FILE" 2>/dev/null \
    | while IFS= read -r rule; do
        [ -n "$rule" ] || continue
        printf '%s\t^[[:space:]]*%s[[:space:]]*$\n' "$rule" \
          "$(printf '%s' "$rule" | sed -e 's/[.+?^$(){}|[\/]/\\&/g' -e 's/\]/\\]/g' -e 's/\*/.*/g')"
      done
}

matching_bash_rule() {
  local segments rule regex
  segments=$(printf '%s\n' "$2"; printf '%s' "$2" | awk '{gsub(/&&|\|\||;|\|/, "\n"); print}')
  while IFS=$'\t' read -r rule regex; do
    [ -n "$regex" ] || continue
    if printf '%s\n' "$segments" | grep -Eq "$regex"; then
      printf '%s' "$rule"
      return 0
    fi
  done < <(bash_rule_regexes "$1")
  return 1
}

deny_read_regexes() {
  [ -f "$SETTINGS_PERMISSION_FILE" ] || return 0
  jq -r '.permissions.deny[]? | select(startswith("Read(")) | .[5:-1]' "$SETTINGS_PERMISSION_FILE" 2>/dev/null \
    | while IFS= read -r pattern; do
        [ -n "$pattern" ] || continue
        case "$pattern" in
          //*) pattern="/${pattern#//}" ;;
          "~/"*) pattern="$HOME/${pattern#\~/}" ;;
        esac
        pattern=$(printf '%s' "$pattern" | sed -e 's/[.+?^$(){}|[]/\\&/g' -e 's#\*\*/#\x01#g' -e 's/\*\*/\x02/g' -e 's/\*/[^\/]*/g' -e 's#\x01#(.*/)?#g' -e 's/\x02/.*/g')
        printf '^%s$\n' "$pattern"
      done
}

read_is_denied() {
  local file="$1" resolved regex
  resolved=$(readlink -f "$file" 2>/dev/null || printf '%s' "$file")
  while IFS= read -r regex; do
    [ -n "$regex" ] || continue
    if printf '%s' "$file" | grep -Eq "$regex" || printf '%s' "$resolved" | grep -Eq "$regex"; then
      return 0
    fi
  done < <(deny_read_regexes)
  return 1
}
