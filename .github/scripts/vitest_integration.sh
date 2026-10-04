#!/usr/bin/env bash
set -euo pipefail

workspace=$1
shift
cd "$workspace"
testlogs=$(bazel info "$@" bazel-testlogs 2> /dev/null)

junit_cases() {
    python3 - "$1" "$2" << 'EOF'
import sys
import xml.etree.ElementTree as ElementTree
cases = list(ElementTree.parse(sys.argv[1]).getroot().iter("testcase"))
ran = [case for case in cases if case.find("skipped") is None]
print(len(ran) if sys.argv[2] == "ran" else len(cases))
EOF
}

check() {
    echo "== $1"
}

check "test.log carries no ANSI escapes"
bazel test "$@" //:unit_tests > /dev/null
escapes=$(python3 -c 'import sys; print(open(sys.argv[1], "rb").read().count(b"\x1b["))' "$testlogs/unit_tests/test.log")
[ "$escapes" = "0" ] || { echo "test.log has $escapes ANSI escape sequences"; exit 1; }

check "--test_filter runs only the matching cases"
bazel test "$@" //:unit_tests --test_filter=sums > /dev/null
ran=$(junit_cases "$testlogs/unit_tests/test.xml" ran)
[ "$ran" = "1" ] || { echo "--test_filter=sums ran $ran cases, expected 1"; exit 1; }

echo "OK: vitest integration checks passed"
