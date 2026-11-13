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

# Locally Harbor gives the containers one shared localhost, but on the portal each has its own.
# So in a task with other services, main must share one's network to reach it at localhost.
compose="$task/environment/docker-compose.yaml"
if [ -f "$compose" ]; then
  # One line for each service but main, then "main <its network_mode>".
  services=$(tr -d '\r' < "$compose" | awk '
    /^[^[:space:]#]/ { in_services = /^services:[[:space:]]*(#.*)?$/; indent = ""; next }
    !in_services || /^[[:space:]]*(#.*)?$/ { next }
    {
      match($0, /^[[:space:]]*/)
      if (indent == "") indent = RLENGTH
      key = $1; gsub(/["\047]/, "", key)
      if (RLENGTH == indent) {
        name = key; sub(/:.*/, "", name)
        if (name != "main") print name
      } else if (name == "main" && key == "network_mode:") {
        mode = $2; gsub(/["\047]/, "", mode)
        print "main " mode
      }
    }')
  others=$(printf '%s\n' "$services" | grep -v '^main ')
  hub=$(printf '%s\n' "$services" | sed -n 's/^main service://p')
  if [ -n "$others" ]; then
    if [ -n "$hub" ] && printf '%s\n' "$others" | grep -qxF "$hub"; then
      echo "PASS  main shares $hub's network"
    else
      echo "FAIL  On the portal each container has its own localhost. Add network_mode: \"service:target\" under main in environment/docker-compose.yaml (use your service's name)"
      failed=1
    fi
  fi
fi

# The write-up goes beside instruction.md. These are the checks the portal makes on it.
write_up="$task/SUBMISSION.md"
# find matches the name exactly, where a Mac's disk would also take submission.md.
if [ -z "$(find "$task" -mindepth 1 -maxdepth 1 -type f -name SUBMISSION.md)" ]; then
  echo "FAIL  $write_up is missing. Copy the template from example-note-share and fill it in"
  failed=1
elif [ "$(wc -c < "$write_up")" -gt 100000 ]; then
  echo "FAIL  $write_up is over 100 KB"
  failed=1
elif [ "$(LC_ALL=C tr -d '\000' < "$write_up" | wc -c)" -ne "$(wc -c < "$write_up")" ] \
  || ! iconv -f UTF-8 -t UTF-8 < "$write_up" > /dev/null 2>&1; then
  echo "FAIL  $write_up isn't UTF-8 text"
  failed=1
elif ! LC_ALL=C grep -q '[^[:space:]]' "$write_up"; then
  echo "FAIL  $write_up is blank"
  failed=1
else
  echo "PASS  SUBMISSION.md"
fi
# The portal also refuses a copy under environment/, which images are built from.
copies=$(find "$task/environment" -iname SUBMISSION.md 2>/dev/null)
if [ -n "$copies" ]; then
  echo "FAIL  these files can't be in the task. Keep SUBMISSION.md only beside instruction.md:"
  printf '%s\n' "$copies" | sed 's/^/        /'
  failed=1
fi

# The run analysis goes beside the task folder. It's written after the model runs, which usually
# come after this script, so these lines only remind you and never fail it.
analysis="$(cd "$task/.." && pwd)/RUN_ANALYSIS.md"
# The SHA-256 of the blank RUN_ANALYSIS.md template. Update it whenever the template changes:
#   tr -d '\r' < RUN_ANALYSIS.md | shasum -a 256
template_sha=91df6506a657234a03b2a55a65126660fe6e83c014f1fcd719befd592da91e0e
sha256() { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256 2>/dev/null; fi | cut -d' ' -f1; }
if [ ! -f "$analysis" ] || ! LC_ALL=C grep -q '[^[:space:]]' "$analysis" \
  || [ "$(tr -d '\r' < "$analysis" | sha256)" = "$template_sha" ]; then
  echo "WARN  RUN_ANALYSIS.md isn't filled in yet. Write it after the model runs: push it with your task (assessment), or load it into Run analysis on the portal."
else
  echo "PASS  RUN_ANALYSIS.md"
fi
inside=$(find "$task" -iname RUN_ANALYSIS.md)
if [ -n "$inside" ]; then
  echo "WARN  Keep RUN_ANALYSIS.md beside the task folder, not in it."
  printf '%s\n' "$inside" | sed 's/^/        /'
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
