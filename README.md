<div align="center">

# Cache Lens

**See what your prompt cache is doing — before it costs you.**

A draining bar in your Claude Code status line, and a warning about what a stale
resume will cost, delivered while you can still do something about it.

[Install](#install) · [What it shows](#what-it-shows) · [How it works](#how-it-works) · [Troubleshooting](#troubleshooting)

</div>

---

Claude Code re-sends your entire conversation with every request. Normally it
reads that back from the prompt cache at a tenth of the price. But the cache
expires after an idle gap — **an hour on a subscription, five minutes
otherwise** — and the first request after that gap pays full freight to rebuild
the prefix.

You never see this happen. You notice a turn that took longer, in a session you
had left open, and move on.

Cache Lens shows you. It does not ping anything, spend anything, or change how
your sessions work.

---

## Install

### Requirements

| | |
|---|---|
| **Claude Code** | v2.1.251 or later — that is when the `prompt_cache` status-line object and the resume fields landed |
| **`jq`** | `brew install jq` · `apt install jq` · `winget install jqlang.jq` |
| **Shell** | bash, present by default on macOS, Linux, and Git Bash on Windows |

Check your version with `claude --version`. On anything older the plugin stays
silent rather than guessing — it will not break, it just will not show anything.

### 1. Add the marketplace and install

Run these inside a Claude Code session:

```
/plugin marketplace add Kirill812/cache-lens
/plugin install cache-lens@cache-lens
```

The install opens a details view where you pick a scope and confirm. If the
summary says `Run /reload-plugins to activate.`, do that — otherwise the plugin
is live immediately.

**At this point the resume warning already works.** No further setup needed for
it.

### 2. Add the bar to your status line

```
/cache-lens:setup
```

This step is a command rather than something the plugin does by itself, because
**a plugin cannot set `statusLine`** — a plugin's own `settings.json` supports
only the `agent` and `subagentStatusLine` keys. So the setup command edits your
configuration instead, and it is written to **merge with the status line you
already have** rather than replace it: it reads your current script, backs it up
to `<name>.bak-cache-lens`, and appends the segment following the conventions
already in that file. If you have no status line, it writes a minimal one.

It finishes by running your real status-line command against synthetic input and
showing you the result, so you see the bar working rather than being told it
works.

### 3. Read the intro page

```
/cache-lens:explain
```

Prints the legend for every state the bar can show. The same page appears once
on its own, the first time a session starts after you install.

### Updating and removing

```
/plugin update cache-lens@cache-lens
/plugin uninstall cache-lens@cache-lens
```

Uninstalling stops the hook. The status-line edit is yours and stays — restore
the `.bak-cache-lens` backup to undo it, or delete the line that calls
`statusline-segment.sh`.

---

## What it shows

### A bar that drains

One short segment on your status line. The column is the share of the cache
lifetime remaining, so it falls as the session sits idle.

```
█ 52m      the cached prefix is good for another 52 minutes
▅ 31m      draining
▂ 12m      under a third remaining — yellow
▁ ᴄᴏʟᴅ     expired; your next request rebuilds the prefix
▅ 3m/5ᴍ    the window itself collapsed to five minutes
▅ 31m ×2   ×N counts misses this session has already paid for
```

**`×N` is the one to watch.** It counts requests that re-processed content the
cache already held — which is exactly the money an idle gap costs you. Claude
Code counts a miss only when a request redid more than 5% and at least 2,000
tokens of what it could have read from cache, so small drift never registers. If
`×N` stays at zero, you do not have this problem.

Misses are not caused only by idling. Switching models, changing effort, turning
on fast mode, connecting or disconnecting an MCP server, enabling or disabling a
plugin, denying a whole tool, compacting, accumulating images, and upgrading
Claude Code all invalidate the cache too. `/cost` names the likely cause of the
last miss on v2.1.260+.

### A warning before the bill

Resume a session that has been sitting idle and Cache Lens speaks up *before the
first request goes out*:

```
⚑ cache-lens — this resume rebuilds the prompt cache
  idle 4d 2h · cache expired · first request re-sends 182k tokens
```

Claude Code hands `SessionStart` hooks three fields on a resume that exist for
precisely this: `seconds_since_last_response`, `context_tokens`, and
`prompt_cache_likely_expired`. This is those fields, said out loud, at the only
moment the number is still actionable. Afterwards it is trivia.

The hook stays quiet otherwise — a warm resume, a fresh start, a `/clear`, or an
older Claude Code all produce nothing at all.

---

## How it works

| Piece | What it is |
|---|---|
| `scripts/statusline-segment.sh` | Reads the status-line JSON on stdin, prints one segment (≤10 columns) on stdout. Prints nothing when there is no cache data to report. |
| `scripts/session-start.sh` | `SessionStart` hook. Emits the welcome page once, then the resume warning when — and only when — a resume will actually rebuild the cache. |
| `scripts/welcome.sh` | Renders the intro page. One source for both the first-run display and `/cache-lens:explain`. |
| `skills/setup` | Instructions for merging the segment into an existing status line without destroying it. |

Using the renderer by hand, without the setup command:

```bash
segment=$(printf '%s' "$input" | bash /path/to/cache-lens/scripts/statusline-segment.sh)
```

---

## Troubleshooting

**The bar does not appear.**
Most likely one of three things. Check them in order:

1. `claude --version` — below v2.1.251 there is no `prompt_cache` object to read.
2. `command -v jq` — no `jq`, no segment.
3. The bar appears only after the session's **first API response**. A session
   sitting at an empty prompt has no cache to report on yet.

**It appeared in a new session but not in an old one.**
A running session keeps the binary it started with. Sessions launched before you
updated Claude Code will show nothing until restarted.

**The bar shows but my status line lost something.**
Restore the backup `/cache-lens:setup` made — `<your script>.bak-cache-lens` —
and open an issue with your original script. That is a bug, not a
misconfiguration.

**It says `3m/5ᴍ`.**
Your cache window collapsed from an hour to five minutes. See the next section.

**The resume warning never fires.**
It fires only when a resume will genuinely rebuild the cache. Resuming inside
the TTL is free and gets no warning — intended, not broken.

---

## One setting worth checking

On a subscription you get the hour-long cache only while inside your plan's
included usage. Draw on usage credits and it drops to five minutes **without
telling you** — and any warmer tuned for an hour silently stops working at
exactly the moment it would matter most.

To hold the hour either way, in `~/.claude/settings.json`:

```json
{ "env": { "CLAUDE_CODE_PROMPT_CACHE_TTL": "1h" } }
```

Cache Lens renders `3m/5ᴍ` in yellow when this has happened to you.

---

## What this deliberately does not do

**It does not keep your cache warm.** Several plugins do, by sending a cheap turn
every N minutes to reset the TTL — [claude-keepwarm][kw], [claude-cache-warm][cw],
[claude-code-cache-warmer][ccw], [cache-tax][ct], [cache-keepalive][ka]. The
trick is sound and documented: a cache hit refreshes the lifetime, and Anthropic
describes pre-warming [in the API docs][prewarm].

It is also not free, and whether it pays depends on how you are billed:

- **On an API key or usage credits** you spend one cache read (0.1× base input)
  to avoid one cache write (2× base input at the 1-hour TTL). Strongly in your
  favour.
- **On a Pro or Max subscription** every keepalive turn is a real request
  carrying your full context and drawing on plan usage. Anthropic does not
  document how subscription quota is computed, so nobody — including this README
  — can state the break-even. Multiply by the number of sessions you leave open
  and the honest answer is *measure first*.

Cache Lens is that measurement. Watch `×N` for a few days. If it stays low,
warming would have cost more than it saved. If it climbs, you now know by how
much, and one of the plugins above will earn its keep.

---

## Development

```bash
bash tests/check.sh                          # 21 assertions, no framework
claude plugin validate .                     # marketplace manifest
claude plugin validate ./plugins/cache-lens  # plugin manifest and skills
```

The tests feed real input to the real scripts. Two properties they hold onto:
the segment never renders a number it had to invent, and the `SessionStart` hook
stays silent unless it has something true and useful to say. A hook that fires
at the start of every session gets muted the first time it cries wolf — and then
the one warning that mattered is muted along with it.

Issues and pull requests welcome.

---

## License

MIT

[kw]: https://github.com/Delitefully/claude-keepwarm
[cw]: https://github.com/FiredMosquito831/claude-cache-warm
[ccw]: https://github.com/AshitaOrbis/claude-code-cache-warmer
[ct]: https://github.com/karanb192/cache-tax
[ka]: https://github.com/yujiachen-y/claude-code-cache-keepalive
[prewarm]: https://platform.claude.com/docs/en/build-with-claude/prompt-caching
