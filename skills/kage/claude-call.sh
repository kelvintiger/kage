#!/bin/sh
# KAGE: every Claude call goes through this file, so the clean-room flags are written once.
# Usage: sh claude-call.sh <per-call flags: --model, --effort, --permission-mode, --tools, ...> < brief
#        sh claude-call.sh which     prints the binary these calls run and its version
# The binary is the first `claude` on the PATH, or the one named in KAGE_CLAUDE.
# Give the prompt on stdin: --tools takes every following word, so a prompt after it is swallowed.
#
# What the fixed flags do (each checked with live calls, see DECISIONS.md):
#   --setting-sources ""      no user, project or local settings, and with them no CLAUDE.md of any
#                             kind, rules file, plugin, hook, output style or custom agent type,
#                             whether it is the user's or sits in the folder the call starts in
#   --settings {...}          hooks off and auto-memory off, whatever else is loaded
#   --strict-mcp-config       no MCP server, from the user or from a .mcp.json in the start folder
#   --disable-slash-commands  no skills or custom commands
#   --no-session-persistence  no session record left behind
#   stream-json + verbose     the log grows while the call works and starts with what was loaded
# Not --safe-mode: it also drops the agent definition a pinned line-up passes with --agents.
# Not covered: managed (administrator) settings, which no flag switches off.
BIN="${KAGE_CLAUDE:-claude}"
if [ "${1:-}" = which ]; then
  P="$(command -v "$BIN")" || { echo "claude: $BIN not found"; exit 1; }
  printf 'claude: %s (%s)\n' "$P" "$("$BIN" --version 2>&1 | head -n 1)"
  exit 0
fi
exec "$BIN" -p --setting-sources "" --settings '{"disableAllHooks":true,"autoMemoryEnabled":false}' \
  --strict-mcp-config --disable-slash-commands --no-session-persistence \
  --output-format stream-json --verbose "$@"
