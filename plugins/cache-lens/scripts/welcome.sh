#!/usr/bin/env bash
#
# Renders the Cache Lens welcome page to stdout.
#
# Two callers, deliberately the same text: the SessionStart hook shows it once
# after install, and /cache-lens:explain shows it on demand. A user who dismissed
# it on day one should be able to get the identical page back on day thirty.
#
# The page is organised around what is ON, what is the user's call, and what this
# plugin does not do at all. Installing a plugin normally means it is now
# working, and half of this one is not: the status-line bar needs an edit to the
# user's own settings, and cache warming is not here at all. Someone who believes
# they are covered and is not is worse off than before they installed anything.
#
# Plain text only, no ANSI. The hook delivers this through a hook `systemMessage`
# field, which carries a string rather than a rendered terminal stream, so colour
# codes would arrive as literal escape bytes. The layout therefore has to carry
# the whole design: box rules, small caps, filled and hollow state markers, and
# the same bar glyphs the status line uses, so the legend and the thing on screen
# read as one system.
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

cat <<'EOF'

  Claude Code sends your whole conversation with every request and
  reads it back from the prompt cache. That cache expires after an
  idle gap — an hour on a subscription, five minutes otherwise. Come
  back later than that and your next request pays to rebuild it.

  Cache Lens does not prevent that. It shows you, in time to act.


  ●  ᴏɴ ᴀʟʀᴇᴀᴅʏ                                  nothing to configure

     ᴛʜᴇ ʀᴇsᴜᴍᴇ ᴡᴀʀɴɪɴɢ. Come back to a session that went cold and
     you are told what it costs before the first request leaves:

       ⚑ idle 4d 2h · cache expired · first request re-sends 182k

     That number is normally invisible until after you have spent
     it. This half is working from the moment you installed.


  ○  ɴᴏᴛ ᴏɴ — ʏᴏᴜʀ ᴄᴀʟʟ                            one command away

     ᴛʜᴇ sᴛᴀᴛᴜs-ʟɪɴᴇ ʙᴀʀ. A column that drains with the cache
     lifetime, and a counter of what idling has already cost:

       █ 52m    ▅ 31m    ▂ 12m    ▁ ᴄᴏʟᴅ    ▅ 3m/5ᴍ    ▅ 31m ×2

     This one cannot install itself: a plugin is not allowed to set
     your status line, so it takes an edit to your own settings. The
     setup command merges with the status line you already have and
     backs it up first — it will not replace anything.

       want it    →  run  /cache-lens:setup
       not now    →  do nothing; this page will not ask again


  ✕  ɴᴏᴛ ɪɴ ᴛʜɪs ᴘʟᴜɢɪɴ ᴀᴛ ᴀʟʟ

     ᴄᴀᴄʜᴇ ᴡᴀʀᴍɪɴɢ. Cache Lens sends no pings and makes no requests
     on your behalf. It is an instrument, not a thermostat — it will
     never keep a cache alive for you.

     Five other plugins do exactly that, and the README links them
     along with the reason you might not want one: on a subscription
     each keepalive turn is a real request carrying your full
     context. Watch the ×N counter for a few days first and you will
     know whether warming would pay for itself.


  ᴀɴʏ ᴛɪᴍᴇ

     /cache-lens:setup      install the status-line bar
     /cache-lens:explain    show this page again


  ᴏɴᴇ sᴇᴛᴛɪɴɢ ᴡᴏʀᴛʜ ᴄʜᴇᴄᴋɪɴɢ

     On a subscription the hour-long cache applies only inside your
     plan's included usage. Draw on usage credits and it drops to
     five minutes without saying so. To hold the hour either way,
     in settings.json:

       "env": { "CLAUDE_CODE_PROMPT_CACHE_TTL": "1h" }

     The bar shows 3m/5ᴍ when this has happened to you.
EOF
