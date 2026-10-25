#!/bin/sh
printf '\033c\033]0;%s\a' Storyteller Snct 3info
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Storyteller Snct 3info.x86_64" "$@"
