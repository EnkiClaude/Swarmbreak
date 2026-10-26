#!/usr/bin/env bash
# Runs every headless check: import, unit tests, scenario tests, benchmark.
# Usage: GODOT=/path/to/godot tools/check.sh
# Fails if any step exits non-zero or logs a script or engine error.
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG_DIR="${LOG_DIR:-ci-logs}"
mkdir -p "$LOG_DIR"
ERROR_PATTERN='SCRIPT ERROR|Parse Error|ERROR:'
status=0

run_step() {
	local name="$1"
	shift
	local log="$LOG_DIR/$name.log"
	echo "::group::$name"
	"$GODOT" --headless --path . "$@" 2>&1 | tee "$log"
	local code=${PIPESTATUS[0]}
	echo "::endgroup::"
	if [ "$code" -ne 0 ]; then
		echo "::error::$name exited with code $code"
		status=1
	fi
	# Headless runs use the dummy renderer, which draws nothing and logs
	# spurious errors from its own stubs; those are reported but not fatal.
	local errors
	errors=$(awk -v pat="$ERROR_PATTERN" '
		$0 ~ pat { err = $0; getline nxt
			if (nxt ~ /servers\/rendering\/dummy\//) { ignored++; next }
			print err; print nxt }
		END { if (ignored) printf "(ignored %d dummy-renderer errors)\n", ignored > "/dev/stderr" }' "$log")
	if [ -n "$errors" ]; then
		echo "::error::$name logged errors:"
		echo "$errors"
		status=1
	fi
}

run_step import --import
run_step unit -s res://tests/run_tests.gd
run_step scenarios --fixed-fps 60 -s res://tests/run_scenarios.gd
BENCH_OUT="$LOG_DIR/benchmark.md" run_step benchmark -s res://tests/benchmark.gd

exit $status
