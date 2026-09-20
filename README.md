# Cache Lens

**Claude Code re-sends your entire conversation with every request.** Normally
it reads that back from the prompt cache for a tenth of the price. But the cache
expires after an idle gap — an hour on a subscription, five minutes otherwise —
and the first request after that gap pays full freight to rebuild it.

You never see this happen. You just notice a turn that took longer, in a session
you had left open, and move on.

Cache Lens shows you. It does not ping anything, spend anything, or change how
your sessions work.

```
  ▅ 31m
```

---

## Two things, both small

### A bar that drains

Your status line gets one short segment showing how much of the cache lifetime
is left. The column is the share of the TTL remaining, so it falls as the
session sits idle.

```
  █ 52m      the cached prefix is good for another 52 minutes
  ▅ 31m      draining
  ▂ 12m      under a third remaining — yellow
  ▁ ᴄᴏʟᴅ     expired; your next request rebuilds the prefix
  ▅ 3m/5ᴍ    the window itself collapsed to five minutes
  ▅ 31m ×2   ×N counts misses this session has already paid for
```

`×N` is the one to watch. It counts requests that re-processed content the cache
already held, which is exactly the money an idle gap costs you. If it stays at
zero, you do not have this problem and can stop reading.

### A warning before the bill

Resume a session that has been sitting idle and Cache Lens speaks up *before the
first request goes out*:

```
  ⚑ cache-lens — this resume rebuilds the prompt cache
    idle 4d 2h · cache expired · first request re-sends 182k tokens
```

Claude Code hands `SessionStart` hooks three purpose-built fields on a resume:
`seconds_since_last_response`, `context_tokens`, and
`prompt_cache_likely_expired`. This is just those fields, said out loud, at the
only moment the number is still actionable. Afterwards it is trivia.

This half needs no setup and starts working the moment the plugin is enabled.

---

## Install

```
/plugin marketplace add Kirill812/cache-lens
/plugin install cache-lens@cache-lens
```

Then, for the status-line bar:

```
/cache-lens:setup
```

And whenever you want the intro page back:

```
/cache-lens:explain
```

### Why the status line needs a command

A plugin cannot set `statusLine` on your behalf — a plugin's own `settings.json`
supports only the `agent` and `subagentStatusLine` keys. So `/cache-lens:setup`
edits your configuration instead, and it is written to **merge with whatever
status line you already have** rather than replace it: it reads your existing
script, backs it up, and appends the segment following the conventions already
in the file. If you have no status line, it writes a minimal one.

If you would rather do it by hand, the renderer is a standalone script that
reads the status-line JSON on stdin and prints one short string:

```bash
segment=$(printf '%s' "$input" | bash /path/to/cache-lens/scripts/statusline-segment.sh)
```

---

## Requirements

- Claude Code **v2.1.251 or later** — that is when the status line's
  `prompt_cache` object and the resume fields landed. On older versions the
  plugin stays silent rather than guessing.
- `jq`.
- A running session keeps the binary it started with, so sessions launched
  before you updated will show nothing until restarted.

---

## What this deliberately does not do

**It does not keep your cache warm.** Several plugins do that by sending a cheap
turn every N minutes to reset the TTL — [claude-keepwarm][kw],
[claude-cache-warm][cw], [claude-code-cache-warmer][ccw], [cache-tax][ct],
[cache-keepalive][ka]. The trick is sound and documented: a cache hit refreshes
the lifetime, and Anthropic describes pre-warming
[in the API docs][prewarm].

It is also not free, and whether it pays depends on how you are billed:

- **On an API key or usage credits**, you spend one cache read (0.1× base input)
  to avoid one cache write (2× base input for the 1-hour TTL). That arithmetic
  is strongly in your favour.
- **On a Pro or Max subscription**, every keepalive turn is a real request
  carrying your full context, and it draws on your plan usage. Anthropic does
  not document how subscription quota is computed, so nobody — including this
  README — can tell you the exact break-even. Multiply by the number of sessions
  you leave open and the honest answer is "measure first".

Cache Lens exists to give you that measurement. Watch `×N` for a few days. If it
stays low, warming would have cost you more than it saved. If it climbs, you now
know by how much, and one of the plugins above will earn its keep.

---

## One setting worth checking

On a subscription you get the hour-long cache only while inside your plan's
included usage. Draw on usage credits and it drops to five minutes **without
telling you** — and a warmer tuned for an hour silently stops working at exactly
the moment it would matter most. To hold the hour either way, in your
`settings.json`:

```json
{ "env": { "CLAUDE_CODE_PROMPT_CACHE_TTL": "1h" } }
```

Cache Lens renders `3m/5ᴍ` in yellow when this has happened to you.

---

## Development

```bash
bash tests/check.sh          # 21 assertions, no framework
claude plugin validate .     # marketplace manifest
claude plugin validate ./plugins/cache-lens
```

The tests feed real input to the real scripts. Two properties they hold onto:
the segment never renders a number it had to invent, and the `SessionStart` hook
stays silent unless it has something true and useful to say. A hook that fires
at the start of every session gets muted the first time it cries wolf — and then
the one warning that mattered is muted along with it.

---

## License

MIT

[kw]: https://github.com/Delitefully/claude-keepwarm
[cw]: https://github.com/FiredMosquito831/claude-cache-warm
[ccw]: https://github.com/AshitaOrbis/claude-code-cache-warmer
[ct]: https://github.com/karanb192/cache-tax
[ka]: https://github.com/yujiachen-y/claude-code-cache-keepalive
[prewarm]: https://platform.claude.com/docs/en/build-with-claude/prompt-caching
