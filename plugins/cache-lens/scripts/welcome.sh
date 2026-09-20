#!/usr/bin/env bash
#
# Renders the Cache Lens welcome page to stdout.
#
# Two callers, deliberately the same text: the SessionStart hook shows it once
# after install, and /cache-lens:explain shows it on demand. A user who dismissed
# it on day one should be able to get the identical page back on day thirty.
#
# Plain text only, no ANSI. The hook delivers this through a hook `systemMessage`
# field, which carries a string rather than a rendered terminal stream, so colour
# codes would arrive as literal escape bytes. The layout therefore has to carry
# the whole design: box rules, small caps, and the same bar glyphs the status
# line uses, so the legend below and the thing on screen are visibly one system.
#
# Every line is kept inside 70 columns. Terminals narrower than that wrap, and a
# wrapped box border looks broken rather than merely narrow.
set -u

VERSION=${CACHE_LENS_VERSION:-1.0.0}

# The title bar is assembled rather than typed out, so the right border stays
# put when the version string grows a digit. 66 is the width inside the corners;
# the label is 12 columns ("  " plus ten small-cap letters, one column each).
_w=66
_ver="v$VERSION"
_pad=$(( _w - 12 - ${#_ver} - 2 ))
_rule=$(printf '─%.0s' $(seq 1 $_w))
printf '  ╭%s╮\n' "$_rule"
printf '  │  ᴄᴀᴄʜᴇ ʟᴇɴs%*s%s  │\n' "$_pad" '' "$_ver"
printf '  ╰%s╯\n' "$_rule"

cat <<EOF

  Claude Code sends your whole conversation with every request and
  reads it back from the prompt cache. That cache expires after an
  idle gap — an hour on a subscription, five minutes otherwise. Come
  back later than that and your next request pays to rebuild it.

  Cache Lens does not prevent that. It makes it visible, in time to
  do something about it.


  ▁▂▃▄▅▆▇█   ᴛʜᴇ sᴛᴀᴛᴜs ʟɪɴᴇ

     █ 52m      the cached prefix is good for another 52 minutes
     ▅ 31m      draining; the column is the share of the TTL left
     ▂ 12m      under a third remaining, shown in yellow
     ▁ ᴄᴏʟᴅ     expired — your next request rebuilds the prefix
     ▅ 3m/5ᴍ    the window itself collapsed to five minutes
     ▅ 31m ×2   ×N counts misses this session has already paid for

     Not installed yet: run /cache-lens:setup. It reads whatever
     status line you already have and adds to it, rather than
     replacing it.


  ⚑   ᴛʜᴇ ʀᴇsᴜᴍᴇ ᴡᴀʀɴɪɴɢ                          already working

     Resume a session that has been sitting idle and Cache Lens
     speaks up before the first request leaves:

       idle 4d 2h · cache expired · first request re-sends 182k

     That number is normally invisible until after you have spent
     it. Seeing it first is the whole point of this plugin.


  ᴄᴏᴍᴍᴀɴᴅs

     /cache-lens:setup      add the segment to your status line
     /cache-lens:explain    show this page again


  ᴏɴᴇ sᴇᴛᴛɪɴɢ ᴡᴏʀᴛʜ ᴄʜᴇᴄᴋɪɴɢ

     On a subscription the hour-long cache applies only while you
     are inside your plan's included usage. Once you draw on usage
     credits it drops to five minutes without saying so. To hold
     the hour either way, in your settings.json:

       "env": { "CLAUDE_CODE_PROMPT_CACHE_TTL": "1h" }

     Cache Lens shows 3m/5ᴍ when this has happened to you.
EOF
