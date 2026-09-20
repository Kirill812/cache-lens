#!/usr/bin/env bash
#
# Prints the Cache Lens status-line segment and nothing else.
#
# Reads the status-line JSON on stdin (the same object Claude Code hands any
# statusLine command) and writes one short segment on stdout, for example
# "▅ 31m" or "▁ ᴄᴏʟᴅ". Output is at most 10 visible columns.
#
# It is a segment, not a status line, because most people already have one.
# /cache-lens:setup composes this into whatever is already configured. To use it
# alone, point statusLine straight at it — you just get a bare bar with no model
# or directory next to it.
#
# Exits 0 and prints nothing when there is nothing honest to say: before the
# first API response of a session, on Claude Code older than v2.1.251, on a
# gateway that reports no cache tokens, or without jq. A status line that
# disappears is better than one showing a number it had to invent.
set -u

command -v jq >/dev/null 2>&1 || exit 0

jq -r '
  ["▁","▂","▃","▄","▅","▆","▇","█"] as $bars
  | (.prompt_cache // {}) as $pc
  | if ($pc.caching_observed // false) | not then ""
    else
      # expires_at is an absolute timestamp, so the bar keeps draining between
      # renders even while the session sits idle and no new response arrives.
      (if $pc.ttl == "5m" then 300 else 3600 end) as $span
      | (($pc.expires_at // 0) - now) as $left
      | (if $left > 0 then $left / $span else 0 end) as $frac
      | (if ($pc.misses // 0) > 0 then " ×\($pc.misses)" else "" end) as $miss
      | if $frac <= 0 then "\u001b[2m\($bars[0]) ᴄᴏʟᴅ\($miss)\u001b[0m"
        else
          ([($frac * 8 | ceil), 8] | min) as $cell
          # Minutes are floored, never rounded: claiming 52 minutes of warmth
          # with 51.6 left would be the one direction of error that costs money.
          | (($left / 60) | floor) as $mins
          | (if $mins < 1 then "<1m" else "\($mins)m" end) as $t
          | (if $pc.ttl == "5m" then "\($t)/5ᴍ" else $t end) as $t
          # A 5m TTL is flagged whatever the fraction: three minutes of five is
          # 60% of the window and would otherwise render as a calm bar, hiding
          # the thing worth seeing — that the hour-long window is gone.
          | if $frac < 0.34 or $pc.ttl == "5m"
            then "\u001b[33m\($bars[$cell - 1]) \($t)\($miss)\u001b[0m"
            else "\($bars[$cell - 1]) \($t)\($miss)"
            end
        end
    end
' 2>/dev/null || true
