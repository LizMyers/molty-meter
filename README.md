# Molty Meter

Molty Meter is a macOS widget that monitors your Moltbot sessions in real time. It pulls session data from your local [OpenClaw](https://openclaw.ai) install and monthly cost data from the Anthropic Admin API.

<img src="Molty-Meter-Screenshot-v1.2.png" alt="Molty Meter" width="100%">

**The arc** shows how full your context window is. As it fills, Molty's status changes:

| Context Used | Status | What It Means |
|:---|:---|:---|
| < 40% | *"Let's go!"* | Fresh session, full speed ahead |
| 40–65% | *"Cruising"* | Smooth sailing |
| 65–85% | *"Wrap it up"* | Context is getting heavy, messages cost more |
| > 85% | *"Time to molt!"* | Start a fresh session now |

**The circle** fills as your monthly spend approaches your budget.

**The forecast** tells you whether you'll get through the month under budget at your current burn rate. If you're on pace, it says "On track". If you're projected to go over, Molty estimates when you'll hit your limit — like "Feb 22".

## Why It Matters

As your context window fills up, every message gets more expensive. The model processes all prior context on every turn.

When the context window hits its limit, your provider compacts (summarizes) the conversation to make room. This buys you more turns, but the compaction itself burns tokens — and the summarized context is lossy. You lose nuance, the model starts repeating itself, and you're paying more for worse results.

That's the molt. When Molty warns you, start a fresh session. Clean context, sharper responses, cheaper messages. Session hygiene is budget hygiene.

## Add Molty Meter to Your Desktop

### 1. Clone and build

```bash
git clone https://github.com/lizmyers/molty-meter.git
cd molty-meter && swift build
```

### 2. Launch

```bash
.build/debug/MoltyMeter
```

Molty appears on your desktop. Drag it wherever you want — it remembers its position between launches.

### 3. Connect your data

Molty reads session data from [OpenClaw](https://github.com/openclaw), which runs locally and captures token usage from your AI sessions. This is where context window and session cost data comes from — all local, read from `~/.openclaw/agents/`.

OpenClaw works with Claude subscriptions (Pro, Max) — not just API keys. Run `openclaw onboard` and choose your auth method. [Setup details here.](https://docs.openclaw.ai/providers/anthropic)

### 4. Add your Anthropic Admin API key (recommended)

For monthly cost tracking, Molty pulls real billing data from Anthropic's API — the same numbers on your [cost page](https://console.anthropic.com/settings/cost). Molty refreshes this every 30 minutes. Current-day costs may lag slightly as billing data syncs on Anthropic's side.

Edit `~/.molty-meter.json`:

```json
{
  "monthlyBudget": 200,
  "anthropicAdminKey": "sk-ant-admin01-your-key-here"
}
```

**Important:** This must be an **Admin API key** (`sk-ant-admin...`), not a regular API key. You need the **admin role** in your Anthropic org to [create one](https://console.anthropic.com/settings/admin-keys).

Don't have an admin key? Molty still works — it estimates monthly costs from local OpenClaw session data instead.

### 5. Start on login (optional)

1. Open **System Settings > General > Login Items**
2. Click **+** under "Open at Login"
3. Navigate to your MoltyMeter build and select it

## Works With Your Provider

Molty Meter works with any provider supported by OpenClaw. Session data (context window, tokens, model) comes from your local OpenClaw install automatically. For monthly cost tracking, it depends on what your provider offers:

| Provider | Session Data | Monthly Cost Data | What You Need |
|:---|:---|:---|:---|
| **Anthropic** | Via OpenClaw | [Admin API](https://docs.anthropic.com/en/api/usage-cost-api) | Admin API key (`sk-ant-admin...`) |
| **OpenAI** | Via OpenClaw | [Costs API](https://platform.openai.com/docs/api-reference/usage) | Org Admin API key |
| **OpenRouter** | Via OpenClaw | [Activity API](https://openrouter.ai/docs/api/reference/overview) | Same API key (`sk-or-...`) |
| **AWS Bedrock** | Via OpenClaw | [Cost Explorer API](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-api.html) | IAM credentials |
| **Google Gemini** | Via OpenClaw | [Cloud Billing API](https://ai.google.dev/gemini-api/docs/billing) | GCP service account |
| **Mistral** | Via OpenClaw | No API (console only) | Estimated from tokens |
| **Ollama** | Via OpenClaw | Free (local) | — |

Molty currently has a built-in integration for the Anthropic Admin API. Other provider billing integrations are on the roadmap. Without a billing API, Molty estimates costs from token counts in your session data.

You can set your budget from the in-app Settings (gear icon) instead of editing the JSON file.

## Just Want Token Usage?

If you only want to surface token usage, without cost tracking, check out [Token Ticker](https://github.com/lizmyers/token-ticker). It's a simple widget that reads session data directly from OpenClaw.

## Requirements

- macOS 13+
- [OpenClaw](https://github.com/openclaw) (reads from `~/.openclaw/agents/`)

<<<<<<< HEAD
=======
## Changelog

### v1.2
- **Fix: model display now tracks the actual model in use.** Previously the meter could show a stale model name from `sessions.json`. Now reads `modelOverride` from OpenClaw session data, so switching models (e.g. Haiku to Gemma) updates correctly — even when the provider falls back silently.
- **Local model support.** When using a local model (Ollama, etc.), Monthly shows `$0.00` and Forecast shows "No bills!"
- **Session sorting by recency.** When multiple sessions exist, Molty picks the most recently active one.

### v1.1
- Multi-provider support (Anthropic, OpenAI, unknown/local)
- Switch to `cost_report` endpoint for exact Anthropic billing
- Add pointer cursor on clickable elements
- Add links to provider cost pages

>>>>>>> b36f1e7 (Prepare v1.2 for publish: fix model tracking, remove debug logging, clean up for GitHub)
## License

MIT

---

*Built by [Liz Myers](https://github.com/lizmyers/) with help from Claude and Molty — Shell yeah!*
