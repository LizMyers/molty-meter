# Molty Meter

**Know when to shed your shell.**

A macOS menubar widget that monitors your AI coding session health and monthly API spend — so you can molt early and spend efficiently.

![Molty Meter](MM01.png) ![Molty Meter](MM02.png) ![Molty Meter](MM03.png)

## What It Does

Molty Meter tracks two things:

1. **Session health** — How full is your context window? When it's bloated, you're paying more per message and risking forced compaction (where the system summarizes your history and you lose nuance). Molty tells you when to start a fresh session.

2. **Monthly spend** — How much have you spent this month vs your budget? Molty fetches real cost data from the Anthropic Admin API and projects when you'll hit your limit.

## The Insight

Here's what most developers don't realize about Claude API sessions:

**"Tokens used" is misleading.** It's not a cumulative counter — it's your *context window fill level*. And that number can go **down**.

When your context hits the limit, the system automatically **compacts** your conversation — summarizing older history, replacing verbose messages with condensed versions, and dropping you back to ~50-60% capacity. You kept working. The AI kept responding. But you lost nuance — and **paid for compaction**.

**Molting early = lean messages = efficient spend.**

## What You See

**Two gauges:**
- **Arc** — Session health (context window fill). When Molty says "Time to molt!", your session is getting heavy.
- **Circle** — Monthly budget tracking. The "$" fills as you approach your limit.

**Metrics:**
- Context usage (current / limit)
- Monthly spend vs budget
- Forecast — projected budget exhaustion date
- Current model

**Forecast** uses your daily spend rate to project forward:
- **On track** — projected spend stays within your monthly budget
- **A date** (e.g. "Feb 22") — the day you'll hit your budget at the current rate
- **---** — no data yet

## Quick Start

```bash
git clone https://github.com/lizmyers/molty-meter.git
cd molty-meter
swift build
.build/debug/MoltyMeter
```

That's it. Molty launches as a floating widget and starts monitoring.

## Configuration

Molty reads its config from `~/.molty-meter.json`. You can edit this file directly or use the in-app settings (click the gear icon).

### Setting your budget

Click the gear icon and enter your monthly budget. It auto-saves when you navigate back.

Or edit the config directly:

```json
{
  "monthlyBudget": 200
}
```

### Adding your Anthropic Admin API key (recommended)

This is the key step for accurate cost tracking. Without it, Molty falls back to estimating costs from local OpenClaw session data.

**Important:** This is an **Admin API key**, not a regular API key. It starts with `sk-ant-admin...` (not `sk-ant-api...`). Regular API keys will not work — the cost report endpoint requires admin access.

To get one:

1. Go to [console.anthropic.com/settings/admin-keys](https://console.anthropic.com/settings/admin-keys)
2. You must have the **admin role** in your organization
3. Click **Create Key** and copy it

Then add it to your config:

```json
{
  "monthlyBudget": 200,
  "anthropicAdminKey": "sk-ant-admin01-your-key-here"
}
```

With an Admin API key, Molty calls the `/v1/organizations/cost_report` endpoint to get your actual monthly spend, broken down by model. It filters for Haiku costs (the model used by coding agents like OpenClaw) and caches results for 5 minutes.

If the key is missing or the API call fails, Molty silently falls back to calculating costs from local OpenClaw session files.

## How Cost Tracking Works

Molty supports two cost data sources:

| Source | How it works | Accuracy |
|--------|-------------|----------|
| **Anthropic Admin API** | Fetches real billing data from Anthropic's cost_report endpoint | Exact (matches your invoice) |
| **OpenClaw (fallback)** | Parses cost data from local session JSONL files in `~/.openclaw/agents/` | Good estimate |

The Admin API approach works for any Anthropic API usage tied to your organization — not just OpenClaw. If you're running Claude through any tool that uses your API key, Molty will pick up the spend.

## Session Monitoring

Molty monitors active sessions by watching OpenClaw's session data at `~/.openclaw/agents/`. It uses file system events for near-instant updates, with a 10-second fallback poll.

OpenClaw works with multiple AI providers (Claude, GPT, etc.), so Molty's session health gauge works regardless of which model your agent is using.

## Customizing for Your Setup

Molty was built for monitoring Anthropic API spend via OpenClaw, but the architecture is straightforward to adapt:

- **Different provider?** The session monitor reads from `~/.openclaw/agents/` — if your tool writes session data there, Molty picks it up automatically.
- **Different cost source?** The monthly spend logic lives in `SessionDataProvider.swift:refresh()`. You can swap in your own cost calculation.
- **Different model filter?** `AnthropicCostFetcher.swift` filters for "Haiku" in the cost report. Change the filter string to match your model (e.g. "Sonnet", "Opus").

## Start on Login

Want Molty waiting for you every morning? Add a LaunchAgent:

```bash
# Create the plist (update the path to match your setup)
cat > ~/Library/LaunchAgents/com.molty.meter.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.molty.meter</string>
    <key>ProgramArguments</key>
    <array>
        <string>/YOUR/PATH/TO/molty-meter/.build/debug/MoltyMeter</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

# Enable it
launchctl load ~/Library/LaunchAgents/com.molty.meter.plist
```

To disable auto-launch later:

```bash
launchctl unload ~/Library/LaunchAgents/com.molty.meter.plist
```

Molty remembers its window position between restarts.

## Requirements

- macOS 13+
- Swift 5.9+
- OpenClaw (for session monitoring — reads from `~/.openclaw/agents/`)
- Anthropic Admin API key (optional, for accurate cost tracking)

## License

MIT

---

*Built by [Liz Myers](https://github.com/lizmyers/) with Claude. Shell yeah!*
