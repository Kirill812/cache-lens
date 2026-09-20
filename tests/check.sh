#!/usr/bin/env bash
#
# Cache Lens self-check. No framework: feeds real input to the real scripts and
# asserts what comes back.
#
#   bash tests/check.sh
#
# Covers the two things that are expensive to get wrong — a status-line segment
# that renders a number it made up, and a SessionStart hook that talks when it
# should stay quiet. The hook runs at the start of every session, so "silent
# unless it has something true to say" is a correctness property, not a taste.
set -u

_here=$(cd "$(dirname "$0")" && pwd)
_plugin="$_here/../plugins/cache-lens"
_seg="$_plugin/scripts/statusline-segment.sh"
_hook="$_plugin/scripts/session-start.sh"
_now=$(date +%s)
_fail=0

pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n       want %s\n       got  %s\n' "$1" "$2" "$3"; _fail=$(( _fail + 1 )); }

strip() { sed "s/$(printf '\033')\[[0-9;]*m//g"; }

# --- the status-line segment ---------------------------------------------
printf 'status-line segment\n'

seg() {
    printf '{"prompt_cache":{"caching_observed":true,"warm":%s,"ttl":"%s","expires_at":%s,"misses":%s}}' \
        "$2" "$3" "$4" "$5" | bash "$_seg" | strip
}

check_seg() {
    _got=$(seg "$@")
    case "$_got" in
        (*"$6"*) pass "$1" ;;
        (*) fail "$1" "$6" "$_got" ;;
    esac
}
#         label              warm   ttl   expires_at            misses  expect
check_seg 'near full'        true   1h    $(( _now + 3150 ))    0       '▇ 52m'
check_seg 'half drained'     true   1h    $(( _now + 1890 ))    0       '▅ 31m'
check_seg 'nearly cold'      true   1h    $(( _now + 750  ))    0       '▂ 12m'
check_seg 'expired'          false  1h    $(( _now - 600  ))    0       '▁ ᴄᴏʟᴅ'
check_seg 'ttl collapsed'    true   5m    $(( _now + 210  ))    0       '3m/5ᴍ'
check_seg 'misses counted'   true   1h    $(( _now + 1890 ))    2       '×2'
check_seg 'sub-minute'       true   1h    $(( _now + 20   ))    0       '<1m'

# Colour is the signal for "act now", so assert the escape is really emitted
# rather than only that the text is right.
_raw=$(printf '{"prompt_cache":{"caching_observed":true,"warm":true,"ttl":"1h","expires_at":%s,"misses":0}}' \
       $(( _now + 750 )) | bash "$_seg")
case "$_raw" in
    (*$(printf '\033')'[33m'*) pass 'low state is yellow' ;;
    (*) fail 'low state is yellow' 'ESC[33m' "$_raw" ;;
esac
_raw=$(printf '{"prompt_cache":{"caching_observed":true,"warm":true,"ttl":"1h","expires_at":%s,"misses":0}}' \
       $(( _now + 3150 )) | bash "$_seg")
case "$_raw" in
    (*$(printf '\033')'['*) fail 'healthy state is uncoloured' 'no escape' "$_raw" ;;
    (*) pass 'healthy state is uncoloured' ;;
esac

# No cache data must render nothing at all, not a zeroed bar.
_quiet=$(printf '{"prompt_cache":{"caching_observed":false}}' | bash "$_seg")
[ -z "$_quiet" ] && pass 'silent without cache data' \
    || fail 'silent without cache data' '(empty)' "$_quiet"
_quiet=$(printf '{}' | bash "$_seg")
[ -z "$_quiet" ] && pass 'silent on absent field' \
    || fail 'silent on absent field' '(empty)' "$_quiet"

# --- the SessionStart hook -----------------------------------------------
printf '\nSessionStart hook\n'

_tmp=$(mktemp -d)
trap 'rm -rf "$_tmp"' EXIT
hook() { printf '%s' "$1" | CLAUDE_PLUGIN_ROOT="$_plugin" CLAUDE_PLUGIN_DATA="$_tmp" bash "$_hook"; }

# First session after install: the welcome page, exactly once.
_first=$(hook '{"source":"startup"}')
case "$_first" in
    (*'ᴄᴀᴄʜᴇ ʟᴇɴs'*) pass 'welcomes on first run' ;;
    (*) fail 'welcomes on first run' 'the welcome page' "$_first" ;;
esac
case "$_first" in
    (*'"systemMessage"'*) pass 'welcome uses systemMessage' ;;
    (*) fail 'welcome uses systemMessage' '"systemMessage" key' "$_first" ;;
esac
_second=$(hook '{"source":"startup"}')
[ -z "$_second" ] && pass 'never welcomes twice' \
    || fail 'never welcomes twice' '(empty)' "$_second"

# A stale resume is the case the plugin exists for.
_stale=$(hook '{"source":"resume","seconds_since_last_response":353000,"context_tokens":182340,"prompt_cache_likely_expired":true}')
case "$_stale" in
    (*'idle 4d 2h'*) pass 'reports idle time' ;;
    (*) fail 'reports idle time' 'idle 4d 2h' "$_stale" ;;
esac
case "$_stale" in
    (*'182k'*) pass 'reports re-sent tokens' ;;
    (*) fail 'reports re-sent tokens' '182k' "$_stale" ;;
esac

# Everything below must stay silent. A hook that cries wolf at every session
# start gets muted, and then the one warning that mattered is muted too.
quiet_case() {
    _got=$(hook "$2")
    [ -z "$_got" ] && pass "$1" || fail "$1" '(empty)' "$_got"
}
quiet_case 'silent when cache still warm' \
    '{"source":"resume","seconds_since_last_response":120,"context_tokens":182340,"prompt_cache_likely_expired":false}'
quiet_case 'silent on a fresh start' \
    '{"source":"startup"}'
quiet_case 'silent when fields absent (old Claude Code)' \
    '{"source":"resume"}'
quiet_case 'silent on a clear' \
    '{"source":"clear","prompt_cache_likely_expired":true}'

# The hook must emit valid JSON or Claude Code treats it as a non-blocking error.
if printf '%s' "$_stale" | jq -e . >/dev/null 2>&1; then
    pass 'emits valid JSON'
else
    fail 'emits valid JSON' 'parseable' "$_stale"
fi

printf '\n'
if [ "$_fail" -eq 0 ]; then printf 'all passed\n'; exit 0
else printf '%d failed\n' "$_fail"; exit 1; fi
