# Molty Meter

**Know when to shed your shell.**

A floating macOS desktop widget that monitors AI session health in real-time. Molty the lobster watches your context window, tracks your spend, and tells you when it's time to start fresh — before your session gets heavy and expensive.

Originally built to monitor Anthropic Claude API spend, but works with any provider supported by [OpenClaw](https://github.com/openclaw).

![Molty Meter](molty-intro.png)

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

## Make It Your Own

Molty Meter was built for Claude, but the architecture is straightforward to adapt to any provider or model.

### Add a new model's pricing

Open `MoltyMeter/CostCalculator.swift` and add an entry to the `pricing` dictionary:

```swift
"gpt-4o": ModelPricing(
    inputPerMillion: 2.50, outputPerMillion: 10.00,
    cacheReadPerMillion: 1.25, cacheWritePerMillion: 0
),
```

Models are matched by prefix, so `"gpt-4o"` will match `"gpt-4o-2025-01-01"` and similar variants.

### Point to a different data directory

The parser reads from `~/.claude/` by default. To change this, edit the `claudeDir` path in `MoltyMeter/ClaudeDataParser.swift`:

```swift
private static let claudeDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".your-tool-here")
```

Your tool needs to provide session data in JSONL format with `usage` fields (`input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`) on assistant messages.

### Adjust health thresholds

Edit `MoltyMeter/SessionHealthState.swift` to tune when Molty warns you:

```swift
static func from(cost: Double, totalTokens: Int) -> SessionHealthState {
    if cost > 5.0 || totalTokens > 1_000_000 { return .heavy }
    if cost > 3.50 || totalTokens > 750_000 { return .warning }
    if cost > 2.0 || totalTokens > 500_000 { return .watching }
    return .healthy
}
```

Lower the thresholds for cheaper models, raise them for expensive ones.

## License

MIT

---

*Built by [Liz Myers](https://github.com/lizmyers/) with help from Claude. Shell yeah!*
