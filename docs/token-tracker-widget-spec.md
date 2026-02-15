# Token Tracker Widget — Product Specification

**Status:** MVP Weekend Build (Target: Ship Monday, Feb 17)  
**Platform:** macOS (SwiftUI widget)  
**Owner:** Liz Myers  

---

## Problem Statement

Developers using multiple AI APIs (Anthropic, OpenAI, Google Cloud, AWS, etc.) have **no unified view of token/credit usage**. Result:
- API rate limits hit unexpectedly
- No warning before balance runs out
- Can't compare spend across providers
- Requires switching between dashboards

**Solution:** Native macOS widget showing real-time usage across configured APIs in one glance.

---

## Objectives

1. **Primary:** Track token/credit usage across multiple APIs simultaneously
2. **Secondary:** Surface warnings before hitting limits (visual + optional notification)
3. **Tertiary:** Open-source portfolio piece signaling cost optimization mindset

---

## Core Features (MVP)

### 1. Multi-API Dashboard

**Flip/Carousel Interface:**
- User can swipe or tap to switch between APIs
- Each API is a separate "tab" / "page"
- Smooth transitions between views

**Per-API Display:**
```
┌────────────────────────────────────┐
│  Anthropic              [refresh]  │
├────────────────────────────────────┤
│                                    │
│  55,000 / 200,000 tokens          │
│  [████████░░░░░░░░░░░░] 27.5%     │
│                                    │
│  Status: ✅ OK                      │
│  Last refreshed: 2 min ago         │
│                                    │
│  Est. cost: $0.27 / million        │
└────────────────────────────────────┘
```

### 2. Configuration UI

**Setup Flow:**
1. Widget opens to empty state: "Add your first API"
2. User taps "+" → selects API type from dropdown:
   - Anthropic
   - OpenAI
   - Google Cloud (GCP)
   - AWS
3. User enters API key securely (stored in macOS Keychain)
4. Widget immediately fetches and displays usage
5. User can add more APIs (unlimited)

**Manage APIs:**
- List view of all configured APIs
- Tap to edit/remove
- Reorder by drag-and-drop

### 3. Real-Time Updates

**Refresh Mechanism:**
- Auto-refresh every 60 seconds (configurable)
- Manual refresh button (⟳)
- Last-updated timestamp on each API card

**Data Fetching:**
- Each API call happens in background (non-blocking)
- If one API fails, others still display
- Error state: "Failed to fetch" (red badge)

### 4. Visual Hierarchy

**Color Coding:**
- **Green** (0-70%): Healthy, plenty of credits
- **Yellow** (70-90%): Warning, getting close
- **Red** (90-100%): Critical, running low
- **Red w/ alert** (100%+): Over limit / out of credits

**Typography:**
- Large, readable numbers (current / max)
- Percentage bold
- Subtle: last refreshed time

---

## Technical Requirements

### Data Sources

| API | Endpoint | Auth | Notes |
|-----|----------|------|-------|
| **Anthropic** | `/v1/messages` + usage in response | API key header | Requires checking if usage API exists; fallback to message response tracking |
| **OpenAI** | `/v1/usage` or billing API | API key header | May require org ID |
| **Google Cloud** | Billing API (`cloudbilling.googleapis.com`) | OAuth2 / Service account | More complex; consider MVP without GCP |
| **AWS** | Cost Explorer API | AWS credentials (IAM) | Requires AWS SDK |

**MVP Scope:** Start with Anthropic + OpenAI (most common). GCP/AWS in v2.

### Architecture

**Technology Stack:**
- **Language:** Swift (native)
- **UI Framework:** SwiftUI
- **Persistence:** UserDefaults (simple config) + Keychain (API keys)
- **Networking:** URLSession (async/await)
- **Widget Framework:** WidgetKit (iOS/macOS 14+)

**File Structure:**
```
TokenTrackerWidget/
├── TokenTrackerWidget/
│   ├── ContentView.swift          # Main widget UI
│   ├── ConfigView.swift           # Add/edit APIs
│   ├── APIManager.swift           # Data fetching logic
│   ├── Models.swift               # APIConfig, UsageData structs
│   ├── KeychainHelper.swift       # Secure key storage
│   └── WidgetBundle.swift         # Widget entry point
├── TokenTrackerWidgetExtension/   # Widget extension target
│   └── TokenTrackerWidget.swift   # Widget logic
└── README.md                       # Open-source docs
```

### Models (Data)

```swift
struct APIConfig {
    let id: UUID
    let provider: APIProvider  // .anthropic, .openai, .gcp, .aws
    let apiKey: String          // Stored in Keychain
    let displayName: String     // User-friendly label
    let createdAt: Date
    var order: Int              // For carousel ordering
}

struct UsageData {
    let provider: APIProvider
    let current: Double         // Tokens/credits used
    let limit: Double           // Max tokens/credits
    let percentage: Double      // (current/limit) * 100
    let status: UsageStatus     // .ok, .warning, .critical, .error
    let lastFetched: Date
    let errorMessage: String?   // If failed
}

enum APIProvider: String, CaseIterable {
    case anthropic
    case openai
    case gcp
    case aws
}

enum UsageStatus {
    case ok          // < 70%
    case warning     // 70-90%
    case critical    // 90-100%
    case overLimit   // > 100%
    case error       // Failed to fetch
}
```

### API Fetching Strategy

**Anthropic:**
```
GET https://api.anthropic.com/v1/usage
Header: x-api-key: {apiKey}
Response: { usage: { input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens } }
Limit: 200k tokens/month (or check from account dashboard)
```

**OpenAI:**
```
GET https://api.openai.com/v1/billing/usage
Header: Authorization: Bearer {apiKey}
Query: start_date={start}&end_date={end}
Response: { total_usage: X }
Limit: Check from account (may require org ID call)
```

---

## User Flows

### First Launch
1. User opens widget
2. Empty state: "No APIs configured"
3. Tap "Add API"
4. Select provider (dropdown)
5. Enter API key
6. Tap "Save" → Keychain stores key
7. Widget fetches usage immediately
8. Success state: Shows current usage + bars

### Daily Use
1. Widget sits on desktop
2. Glances at it periodically (like stocks app)
3. If yellow/red: knows to optimize or top up
4. Swipes to next API if monitoring multiple
5. Tap refresh manually if needed

### Adding More APIs
1. Widget shows current API
2. Swipe left/right → empty carousel slot
3. Tap "+" → add new API
4. Repeat setup flow
5. Now tracks N APIs simultaneously

---

## UI/UX Specifications

### Widget Size
- **macOS:** Floating window, resizable (suggest 400x300px default)
- **Aspect ratio:** 16:9 landscape preferred (fits desktop better)

### Color Palette
```
Background:     #1a1a1a (dark gray, matches macOS)
Text Primary:   #ffffff (white)
Text Secondary: #999999 (light gray)
Accent:         #00d4ff (cyan, matches OpenClaw vibes)
Status OK:      #10b981 (green)
Status Warn:    #f59e0b (amber)
Status Error:   #ef4444 (red)
```

### Typography
- **Font:** San Francisco (macOS system font)
- **Large numbers:** 36pt bold (usage %)
- **API name:** 18pt medium
- **Metadata:** 12pt regular (light gray)

### Interactions
- Swipe left/right to switch APIs
- Tap refresh button → spins, fetches new data
- Click API card → opens config/remove options
- Long-press on widget → open full app (if you build one)

---

## Implementation Phases

### Phase 1: MVP (This Weekend)
- ✅ Anthropic + OpenAI support only
- ✅ Basic UI (single API first, then carousel)
- ✅ Keychain storage
- ✅ Auto-refresh every 60s
- ✅ Color-coded status (green/yellow/red)
- ✅ No error handling beyond "Failed to fetch"

### Phase 2: Polish (Following Week)
- ✅ Better error messages
- ✅ Settings/preferences UI
- ✅ Notifications when hitting 90%+
- ✅ Custom refresh intervals

### Phase 3: Scale (Future)
- ✅ GCP + AWS support
- ✅ Historical usage graphs
- ✅ Cost estimation
- ✅ Shared team dashboards

---

## Success Criteria

### Technical
- [ ] Widget loads and displays usage for Anthropic API
- [ ] Widget loads and displays usage for OpenAI API
- [ ] Can switch between APIs smoothly
- [ ] Refreshes data every 60s without crashing
- [ ] Stores API keys securely in Keychain
- [ ] Builds and runs on macOS 13+

### Product
- [ ] User can add/remove/reorder APIs in < 30 seconds
- [ ] Usage percentage updates visually
- [ ] Error states display gracefully
- [ ] Widget looks polished (native macOS aesthetics)

### Launch
- [ ] Open-sourced on GitHub with README
- [ ] Published blog post: "Tracking AI token burn"
- [ ] Shareable on Twitter/LinkedIn
- [ ] Portfolio-worthy (clean code, good UX)

---

## Open Questions / Future Exploration

1. **Anthropic usage API:** Does it exist publicly or only in dashboard? May need to scrape or use OpenClaw integration.
2. **Rate limiting:** Should we cache API usage (to avoid rate limiting) or fetch fresh every refresh?
3. **Authentication:** Should GCP/AWS use OAuth2 or service account files? (Consider Phase 2)
4. **Notifications:** Do we want OS-level notifications when hitting limits?
5. **Full app vs widget-only:** Is desktop widget enough or do we build full Electron/SwiftUI app later?

---

## Deliverables

**By Monday, Feb 17:**
1. ✅ Working macOS widget (SwiftUI)
2. ✅ GitHub repo (open-source)
3. ✅ README with setup instructions
4. ✅ Optional: Twitter/LinkedIn post announcing it

**GitHub Structure:**
```
token-tracker-widget/
├── TokenTrackerWidget.xcodeproj
├── TokenTrackerWidget/
├── TokenTrackerWidgetExtension/
├── README.md (setup + features)
├── LICENSE (MIT)
└── ARCHITECTURE.md (technical deep-dive)
```

---

## Notes

- **Why it matters:** Every dev with multiple AI APIs needs this. Ship it, get visibility.
- **Timing:** Done by Monday = Anthropic follow-up landing while you're shipping. Perfect signal.
- **Marketing:** "Built a widget to stop getting surprised by API limits" is a story.
- **Future:** Could become a service (paid dashboard), but open-source MVP builds credibility first.

---

**Ready to build? Hand this to Claude + Xcode. Go!** 🚀
