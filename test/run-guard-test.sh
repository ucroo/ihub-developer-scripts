#!/bin/bash
# Regression test: when a script's argument check or flow-token check fails,
# the script must stop there - no request sent, non-zero exit status.
#
#   ./test/run-guard-test.sh
#
# Runs entirely offline - no creds, no flowServer, no network. curl and zip are
# replaced by stubs on PATH, and HOME points at a throwaway creds directory.
#
# Guards the bug where those checks used a top-level `return 1`. In a script
# that is executed rather than sourced, `return` outside a function is an error
# that does not stop the script, so it printed the usage message and carried
# on: `deleteFlow.sh` with no arguments sent DELETE .../flows/ to the local
# server and exited 0.
#
# Also checks the other half of the contract: a script that is *sourced*, as
# repushAllConfig.sh does, must hand control back to its caller rather than
# exit it.

set -u

SCRIPTS=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failures=0
checks=0

fail() {
    echo "FAIL  $*"
    failures=$((failures + 1))
}

# ---------------------------------------------------------------------------
# Sandbox: a creds directory holding only local.token, so a script that falls
# through a failed check finds a usable token and reaches curl - which is the
# dangerous path. Any other environment name has no token.
# ---------------------------------------------------------------------------
export HOME="$WORK/home"
mkdir -p "$HOME/creds"
echo "TEST_TOKEN" > "$HOME/creds/local.token"

STUBS="$WORK/stubs"
mkdir -p "$STUBS"
CURL_LOG="$WORK/curl.log"
export CURL_LOG

cat > "$STUBS/curl" <<'EOF'
#!/bin/bash
echo "curl $*" >> "$CURL_LOG"
printf 200
EOF
cat > "$STUBS/zip" <<'EOF'
#!/bin/bash
exit 0
EOF
cat > "$STUBS/tput" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$STUBS/curl" "$STUBS/zip" "$STUBS/tput"

RUN_DIR="$WORK/repo"
mkdir -p "$RUN_DIR"

# run_script <script> [args...] - execute a script the way a user does, from
# the root of a partner repo with the scripts on PATH. Sets $status and $output
# and leaves the stub curl's log in $CURL_LOG.
run_script() {
    local script="$1"
    shift
    rm -f "$CURL_LOG"
    output=$(cd "$RUN_DIR" && env -u FLOW_TOKEN PATH="$STUBS:$SCRIPTS:$PATH" \
        bash "$SCRIPTS/$script" "$@" 2>&1)
    status=$?
}

# expect_stopped <label> <script> [args...]
expect_stopped() {
    local label="$1"
    shift
    checks=$((checks + 1))
    run_script "$@"
    if [ -s "$CURL_LOG" ]; then
        fail "$label: sent a request after the check failed: $(head -1 "$CURL_LOG")"
    elif [ "$status" -eq 0 ]; then
        fail "$label: exited 0 after the check failed"
    elif grep -q "can only \`return'" <<<"$output"; then
        fail "$label: top-level return did not stop the script"
    else
        echo "PASS  $label"
    fi
}

# Scripts taking <name> [environment]. The token case passes an environment
# that has no token file.
NAME_ENV_SCRIPTS="
decrypt.sh
decryptFile.sh
deleteBundle.sh
deleteFlow.sh
deleteFlowTriggerer.sh
deleteResourceCollection.sh
deleteSharedConfig.sh
downloadBundle.sh
encrypt.sh
encryptFile.sh
exportKey.sh
importKey.sh
triggerFlow.sh
uploadConfigPanel.sh
uploadFlow.sh
uploadResourceCollection.sh
uploadResourceCollectionJson.sh
uploadSharedConfig.sh
uploadTrigger.sh
"

# Scripts taking two names before [environment].
TWO_NAME_SCRIPTS="
deleteResource.sh
uploadRecipeAnswers.sh
uploadSharedConfigFragment.sh
"

# Scripts taking only [environment]; they have no argument check to fail.
ENV_ONLY_SCRIPTS="
generateNewEncryptionKey.sh
getEncryptionKey.sh
getSharedConfigEncrypted.sh
"

echo "==== no arguments"
for script in $NAME_ENV_SCRIPTS $TWO_NAME_SCRIPTS uploadMetarecipe.sh; do
    expect_stopped "$script with no arguments" "$script"
done

echo "==== too many arguments"
for script in $NAME_ENV_SCRIPTS; do
    expect_stopped "$script with three arguments" "$script" one local extra
done
expect_stopped "deleteResource.sh with four arguments" deleteResource.sh one two local extra
expect_stopped "uploadRecipeAnswers.sh with four arguments" uploadRecipeAnswers.sh one two local extra
expect_stopped "uploadSharedConfigFragment.sh with five arguments" uploadSharedConfigFragment.sh one two local four extra
expect_stopped "uploadMetarecipe.sh with three arguments" uploadMetarecipe.sh one local extra
expect_stopped "uploadMetarecipe.sh with an unknown option" uploadMetarecipe.sh one --bogus

echo "==== no token for the environment"
for script in $NAME_ENV_SCRIPTS; do
    expect_stopped "$script without a token" "$script" thing notoken
done
expect_stopped "deleteResource.sh without a token" deleteResource.sh collection resource notoken
expect_stopped "uploadRecipeAnswers.sh without a token" uploadRecipeAnswers.sh recipe answers notoken
expect_stopped "uploadSharedConfigFragment.sh without a token" uploadSharedConfigFragment.sh fragment.json name notoken
for script in $ENV_ONLY_SCRIPTS; do
    expect_stopped "$script without a token" "$script" notoken
done

echo "==== sourced callers keep running"
# repushAllConfig.sh sources uploadSharedConfig.sh / uploadFlow.sh /
# uploadTrigger.sh in a loop, so a failed check there must return to it.
for script in uploadSharedConfig.sh uploadFlow.sh uploadTrigger.sh; do
    checks=$((checks + 1))
    rm -f "$CURL_LOG"
    output=$(cd "$RUN_DIR" && env -u FLOW_TOKEN PATH="$STUBS:$SCRIPTS:$PATH" \
        bash -c 'subject="$1"; set --; source "$subject"; echo "rc=$?"; echo "caller still running"' _ "$SCRIPTS/$script" 2>&1)
    if ! grep -q "caller still running" <<<"$output"; then
        fail "sourcing $script with no arguments exited its caller"
    elif ! grep -q "rc=1" <<<"$output"; then
        fail "sourcing $script with no arguments did not return 1"
    elif [ -s "$CURL_LOG" ]; then
        fail "sourcing $script with no arguments sent a request"
    else
        echo "PASS  sourcing $script with no arguments returns 1 to its caller"
    fi
done

echo "==== valid calls still reach the server"
# Control: proves the stubs are wired up, so the checks above are not passing
# merely because curl could never have been reached.
for script in uploadFlow.sh deleteFlow.sh; do
    checks=$((checks + 1))
    run_script "$script" thing
    if [ -s "$CURL_LOG" ]; then
        echo "PASS  $script thing (local) sends its request"
    else
        fail "$script thing (local) never reached curl: $output"
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
