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

snapshot=src/lib/__snapshots__/snapshot_update.test.js.snap
committed_snapshot=$(git show "HEAD:$(git rev-parse --show-prefix)$snapshot")

check "bazel run -u recreates a deleted snapshot in the source tree"
rm "$snapshot"
bazel run "$@" //:unit_tests -- -u src/lib/snapshot_update.test.js > /dev/null
[ -f "$snapshot" ] || { echo "$snapshot was not written back"; exit 1; }
[ "$(cat "$snapshot")" = "$committed_snapshot" ] || { echo "$snapshot differs from the committed one"; exit 1; }

check "bazel run -u rewrites a stale snapshot in the source tree"
sed -i.bak 's/"total": 5/"total": 999/' "$snapshot" && rm "$snapshot.bak"
bazel run "$@" //:unit_tests -- -u src/lib/snapshot_update.test.js > /dev/null
[ "$(cat "$snapshot")" = "$committed_snapshot" ] || { echo "$snapshot was not rewritten"; exit 1; }

check "bazel test refuses -u instead of losing the update in the stage"
if bazel test "$@" //:unit_tests --test_arg=-u > /dev/null 2>&1; then
    echo "bazel test --test_arg=-u passed; it must fail and point to bazel run"
    exit 1
fi
grep -q "bazel run //:unit_tests -- -u" "$testlogs/unit_tests/test.log" || { echo "missing the bazel run hint in test.log"; exit 1; }

check "GITHUB_ACTIONS annotations point at the repository file and line"
annotation_log=$(mktemp)
if GITHUB_ACTIONS=true bazel test "$@" //:annotation_fixture_test --test_output=errors \
    --test_env=GITHUB_ACTIONS --test_env=RULES_VITE_ANNOTATION_PREFIX=e2e/react > "$annotation_log" 2>&1; then
    echo "annotation_fixture_test passed; it must fail on purpose"
    exit 1
fi
grep -q '^::error file=e2e/react/fixtures/annotation.fixture.js,.*line=4,' "$annotation_log" || {
    echo "no ::error annotation for e2e/react/fixtures/annotation.fixture.js line 4"
    grep '^::error' "$annotation_log" || true
    exit 1
}

check "reports vitest writes to disk end up in test.outputs"
bazel test "$@" //:file_reports_test > /dev/null
python3 - "$testlogs/file_reports_test/test.outputs" << 'PYTHON'
import pathlib
import sys
import zipfile
outputs = pathlib.Path(sys.argv[1])
names = {str(path.relative_to(outputs)) for path in outputs.rglob("*") if path.is_file()}
for archive in outputs.glob("*.zip"):
    names |= set(zipfile.ZipFile(archive).namelist())
missing = [name for name in ("reports/vitest.json", "reports/html/index.html") if name not in names]
if missing:
    sys.exit(f"missing from test.outputs: {', '.join(missing)}")
PYTHON

check "bazel coverage reports vitest's lcov per source file"
bazel coverage "$@" //:unit_tests --instrument_test_targets --combined_report=lcov > /dev/null
combined_report="$(bazel info "$@" output_path 2> /dev/null)/_coverage/_coverage_report.dat"
for report in "$testlogs/unit_tests/coverage.dat" "$combined_report"; do
    python3 - "$report" << 'PYTHON'
import sys
records = {}
current = None
for line in open(sys.argv[1]):
    line = line.strip()
    if line.startswith("SF:"):
        current = records.setdefault(line[3:], {})
    elif current is not None and line.startswith(("LH:", "LF:")):
        current[line[:2]] = int(line[3:])
calc = records.get("src/lib/calc.js")
if calc != {"LH": 6, "LF": 6}:
    sys.exit(f"{sys.argv[1]}: src/lib/calc.js coverage is {calc}, expected 6/6 lines hit")
PYTHON
done

echo "OK: vitest integration checks passed"
