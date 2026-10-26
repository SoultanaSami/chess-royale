#!/bin/zsh
set -eu
project_dir="${0:A:h}"
godot_bin="${GODOT_BIN:-$HOME/Downloads/Godot-2.app/Contents/MacOS/Godot}"
if [[ ! -x "$godot_bin" ]]; then
  print "Godot not found. Set GODOT_BIN to the Godot executable or open project.godot in Godot 4.7+."
  exit 1
fi
"$godot_bin" --headless --path "$project_dir" --editor --import --quit
exec "$godot_bin" --path "$project_dir" "$@"
