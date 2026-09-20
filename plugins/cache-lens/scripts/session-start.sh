#!/usr/bin/env bash
#
# SessionStart hook: the one-time welcome page, and the resume-cost warning.
#
# Claude Code hands a SessionStart hook a few fields that exist for exactly this
# purpose when a session is resumed or forked (v2.1.251+):
#
#   seconds_since_last_response   how long the session sat idle
#   context_tokens                what the first request re-sends as its prompt
#   prompt_cache_likely_expired   whether that re-send will miss the cache
#
# Reporting them before the first request is the whole plugin. Afterwards the
# tokens are already spent and the number is only trivia.
#
# Output goes through the JSON `systemMessage` field, which is what Claude Code
# shows the user. A hook's ordinary stdout is NOT shown: the docs are explicit
# that a successful hook's stdout never reaches the transcript and lands in the
# debug log instead. Printing the page with echo would be silently invisible.
#
# Any failure here must stay invisible. This hook runs at the start of every
# single session; a noisy or slow failure would be worse than no plugin at all.
set -u

command -v jq >/dev/null 2>&1 || exit 0

_input=$(cat)
_root=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}

# CLAUDE_PLUGIN_DATA outlives plugin updates, which is what makes it the right
# place for "this user has already seen the welcome". Falling back to the plugin
# directory would re-show the page after every update.
_data=${CLAUDE_PLUGIN_DATA:-}
if [ -z "$_data" ]; then
    _data="$HOME/.claude/plugins/data/cache-lens"
fi
mkdir -p "$_data" 2>/dev/null || exit 0
_seen="$_data/welcomed"

emit() {
    # jq -Rs turns the raw page into one correctly escaped JSON string; hand
    # assembling this would break on the first quote or backslash in the text.
    printf '%s' "$1" | jq -Rs '{systemMessage: .}' 2>/dev/null || true
    exit 0
}

# --- first run after install: the welcome page, once ---------------------
if [ ! -f "$_seen" ]; then
    : > "$_seen" 2>/dev/null || true
    _page=$(bash "$_root/scripts/welcome.sh" 2>/dev/null) || exit 0
    [ -n "$_page" ] && emit "$_page"
    exit 0
fi

# --- every later resume: what this one costs -----------------------------
_fields=$(printf '%s' "$_input" | jq -r '
    [ (.source // ""),
      (.seconds_since_last_response // -1),
      (.context_tokens // -1),
      (if (.prompt_cache_likely_expired // false) then 1 else 0 end)
    ] | @tsv
' 2>/dev/null) || exit 0

IFS=$(printf '\t') read -r _source _idle _tokens _expired <<EOF
$_fields
EOF

case "${_source:-}" in
    (resume|fork) ;;
    (*) exit 0 ;;
esac

# The fields are absent on older Claude Code and on a transcript with no replies
# yet. Silence beats a warning assembled from -1.
[ "${_idle:-−1}" -ge 0 ] 2>/dev/null || exit 0
[ "${_tokens:-−1}" -ge 0 ] 2>/dev/null || exit 0

# A warm resume costs nothing worth interrupting for. Only speak when the
# rebuild is actually going to happen.
[ "${_expired:-0}" = "1" ] || exit 0

# idle: the largest two units, so "4d 2h" rather than "98h" or "4d 2h 11m 6s"
_d=$(( _idle / 86400 ))
_h=$(( (_idle % 86400) / 3600 ))
_m=$(( (_idle % 3600) / 60 ))
if   [ "$_d" -gt 0 ]; then _idle_h="${_d}d ${_h}h"
elif [ "$_h" -gt 0 ]; then _idle_h="${_h}h ${_m}m"
else                       _idle_h="${_m}m"
fi

if [ "$_tokens" -ge 1000 ]; then
    _tok_h="$(( _tokens / 1000 ))k"
else
    _tok_h="$_tokens"
fi

emit "⚑ cache-lens — this resume rebuilds the prompt cache
  idle $_idle_h · cache expired · first request re-sends $_tok_h tokens"
