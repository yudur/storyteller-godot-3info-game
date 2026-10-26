#!/bin/sh
# Runs every headless test. Usage: GODOT=/path/to/godot tests/run_all.sh
# test_*.gd extending SceneTree run with --script; test_*.tscn run as scenes
# (needed when the code under test uses autoloads such as SignalBus).
: "${GODOT:?set GODOT to the Godot 4.5 executable}"
status=0
for test in tests/test_*.gd tests/test_*.tscn; do
	case "$test" in
		*.gd) [ -f "${test%.gd}.tscn" ] && continue; args="--script res://$test" ;;
		*) args="res://$test" ;;
	esac
	echo "== $test"
	output=$(timeout 120 "$GODOT" --headless --path . $args 2>&1)
	code=$?
	echo "$output" | grep -E "FAIL|ALL PASSED|checks failed|SCRIPT ERROR" | head -20
	[ $code -eq 0 ] || { echo "exit code $code"; status=1; }
done
exit $status
