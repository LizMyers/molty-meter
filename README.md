# Molty Meter

**Meter your AI session activity and monthly spend.**

A macOS desktop widget that puts your coding agent's context usage and Anthropic API spend right on your desktop — no digging through web dashboards, token math, or hidden log files.

![Molty Meter](MM01.png) ![Molty Meter](MM02.png) ![Molty Meter](MM03.png)

## Why You Need This

Think of it like your water or electric meter. You might decide to shorten your showers — or you might not — but at least you know what's happening.

AI coding agents run in the background, consuming tokens and racking up charges. Without a meter, you don't notice until the bill arrives. Molty puts the numbers where you can see them:

- **Monthly spend vs budget** — real billing data from Anthropic, not estimates
- **Agent activity** — when the context gauge is moving, something is running and costing you money
- **Budget forecast** — "On track" or the date you'll hit your limit at the current rate

## What You See

**Two gauges:**
- **Arc** — Context window fill level for the active session. A full context = expensive messages.
- **Circle** — Monthly budget usage. The "$" fills as you approach your limit.

**Metrics:**
- Context usage (current / limit)
- Monthly spend vs budget (click to open Anthropic cost page)
- Forecast — "On track" or the date you'll exhaust your budget
- Current model

## Quick Start

```bash
git clone https://github.com/lizmyers/molty-meter.git
cd molty-meter
swift build
.build/debug/MoltyMeter
```

Molty launches as a floating widget and starts monitoring.

## Configuration

Molty reads `~/.molty-meter.json`. Edit it directly or use the in-app settings (gear icon).

### Budget

Click the gear icon, enter your monthly budget, tap back. It auto-saves.

```json
{
  "monthlyBudget": 200
}
```

### Anthropic Admin API key (recommended)

For accurate cost tracking, add an Admin API key. Without it, Molty falls back to estimating costs from local session data.

**Important:** This must be an **Admin API key** (`sk-ant-admin...`), not a regular API key (`sk-ant-api...`).

1. Go to [console.anthropic.com/settings/admin-keys](https://console.anthropic.com/settings/admin-keys)
2. You need the **admin role** in your organization
3. Create a key and add it to your config:

```json
{
  "monthlyBudget": 200,
  "anthropicAdminKey": "sk-ant-admin01-your-key-here"
}
```

### Optional: Custom start date

By default, Molty tracks spend from the 1st of each month. If you need to start tracking from a specific date (e.g. you switched API keys mid-month), add:

```json
{
  "monthlyBudget": 200,
  "anthropicAdminKey": "sk-ant-admin01-your-key-here",
  "costStartDate": "2026-02-12"
}
```

Remove `costStartDate` when you no longer need it — Molty will default back to the 1st.

## How Cost Tracking Works

Molty fetches billing data from Anthropic's `/v1/organizations/cost_report` endpoint. This returns exact amounts — the same numbers you see on your [Anthropic cost page](https://console.anthropic.com/settings/cost).

It filters for Haiku costs (the model used by most coding agents) and caches results for 30 minutes.

**Note on timing:** The cost report endpoint reflects finalized billing data. Charges from the current day may take a few hours to appear. By the next morning, Molty's numbers will match the console exactly.

If no Admin API key is configured, Molty falls back to parsing cost data from local OpenClaw session files (`~/.openclaw/agents/`).

## Session Monitoring

Molty watches OpenClaw's session data at `~/.openclaw/agents/` using file system events for near-instant updates, with a 10-second fallback poll.

When you see the context gauge climbing, that's an agent working — and spending. If it's filling up fast and you didn't expect it, that's your cue to check what's running.

## Start on Login

```bash
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

launchctl load ~/Library/LaunchAgents/com.molty.meter.plist
```

To disable: `launchctl unload ~/Library/LaunchAgents/com.molty.meter.plist`

## Why "Molty"?

Context windows are like shells — when they get too full, the system compacts (summarizes) your conversation to free up space. You lose nuance, and you pay for the compaction. Starting a fresh session early ("molting") keeps your messages lean and your spend efficient.

## Requirements

- macOS 13+
- Swift 5.9+
- OpenClaw (for session monitoring)
- Anthropic Admin API key (optional, for accurate cost tracking)

## License

MIT

---

*Built by [Liz Myers](https://github.com/lizmyers/) with Claude. Shell yeah!*
