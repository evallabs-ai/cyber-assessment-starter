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

work=$(mktemp -d)
failed=0

# Runs one agent and checks the score it gets.
expect() {
  local label="$1" path="$2" agent="$3" want="$4"
  harbor run -p "$path" -a "$agent" -o "$work/jobs" --job-name "$label" -y > "$work/$label.log" 2>&1
  local reward
  reward=$(find "$work/jobs/$label" -name reward.txt -exec cat {} \; 2>/dev/null | head -1)
  # A crash can still leave a score behind, so it never counts as a pass.
  if [ -n "$(find "$work/jobs/$label" -name exception.txt 2>/dev/null)" ]; then
    echo "FAIL  $label crashed (log: $work/$label.log)"
    failed=1
  elif [ "$reward" = "$want" ]; then
    echo "PASS  $label scored $reward"
  else
    echo "FAIL  $label scored '${reward:-no score}', expected $want (log: $work/$label.log)"
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

expect reference "$task" oracle 1
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
