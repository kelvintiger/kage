#!/bin/sh
# KAGE check-in. Usage: sh heartbeat.sh <logs dir> [seconds, default 600]
# Waits up to that long (less if every call ends), then prints one line per call still running.
# A call is running while the process whose id is in <name>.pid is alive. Each launch removes its
# own .pid file when it ends; one left behind by a call stopped from outside can match a later,
# unrelated process, so the orchestrator removes it. Never stops anything.
cd "$1" || exit 1
EVERY="${2:-600}"
running() { ls | grep '\.pid$' | while read -r P; do kill -0 "$(cat "$P" 2>/dev/null)" 2>/dev/null && echo "${P%.pid}"; done; }
T=0; while [ "$T" -lt "$EVERY" ] && [ -n "$(running)" ]; do sleep 5; T=$((T+5)); done
NOW=$(date +%s)
running | while read -r N; do
  E=$(( (NOW - $(date -r "$N.pid" +%s 2>/dev/null || echo "$NOW")) / 60 ))
  Q=$(( NOW - $(date -r "$N.log" +%s 2>/dev/null || echo "$NOW") ))
  if [ "$Q" -lt "$EVERY" ]; then echo "$N: running $E min, log growing"
  else echo "$N: running $E min, no new output for $((Q/60)) min"; fi
done
[ -n "$(running)" ] || echo "no calls running"
