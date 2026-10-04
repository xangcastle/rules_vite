#!/usr/bin/env bash
# Starts a vite_run target, asserts the dev server serves the page and its
# entry module, then stops it with SIGTERM and asserts the source tree is
# exactly as before (the driver links node_modules/overlays for its lifetime).
#
# usage: dev_server_smoke.sh <workspace_dir> <vite_run_label> [port] [bazel flags...]
set -euo pipefail

workspace=$1
target=$2
port=${3:-5199}
shift $(($# < 3 ? $# : 3))

cd "$workspace"
log=$(mktemp)
# The whole tree, empty directories and gitignored paths included: git status
# alone misses an empty node_modules/@scope/ the dev server forgot to remove.
tree_snapshot() {
    find . \( -name .git -o -name 'bazel-*' \) -prune -o -print | LC_ALL=C sort
}
tree_before=$(tree_snapshot)

stop_server() {
    pkill -TERM -f "dev_driver.mjs" 2>/dev/null || true
    for _ in $(seq 1 40); do
        pgrep -f "dev_driver.mjs" > /dev/null || return 0
        sleep 0.5
    done
    echo "dev server did not exit after SIGTERM" >&2
    return 1
}
trap 'stop_server || true' EXIT

bazel run "$@" "$target" -- --port "$port" --strictPort > "$log" 2>&1 &
server_pid=$!

url="http://localhost:${port}"
for _ in $(seq 1 180); do
    curl -fsS -o /dev/null "$url/" 2> /dev/null && break
    kill -0 "$server_pid" 2> /dev/null || break
    sleep 1
done

fail() {
    echo "FAIL $target: $1" >&2
    echo "----- dev server log -----" >&2
    tail -n 60 "$log" >&2
    exit 1
}

index=$(curl -fsS "$url/") || fail "index did not respond"
entry=$(grep -o '<script type="module" src="[^"]*"' <<< "$index" | grep -v '/@vite/client' | head -1 | sed 's/.*src="//; s/"$//')
[ -n "$entry" ] || fail "no module entry script in index.html"
entry_status=$(curl -s -o /dev/null -w "%{http_code}" "$url$entry")
[ "$entry_status" = "200" ] || fail "entry $entry answered $entry_status"
echo "OK $target: index 200, entry $entry 200"

stop_server || fail "server did not stop"
trap - EXIT
tree_after=$(tree_snapshot)
[ "$tree_before" = "$tree_after" ] || {
    echo "source tree changed after the dev server exited:" >&2
    diff <(echo "$tree_before") <(echo "$tree_after") >&2 || true
    exit 1
}
echo "OK $target: source tree unchanged after SIGTERM"
