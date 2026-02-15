# Token Ticker Widget — MVP Spec (Revised)

**Goal:** Build today, use today
**Platform:** macOS desktop widget (floating window)
**Data source:** OpenClaw status

---

## What It Does

A small, always-visible desktop widget that shows your current token usage at a glance — like a weather widget but for API costs.

---

## UI (Based on Mockup)

```
┌─────────────────────────────┐
│                             │
│   78%                  🦞   │
│   178k/200k tokens          │
│                             │
│   Haiku-4-5                 │
│                             │
└─────────────────────────────┘
```

**Elements:**
- **Percentage** — Large, bold (primary focus)
- **Token count** — `{used}k/{limit}k tokens`
- **Model name** — Bottom left (e.g., "Haiku-4-5")
- **Lobster emoji** — Trend indicator
  - 🦞 pointing right = costs rising
  - 🦞 pointing left = costs falling (or flip vertically)
- **Background** — Gray rounded rectangle, matches macOS aesthetic

---

## Behavior

| Feature | MVP |
|---------|-----|
| Data source | OpenClaw status (local file or API) |
| Refresh | Poll every 60 seconds |
| Provider/Model | Hardcoded (no settings UI) |
| Trend detection | Compare current vs previous reading |
| Window | Floating, always-on-top option, ~200x150px |

---

## Tech Stack

**Option A: SwiftUI App (Recommended)**
- Native macOS floating window
- Reads OpenClaw status file/API
- Timer-based refresh
- Single `.swift` file possible

**Option B: Electron/Web**
- If faster to prototype
- HTML/CSS/JS
- Same data source

---

## Data Contract

Widget expects this data (from OpenClaw or mock):

```json
{
  "provider": "anthropic",
  "model": "haiku-4-5",
  "tokensUsed": 178000,
  "tokenLimit": 200000,
  "trend": "rising"  // or "falling"
}
```

**If OpenClaw doesn't provide this directly**, create a small script that:
1. Reads OpenClaw logs/status
2. Writes to `~/.token-ticker/status.json`
3. Widget reads that file

---

## File Structure (Minimal)

```
token-ticker/
├── TokenTicker/
│   ├── TokenTickerApp.swift    # App entry + window
│   ├── WidgetView.swift        # The UI
│   └── DataProvider.swift      # Reads OpenClaw status
├── token-ticker-mvp-spec.md    # This file
└── README.md
```

---

## Build Steps

1. **Find OpenClaw status data** — Locate the file/endpoint on the right machine
2. **Create SwiftUI app** — Floating window with the widget view
3. **Wire up data** — Read status, parse, display
4. **Add refresh timer** — Poll every 60s
5. **Add trend logic** — Compare readings, flip lobster

---

## Not in MVP

- Settings/config UI
- Multiple providers
- Notifications
- Keychain storage
- Carousel/swipe between APIs
- Historical graphs

---

## Success

- [ ] Widget shows on desktop
- [ ] Displays current percentage + token count
- [ ] Shows correct model name
- [ ] Lobster reflects trend direction
- [ ] Updates automatically

---

**Next step:** On the machine with OpenClaw, find where usage data lives, then build.
