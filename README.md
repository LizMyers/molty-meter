# Molty Meter

**Know when to shed your shell.**

A macOS widget that monitors your Claude API session health and monthly spend — so you can molt early and spend efficiently.

## The Insight

Here's what most developers don't realize about Claude API sessions:

**"Tokens used" is misleading.** It's not a cumulative counter — it's your *context window fill level*. And that number can go **down**.

When your context hits the limit, the system automatically **compacts** your conversation:
- Summarizes older history
- Replaces verbose messages with condensed versions
- Drops you back to ~50-60% capacity

You kept working. The AI kept responding. But you lost nuance — and **paid for compaction**.

That's the hidden cost: summarizing 200k tokens of history isn't free. It's token debt. The longer you wait, the more you pay to compress.

**Molty Meter makes this visible.**

## Why "Molt"?

Like a lobster outgrowing its shell, AI sessions get heavy and sluggish. The fuller your context window:
- More tokens sent with every message
- Higher cost per interaction
- Slower responses
- Eventually: forced compaction

**Molting early = lean messages = efficient spend.**

## What You See

**Two gauges:**
- **Arc** — Session health (context window fill). When Molty says "Time to molt!", your session is getting heavy.
- **Circle** — Monthly budget tracking. The "$" fills as you approach your limit.

**Metrics:**
- Session cost
- Context usage (current / limit)
- Monthly spend vs budget
- Current model

**Advice:** Rotating lobster-themed phrases. "Shell yeah!" when you're fresh. "Butter's melting!" when it's time to bail.

## Quick Start

```bash
git clone https://github.com/lizmyers/molty-meter.git
cd molty-meter
swift build
.build/debug/MoltyMeter
```

Click the gear to set your monthly budget. Molty watches your OpenClaw sessions automatically.

## Start on Login

Want Molty waiting for you every morning? Add it to your Login Items:

**Option 1: System Settings (easiest)**
1. Open **System Settings → General → Login Items**
2. Click **+** under "Open at Login"
3. Navigate to your MoltyMeter build and select it

**Option 2: LaunchAgent (for CLI fans)**

```bash
# Create the plist
cat > ~/Library/LaunchAgents/com.molty.meter.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.molty.meter</string>
    <key>ProgramArguments</key>
    <array>
        <string>/full/path/to/molty-meter/.build/debug/MoltyMeter</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Load it
launchctl load ~/Library/LaunchAgents/com.molty.meter.plist
```

Replace `/full/path/to/` with your actual path. Molty will be there when you log in.

## The Philosophy

**Session hygiene is budget hygiene.**

Don't wait for auto-compaction. When Molty warns you, wrap up and start fresh. You'll:
- Keep full control of your context
- Avoid surprise summarization
- Send leaner messages
- Spend less per interaction

The arc and circle work together: healthy sessions lead to healthy budgets.

## Requirements

- macOS 13+
- OpenClaw (reads from `~/.openclaw/agents/`)
- An Anthropic API key (and the desire to spend it wisely)

## Lobster Wisdom

| State | Molty Says |
|-------|------------|
| Fresh | "Shell yeah!", "Claws out!", "Seize the bait!" |
| Cruising | "In flow", "Riding the tide", "Making waves" |
| Warning | "Riptides ahead", "Getting crabby", "Watch the trap" |
| Critical | "Molt o'clock", "Butter's melting", "Escape the pot!" |

## License

MIT

---

*Built by [Liz Myers](https://github.com/lizmyers/) with help from Claude. Shell yeah!*
