#!/bin/bash
# Regression test: the upload scripts must give every uploaded recipe a version
# compatibility range, without disturbing a range the recipe already declares.
#
#   ./test/run-minmaxversion-test.sh
#
# Runs entirely offline - no creds, no flowServer, no network. It extracts the
# version-patching code straight out of uploadRecipe.sh and uploadMetarecipe.sh
# and runs it against fixtures, so the test exercises the shipped code rather
# than a copy of it.
#
# Guards the behaviour IOPS-395 asked for:
#   1. A recipe with no minVersion/maxVersion gets 1.0.0 and 100.0.0, on every
#      environment - not just the old amanda/testing-manual whitelist.
#   2. A recipe that already declares a range keeps it exactly.
#   3. A partial range is completed without touching the half that was there.
#   4. null and empty-string count as missing, not as a declared range.
#   5. --widen overwrites a declared range, replacing what the whitelist did.
#
# uploadRecipe.sh's cases run under all three JSON backends it supports (jq,
# python3, and the awk/grep fallback), because that fallback has its own upsert
# implementation that has to agree with the other two. uploadMetarecipe.sh
# depends on jq unconditionally, so it is tested under jq only.
#
# Not covered: the scripts' staging and upload behaviour. The code under test
# only ever writes to the staged copy it is handed.

set -u

SCRIPTS=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RECIPE_SUBJECT="$SCRIPTS/uploadRecipe.sh"
META_SUBJECT="$SCRIPTS/uploadMetarecipe.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Resolved now, by absolute path: the restricted PATHs below deliberately omit
# the shell, and looking it up through PATH would leave the block unable to run
# at all - which reads as a passing "nothing changed" case.
SH_BIN=$(command -v sh)

failures=0
checks=0

fail() {
    echo "FAIL  $*"
    failures=$((failures + 1))
}

# ---------------------------------------------------------------------------
# Extract the code under test.
# ---------------------------------------------------------------------------

# uploadRecipe.sh patches inline, so take everything from upsert_json's comment
# down to the line before the upload begins.
RECIPE_BLOCK="$WORK/recipe-block.sh"
awk '/^# update or insert a top-level string-valued key/,/^source setEnvForUpload\.sh/' \
    "$RECIPE_SUBJECT" | sed '$d' > "$RECIPE_BLOCK"

if ! grep -q 'json_has_value' "$RECIPE_BLOCK"; then
    echo "FATAL  could not extract the version-patching block from uploadRecipe.sh"
    echo "       (has the block moved or been renamed?)"
    exit 2
fi

# uploadMetarecipe.sh patches through patch_versions(), so take its three
# helpers and call the entry point directly.
META_BLOCK="$WORK/meta-block.sh"
awk '/^# update or insert a top-level string-valued key/,/^CHILD_RECIPES=/' \
    "$META_SUBJECT" | sed '$d' > "$META_BLOCK"
echo 'patch_versions "$STAGED_FLOW/metadata.json" "metadata.json"' >> "$META_BLOCK"

if ! grep -q 'patch_versions()' "$META_BLOCK"; then
    echo "FATAL  could not extract patch_versions from uploadMetarecipe.sh"
    exit 2
fi

# ---------------------------------------------------------------------------
# Backend selection: a PATH holding only the utilities the code needs, so a
# backend can be hidden from `command -v` by simply not linking it in.
# ---------------------------------------------------------------------------
build_path() {
    want_jq="$1"
    want_python="$2"
    bin="$WORK/bin-${want_jq}-${want_python}"
    rm -rf "$bin"
    mkdir -p "$bin"
    for tool in mktemp awk grep sed mv rm cat cp dirname tr; do
        real=$(command -v "$tool" 2>/dev/null) && ln -sf "$real" "$bin/$tool"
    done
    if [ "$want_jq" = jq ]; then
        real=$(command -v jq 2>/dev/null) && ln -sf "$real" "$bin/jq"
    fi
    if [ "$want_python" = python3 ]; then
        real=$(command -v python3 2>/dev/null) && ln -sf "$real" "$bin/python3"
    fi
    echo "$bin"
}

# read_key <key> <file> - print a top-level value, using whatever JSON tool the
# *test* has available (independent of the backend under test). Reports invalid
# JSON explicitly so a mangled file cannot masquerade as a missing key.
read_key() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception as exc:
    print("<<INVALID JSON: %s>>" % exc)
    sys.exit(0)
value = data.get(sys.argv[2], "<<ABSENT>>")
print("<<NULL>>" if value is None else value)
' "$2" "$1"
    else
        jq -r --arg k "$1" 'if has($k) then (.[$k] // "<<NULL>>") else "<<ABSENT>>" end' "$2"
    fi
}

# run_case <block> <backend> <path> <widen> <json> <want-min> <want-max> <name>
run_case() {
    block="$1"
    backend="$2"
    testpath="$3"
    widen="$4"
    body="$5"
    want_min="$6"
    want_max="$7"
    name="$8"

    staged="$WORK/staged-$checks"
    mkdir -p "$staged"
    printf '%s\n' "$body" > "$staged/metadata.json"
    original=$(cat "$staged/metadata.json")

    output=$(PATH="$testpath" STAGED_FLOW="$staged" WIDEN_VERSIONS="$widen" \
        "$SH_BIN" -c '. "$1"' _ "$block" 2>&1)
    ran=$?

    got_min=$(read_key minVersion "$staged/metadata.json")
    got_max=$(read_key maxVersion "$staged/metadata.json")

    checks=$((checks + 1))
    if [ "$ran" -ne 0 ] || echo "$output" | grep -q 'command not found'; then
        fail "[$backend] $name - the code could not run (exit $ran)"
        echo "        output: $output"
    elif [ "$got_min" = "$want_min" ] && [ "$got_max" = "$want_max" ]; then
        echo "PASS  [$backend] $name"
    else
        fail "[$backend] $name"
        echo "        want minVersion='$want_min' maxVersion='$want_max'"
        echo "        got  minVersion='$got_min' maxVersion='$got_max'"
        echo "        input:  $original"
        echo "        result: $(cat "$staged/metadata.json")"
        [ -n "$output" ] && echo "        output: $output"
    fi
}

# Whether the code announced a change should track whether it made one.
# run_message_case <block> <backend> <path> <widen> <json> <yes|no> <name>
run_message_case() {
    block="$1"
    backend="$2"
    testpath="$3"
    widen="$4"
    body="$5"
    should_report="$6"
    name="$7"

    staged="$WORK/msg-$checks"
    mkdir -p "$staged"
    printf '%s\n' "$body" > "$staged/metadata.json"

    output=$(PATH="$testpath" STAGED_FLOW="$staged" WIDEN_VERSIONS="$widen" \
        "$SH_BIN" -c '. "$1"' _ "$block" 2>&1)
    ran=$?

    checks=$((checks + 1))
    if [ "$ran" -ne 0 ] || echo "$output" | grep -q 'command not found'; then
        fail "[$backend] $name - the code could not run (exit $ran)"
        echo "        output: $output"
        return
    fi

    if echo "$output" | grep -qE 'in the uploaded|Widened the uploaded'; then
        reported=yes
    else
        reported=no
    fi

    if [ "$reported" = "$should_report" ]; then
        echo "PASS  [$backend] $name"
    else
        fail "[$backend] $name (reported=$reported, expected=$should_report)"
        echo "        output: $output"
    fi
}

# ---------------------------------------------------------------------------
# Fixtures.
# ---------------------------------------------------------------------------
NEITHER='{
  "id": "test_recipe",
  "name": "Test Recipe"
}'

BOTH='{
  "id": "test_recipe",
  "minVersion": "2.0.0",
  "maxVersion": "2.5.0"
}'

MIN_ONLY='{
  "id": "test_recipe",
  "minVersion": "3.1.4"
}'

MAX_ONLY='{
  "id": "test_recipe",
  "maxVersion": "9.9.9"
}'

EMPTY='{
  "id": "test_recipe",
  "minVersion": "",
  "maxVersion": ""
}'

NULLS='{
  "id": "test_recipe",
  "minVersion": null,
  "maxVersion": null
}'

# suite <block> <backend> <path> - the behaviour both scripts must share.
suite() {
    block="$1"
    backend="$2"
    testpath="$3"

    run_case "$block" "$backend" "$testpath" false "$NEITHER" "1.0.0" "100.0.0" \
        "neither field is injected with the defaults"
    run_case "$block" "$backend" "$testpath" false "$BOTH" "2.0.0" "2.5.0" \
        "a declared range is left untouched"
    run_case "$block" "$backend" "$testpath" false "$MIN_ONLY" "3.1.4" "100.0.0" \
        "minVersion only keeps min, adds max"
    run_case "$block" "$backend" "$testpath" false "$MAX_ONLY" "1.0.0" "9.9.9" \
        "maxVersion only keeps max, adds min"
    run_case "$block" "$backend" "$testpath" false "$EMPTY" "1.0.0" "100.0.0" \
        "empty strings count as missing"
    run_case "$block" "$backend" "$testpath" false "$NULLS" "1.0.0" "100.0.0" \
        "nulls count as missing"

    # --widen restores what the old whitelist did: overwrite unconditionally.
    run_case "$block" "$backend" "$testpath" true "$BOTH" "1.0.0" "100.0.0" \
        "--widen overwrites a declared range"
    run_case "$block" "$backend" "$testpath" true "$NEITHER" "1.0.0" "100.0.0" \
        "--widen also fills in an absent range"
    run_case "$block" "$backend" "$testpath" true "$MIN_ONLY" "1.0.0" "100.0.0" \
        "--widen overwrites a partial range"

    run_message_case "$block" "$backend" "$testpath" false "$NEITHER" yes \
        "reports the patch when it injects one"
    run_message_case "$block" "$backend" "$testpath" false "$BOTH" no \
        "stays quiet when nothing needed patching"
    run_message_case "$block" "$backend" "$testpath" true "$BOTH" yes \
        "reports the widening"
}

echo "==== uploadRecipe.sh"
for spec in "jq:jq:no-python" "python3:no-jq:python3" "awk/grep fallback:no-jq:no-python"; do
    backend="${spec%%:*}"
    rest="${spec#*:}"
    want_jq="${rest%%:*}"
    want_python="${rest##*:}"

    # Skip a backend whose tool this machine does not have.
    if [ "$want_jq" = jq ] && ! command -v jq >/dev/null 2>&1; then
        echo "SKIP  [$backend] jq is not installed"
        continue
    fi
    if [ "$want_python" = python3 ] && ! command -v python3 >/dev/null 2>&1; then
        echo "SKIP  [$backend] python3 is not installed"
        continue
    fi

    echo "--- $backend"
    suite "$RECIPE_BLOCK" "$backend" "$(build_path "$want_jq" "$want_python")"
done

echo "==== uploadMetarecipe.sh"
if command -v jq >/dev/null 2>&1; then
    echo "--- jq"
    suite "$META_BLOCK" "meta/jq" "$(build_path jq no-python)"
else
    echo "SKIP  [meta/jq] jq is not installed"
fi

# ---------------------------------------------------------------------------
# The old whitelist meant the environment decided whether any of this happened.
# ---------------------------------------------------------------------------
echo "==== whitelist removal"
for subject in "$RECIPE_SUBJECT" "$META_SUBJECT"; do
    name=$(basename "$subject")
    checks=$((checks + 1))
    if grep -qE '^[^#]*\b(amanda|testing-manual)\b' "$subject"; then
        fail "$name still branches on an environment whitelist"
        grep -nE '^[^#]*\b(amanda|testing-manual)\b' "$subject" | sed 's/^/        /'
    else
        echo "PASS  no environment whitelist remains in $name"
    fi
done

for pair in "uploadRecipe.sh:$RECIPE_BLOCK" "uploadMetarecipe.sh:$META_BLOCK"; do
    name="${pair%%:*}"
    block="${pair#*:}"
    checks=$((checks + 1))
    if grep -q 'ENVIRONMENT' "$block"; then
        fail "$name's version-patching code still reads ENVIRONMENT"
    else
        echo "PASS  version patching is environment-independent in $name"
    fi
done

# Both scripts must accept --widen.
echo "==== --widen is wired up"
for subject in "$RECIPE_SUBJECT" "$META_SUBJECT"; do
    name=$(basename "$subject")
    checks=$((checks + 1))
    if grep -q -- '--widen)' "$subject" && grep -q 'WIDEN_VERSIONS=true' "$subject"; then
        echo "PASS  $name parses --widen"
    else
        fail "$name does not parse --widen"
    fi
done

echo "---------------------------------------------"
echo "$checks check(s) run"
if [ "$failures" -eq 0 ]; then
    echo "OK"
else
    echo "$failures check(s) failed"
fi

exit "$failures"
