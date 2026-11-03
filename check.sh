#!/bin/bash
# Usage: ./check.sh <task-folder>
# Runs the checks we run first. All of them must pass before you submit.
set -u

task="${1:?Usage: ./check.sh <task-folder>}"
task="${task%/}"
[ -f "$task/task.toml" ] || { echo "No task.toml in $task"; exit 2; }
[ -f "$task/wrong_solution/solve.sh" ] || { echo "Missing $task/wrong_solution/solve.sh"; exit 2; }
command -v harbor >/dev/null || { echo "Harbor isn't installed. Run: uv tool install harbor==0.25.0"; exit 2; }
docker info >/dev/null 2>&1 || { echo "Docker isn't running."; exit 2; }
# Tasks run offline. This is the same kernel test Harbor uses before it will block internet access.
docker run --rm alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 \
  sh -c "[ ! -f /proc/config.gz ] || zcat /proc/config.gz | grep -qE '^CONFIG_NFT_FIB_INET=[ym]'" >/dev/null 2>&1 \
  || { echo "Your Docker can't block internet access, which these tasks need. Update Docker and try again."; exit 2; }

work=$(mktemp -d)
failed=0

# Runs one agent, optionally several times, and checks the score of every run.
expect() {
  local label="$1" path="$2" agent="$3" want="$4" runs="${5:-1}"
  harbor run -p "$path" -a "$agent" -k "$runs" -o "$work/jobs" --job-name "$label" -y > "$work/$label.log" 2>&1
  local scores shown matches every=""
  # One score per run, trimmed, one per line.
  scores=$(find "$work/jobs/$label" -path '*/verifier/reward.txt' -exec sh -c 'tr -d "[:space:]" < "$1"; echo' _ {} \; 2>/dev/null)
  shown=$(printf '%s' "$scores" | tr '\n' ' ')
  matches=$(printf '%s\n' "$scores" | grep -cx "$want")
  [ "$runs" -gt 1 ] && every=" in all $runs runs"
  # A crash can still leave a score behind, so it never counts as a pass.
  if [ -n "$(find "$work/jobs/$label" -name exception.txt 2>/dev/null)" ]; then
    echo "FAIL  $label crashed (log: $work/$label.log)"
    failed=1
  elif [ "$matches" = "$runs" ]; then
    echo "PASS  $label scored $want$every"
  else
    echo "FAIL  $label scored '${shown:-no score}', expected $want$every (log: $work/$label.log)"
    failed=1
  fi
}

if harbor lint "$task" > "$work/lint.log" 2>&1; then
  echo "PASS  lint"
else
  echo "FAIL  lint (see below)"
  cat "$work/lint.log"
  if grep -q "could not load this configuration" "$work/lint.log"; then
    echo "If docker-compose.yaml looks right, your Docker Compose may be too old. Update Docker and try again."
  fi
  failed=1
fi

# A model should fail because the task is hard, not because it ran out of time.
min_timeout=1800
timeout=$(awk '
  /^[[:space:]]*\[/ { in_agent = /^[[:space:]]*\[agent\][[:space:]]*(#.*)?$/ }
  in_agent && /^[[:space:]]*timeout_sec[[:space:]]*=/ { sub(/^[^=]*=/, ""); print $0 + 0; exit }
' "$task/task.toml")
if [ -z "$timeout" ]; then
  echo "FAIL  agent timeout isn't set. Set [agent] timeout_sec in task.toml to $min_timeout or more"
  failed=1
elif awk -v t="$timeout" -v min="$min_timeout" 'BEGIN { exit !(t + 0 >= min + 0) }'; then
  echo "PASS  agent timeout is ${timeout}s"
else
  echo "FAIL  agent timeout is ${timeout}s. Set [agent] timeout_sec in task.toml to $min_timeout or more"
  failed=1
fi

# We test a clean clone, so anything that isn't committed won't be there.
if git -C "$task" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  uncommitted=$(git -C "$task" status --porcelain --ignored --untracked-files=all -- . | grep -v '\.DS_Store$' | cut -c4-)
  if [ -n "$uncommitted" ]; then
    echo "WARN  these changes aren't committed, so a clean clone won't have them:"
    printf '%s\n' "$uncommitted" | sed 's/^/        /'
  fi
fi

# Three runs of the reference catch a flaky check.
expect reference "$task" oracle 1 3
expect do-nothing "$task" nop 0

# Runs the wrong solution through the oracle agent, in a temporary copy.
copy="$work/wrong/$(basename "$task")"
mkdir -p "$work/wrong"
cp -R "$task" "$copy"
cp "$copy/wrong_solution/solve.sh" "$copy/solution/solve.sh"
expect wrong-solution "$copy" oracle 0

if [ "$failed" = 0 ]; then
  echo "All checks passed. Next: test a frontier model, then submit."
else
  echo "Fix the failures above before submitting."
fi
exit "$failed"
