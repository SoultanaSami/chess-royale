#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -x .runtime/bin/node ]; then
  export PATH="$PWD/.runtime/bin:$PATH"
fi
if ! command -v node >/dev/null 2>&1; then
  echo 'Node.js 24 oder neuer wird benötigt: https://nodejs.org'
  exit 1
fi
exec node src/server.js
