#!/usr/bin/env bash
# Clears a stale .claude scheduled task lock if the lock is orphaned or older than a safe TTL.
#
# Reads .claude/scheduled_tasks.lock, checks whether the recorded PID is still running,
# and removes the lock if the process is not active or the lock is older than the
# configured TTL.
#
# Exit codes:
#   0 - lock removed or no stale lock present
#   1 - active lock detected and retained

set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lock_path="$script_dir/../.claude/scheduled_tasks.lock"
ttl_seconds=$((2 * 60 * 60))

if [ ! -f "$lock_path" ]; then
  echo "No lock file found at '$lock_path'."
  exit 0
fi

lock_json="$(cat "$lock_path")"
pid="$(echo "$lock_json" | grep -o '"pid"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$')"
acquired_at_ms="$(echo "$lock_json" | grep -o '"acquiredAt"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*$')"

if [ -z "$acquired_at_ms" ]; then
  echo "Failed to parse lock file content. Removing corrupt lock file."
  rm -f "$lock_path"
  exit 0
fi

acquired_at_s=$(( ${acquired_at_ms%%.*} / 1000 ))
now_s=$(date -u +%s)
age_s=$(( now_s - acquired_at_s ))
age_min=$(( age_s / 60 ))

pid_alive=false
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
  pid_alive=true
fi

if [ "$pid_alive" = false ] || [ "$age_s" -gt "$ttl_seconds" ]; then
  rm -f "$lock_path"
  echo "Removed stale lock file. PID: ${pid:-unknown}, age: ${age_min} min."
  exit 0
fi

echo "Lock file appears active. PID $pid is still running and lock age is ${age_min} min."
exit 1
