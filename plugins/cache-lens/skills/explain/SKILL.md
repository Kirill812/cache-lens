---
name: explain
description: Show the Cache Lens welcome page — what the status-line bar means, what the resume warning is, and which setting controls the cache TTL. Use when the user asks what cache-lens does, what the bar or the ᴄᴏʟᴅ marker means, what 3m/5ᴍ means, or asks to see the intro page again.
---

# Explain Cache Lens

Run the page and show it to the user:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/welcome.sh"
```

Print the output verbatim in a fenced block. It is laid out to a fixed width and
reflowing or summarising it breaks the box rules and the legend alignment.

Do not add a summary above or below it. The page says everything it needs to; a
preamble just pushes it off the screen.

If the user then asks a specific question about one of the lines, answer that
question directly rather than re-printing the page.
