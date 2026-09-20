---
name: setup
description: Add the Cache Lens cache bar to the user's Claude Code status line, merging with whatever status line they already have instead of replacing it. Use when the user asks to install, set up, enable, or add the cache-lens status line, or asks why the bar is not showing up.
---

# Add the cache bar to the status line

A plugin cannot set `statusLine` itself — a plugin's own `settings.json` supports
only the `agent` and `subagentStatusLine` keys. So this has to be an edit to the
user's own configuration, which means doing it carefully.

**The rule that matters: never replace a status line the user already has.**
People put real work into these. Destroying one to show a cache bar is a bad
trade, and it is the failure they will remember.

The segment renderer lives at `${CLAUDE_PLUGIN_ROOT}/scripts/statusline-segment.sh`.
It reads the status-line JSON on stdin and prints one short piece of text such as
`▅ 31m`. It prints nothing when there is no cache data to report, so a session
that has not made its first request yet simply shows nothing.

## Steps

1. **Read the current setting.** Look for `statusLine` in `~/.claude/settings.json`,
   then in the project's `.claude/settings.json`. Report which one you found and
   what it points at before changing anything.

2. **Pick the case that applies.**

   **No `statusLine` anywhere.** Write a small script to
   `~/.claude/statusline.sh` that prints the model name and then the segment, and
   point `statusLine` at it:

   ```bash
   #!/usr/bin/env bash
   input=$(cat)
   model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
   segment=$(printf '%s' "$input" | bash "$HOME/.claude/plugins/.../statusline-segment.sh")
   printf '%s' "$model"
   [ -n "$segment" ] && printf '  %s' "$segment"
   ```

   Resolve the real path to `statusline-segment.sh` from `${CLAUDE_PLUGIN_ROOT}`
   and write it out literally. Do not leave `...` in the file.

   **`statusLine` points at a script the user owns.** Read that script. Find
   where it emits its final line and append the segment there, following the
   conventions already in the file — if it builds the line through a helper
   function, use that helper rather than a bare `printf` at the end. The input
   JSON is already on stdin in that script; capture it once if the script has
   not already done so, because stdin can only be read once.

   **`statusLine` is an inline command string.** Leave it intact. Write a
   wrapper script that feeds the same stdin to the original command and appends
   the segment, then point `statusLine` at the wrapper.

3. **Back up before editing an existing script.** Copy it to
   `<name>.bak-cache-lens` first and tell the user the path.

4. **Verify by running it, not by reading it.** Feed synthetic input through the
   real status-line command and show the user the output:

   ```bash
   now=$(date +%s)
   printf '{"model":{"display_name":"Opus 5"},"prompt_cache":{"caching_observed":true,"warm":true,"ttl":"1h","expires_at":%s,"misses":0}}' $(( now + 1890 )) \
     | bash <the configured status line command>
   ```

   It should print the user's normal status line with `▅ 31m` on the end. If the
   segment is missing, check that `jq` is installed and that the path to
   `statusline-segment.sh` in the script is correct.

5. **Say what changed.** Name the files you edited, the backup path, and that
   the status line refreshes on the next render — no restart needed. Mention
   that `prompt_cache` requires Claude Code v2.1.251 or later, so an older
   session that is still running will show nothing until it is restarted.

## Also worth checking

If `promptCacheTtl` / `CLAUDE_CODE_PROMPT_CACHE_TTL` is not set anywhere, tell
the user what that means for them: on a subscription the cache window is an hour
while they are inside their plan's included usage, and drops to five minutes
once they draw on usage credits. Setting it explicitly to `1h` holds the hour
either way. Offer the edit; do not make it without asking, since it changes
billing behaviour rather than display.
