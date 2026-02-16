# Molty Meter

A floating macOS desktop widget that monitors AI session health and token spend in real time. Originally built to monitor Anthropic Claude API spend, but works with any provider supported by [OpenClaw](https://github.com/openclaw).

<img src="molty-hero.png" alt="Molty Meter" width="75%">

## What You See

**Two gauges:**
- **Arc** — Session health (context window fill). When Molty says "Time to molt!", your session is getting heavy.
- **Circle** — Monthly budget tracking. The "$" fills as you approach your limit.

## Easy Install

```bash
git clone https://github.com/lizmyers/molty-meter.git
cd molty-meter
swift build
.build/debug/MoltyMeter
```

## Configuration

Molty reads `~/.molty-meter.json`. You can set your budget from the in-app Settings (gear icon), or edit the file directly.

### Budget

Click the gear icon, enter your monthly budget, tap back. It auto-saves.

```json
{
  "monthlyBudget": 200
}
```

### Anthropic Admin API key (recommended)

For accurate cost tracking, add an [Admin API key](https://console.anthropic.com/settings/admin-keys). This gives Molty exact billing data — the same numbers you see on your Anthropic cost page.

**Important:** This must be an **Admin API key** (`sk-ant-admin...`), not a regular API key (`sk-ant-api...`). You need the **admin role** in your Anthropic organization to create one.

Add it to `~/.molty-meter.json`:

```json
{
  "monthlyBudget": 200,
  "anthropicAdminKey": "sk-ant-admin01-your-key-here"
}
```

Without an admin key, Molty falls back to estimating costs from local OpenClaw session files at `~/.openclaw/agents/`. This works but may be less precise.

## Launch the Desktop Widget on Mac OS

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

## License

MIT

---

*Built by [Liz Myers](https://github.com/lizmyers/) with help from Claude. Shell yeah!*
