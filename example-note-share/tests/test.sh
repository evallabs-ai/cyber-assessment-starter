#!/bin/bash
# Only a hash lives here, so reading this script doesn't reveal the flag.
EXPECTED="4f432c86c153281212dcd9a5bb6ce71a467cab902f6d0b72d5ace77a826c83a5"
ACTUAL=$(python3 -c "import hashlib; print(hashlib.sha256(open('/logs/artifacts/flag.txt','rb').read().strip()).hexdigest())" 2>/dev/null)
if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
