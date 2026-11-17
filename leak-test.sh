#!/bin/sh
# Leak test. Run in place of a task's solution, from inside main, with the agent's network rules on.
# It asks outside web servers for a page. Opening a connection isn't enough to count: Harbor's local
# filter accepts every connection first and drops it afterwards, so only a real reply counts as reached.
# Name lookups aren't counted either: both Harbor's filter and the portal allow them at times.
# On the portal the sandbox's rules change as the agent's turn starts, and a change takes a few
# seconds to hold. Waiting first means every question below is asked under the rules an attempt gets.
sleep "${LEAK_TEST_WAIT:-15}"
ALLOWED="${LEAK_TEST_ALLOWED:-}"          # the task's own service names, to try as a disguise
tool="${LEAK_TEST_TOOL:-}"
if [ -z "$tool" ]; then
  for t in bash python3 curl; do command -v "$t" >/dev/null 2>&1 && { tool=$t; break; }; done
fi

# ask ADDRESS PORT HOST_HEADER PATH -> prints the start of the reply, or nothing
ask() {
  case "$tool" in
    bash) bash -c '
      exec 3<>"/dev/tcp/$1/$2" || exit 1
      printf "GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n" "$4" "$3" >&3
      n=0; while [ $n -lt 40 ] && IFS= read -r -t 6 line <&3; do printf "%s\n" "$line"; n=$((n+1)); done' _ "$@" 2>/dev/null &
      ;;
    python3) python3 -c '
import socket, sys
a, p, h, path = sys.argv[1:]
s = socket.create_connection((a, int(p)), 6); s.settimeout(6)
s.sendall(("GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n" % (path, h)).encode())
sys.stdout.write(s.recv(2000).decode("latin-1"))' "$@" 2>/dev/null &
      ;;
    curl) curl -s -i -m 6 -H "Host: $3" "http://$1:$2$4" 2>/dev/null | head -c 2000 &
      ;;
    *) return 0 ;;
  esac
  pid=$!; ( sleep 9; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 & guard=$!
  wait "$pid" 2>/dev/null; kill "$guard" 2>/dev/null
}

reached=""
try() {  # LABEL ADDRESS PORT HOST PATH MARK: reached when the reply contains MARK
  reply=$(ask "$2" "$3" "$4" "$5")
  if printf '%s' "$reply" | grep -qi "$6"; then
    echo "REACHED  $1"; reached="$reached $1;"
  else
    echo "blocked  $1"
  fi
}

echo "leak test, using $tool"
if [ -z "$tool" ]; then
  echo "VERDICT: untested (no bash, python3 or curl in this image)"; exit 0
fi
try "a public web server by address (1.1.1.1)"        1.1.1.1         80 1.1.1.1     /                  "cloudflare"
try "a public web server by name (example.com)"      example.com     80 example.com /                  "Example Domain"
try "the cloud metadata address (169.254.169.254)"   169.254.169.254 80 169.254.169.254 /metadata/v1/  "^HTTP/"
for name in $ALLOWED; do
  try "a public web server disguised as $name"        1.1.1.1         80 "$name"     /                  "cloudflare"
done
if [ -n "$reached" ]; then echo "VERDICT: fail. Reached:$reached"; else echo "VERDICT: pass. Nothing outside the task was reachable."; fi
