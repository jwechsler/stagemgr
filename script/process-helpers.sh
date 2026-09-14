#!/bin/bash
# Shared helpers for script/resque-worker and script/scheduler.
#
# Both scripts used to `kill $(cat pidfile)`, delete the pidfile and start the
# replacement straight away, trusting that TERM had already done its job. It
# had not: resque-scheduler only notices a signal at the end of its poll sleep,
# and on exit its at_exit hook deletes the pidfile -- by which time the *new*
# scheduler had already written its own pid there. The new pid was wiped, the
# next deploy found no pidfile, and an orphan scheduler kept running the old
# code as master (production, Sep 2026).
#
# stop_pid waits until the process is really gone, escalating to KILL after
# STOP_TIMEOUT seconds, so a restart never overlaps the old process with the
# new one. Meaningful delays are named here rather than sprinkled inline.

STOP_TIMEOUT="${STOP_TIMEOUT:-30}"   # seconds to wait after TERM
KILL_TIMEOUT="${KILL_TIMEOUT:-5}"    # seconds to wait after KILL

# is_running PID
is_running() {
  [ -n "$1" ] && kill -0 "$1" 2>/dev/null
}

# wait_for_exit PID SECONDS -> 0 once the process is gone, 1 on timeout
wait_for_exit() {
  local pid="$1" deadline=$(( $(date +%s) + $2 ))
  while is_running "$pid"; do
    [ "$(date +%s)" -ge "$deadline" ] && return 1
    sleep 1
  done
  return 0
}

# stop_pid LABEL PID -> 0 when the process is gone, 1 if it survived KILL
stop_pid() {
  local label="$1" pid="$2"
  if ! is_running "$pid"; then
    echo "$label (PID $pid) is not running"
    return 0
  fi
  echo "Stopping $label (PID $pid)..."
  kill -TERM "$pid" 2>/dev/null
  if wait_for_exit "$pid" "$STOP_TIMEOUT"; then
    echo "$label stopped"
    return 0
  fi
  echo "$label (PID $pid) ignored TERM for ${STOP_TIMEOUT}s; sending KILL"
  kill -KILL "$pid" 2>/dev/null
  if wait_for_exit "$pid" "$KILL_TIMEOUT"; then
    echo "$label killed"
    return 0
  fi
  echo "Could not stop $label (PID $pid)" >&2
  return 1
}

# pid_matches PID PATTERN -> 0 when the process's command line matches
pid_matches() {
  ps -o args= -p "$1" 2>/dev/null | grep -qE "$2"
}

# stop_pidfile_process LABEL PIDFILE PATTERN
# Stops the process recorded in PIDFILE and removes the file. A missing or
# stale pidfile is reported, not treated as an error. PATTERN guards against
# a recycled pid: a live process that does not look like ours is left alone.
stop_pidfile_process() {
  local label="$1" pidfile="$2" pattern="$3" pid
  if [ ! -f "$pidfile" ]; then
    echo "No $label PID file found"
    return 0
  fi
  pid="$(tr -d '[:space:]' < "$pidfile")"
  if ! is_running "$pid"; then
    echo "$label PID file is stale (PID $pid not running); removing it"
    rm -f "$pidfile"
    return 0
  fi
  if ! pid_matches "$pid" "$pattern"; then
    echo "$label PID file points at an unrelated process (PID $pid); removing the file, not the process" >&2
    rm -f "$pidfile"
    return 0
  fi
  stop_pid "$label" "$pid" || return 1
  rm -f "$pidfile"
}

# status_pidfile_process LABEL PIDFILE -> 0 running, 1 not
status_pidfile_process() {
  local label="$1" pidfile="$2" pid
  if [ ! -f "$pidfile" ]; then
    echo "No $label PID file found"
    return 1
  fi
  pid="$(tr -d '[:space:]' < "$pidfile")"
  if is_running "$pid"; then
    echo "$label is running with PID $pid"
    return 0
  fi
  echo "$label is not running (stale PID file, PID $pid)"
  return 1
}

# find_processes PATTERN -> pids, one per line, of this user's processes whose
# command line matches PATTERN. Used to find processes that lost their pidfile.
find_processes() {
  pgrep -u "$(id -u)" -f "$1" 2>/dev/null
}
