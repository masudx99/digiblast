# Architecture

Fully written in phase 7. This stub captures the phase 0 decisions so nothing drifts.

## Shape

```
                ┌─────────────────────────┐
                │  frontend/index.html    │  Hostinger static host
                │  (Supabase REST + JWT)  │
                └───────────┬─────────────┘
                            │ auth, read own data
                            ▼
                   ┌────────────────┐
                   │   Supabase     │  Postgres + storage + auth
                   └───┬────────▲───┘
                       │        │
   service role key ───┘        │ reads/writes
                                │
                   ┌────────────┴──────────┐
                   │  services/core  (Node)│  Hetzner VPS, docker-compose
                   │  ├─ /scrape  (Playwright)
                   │  ├─ /render  (Playwright → PNG)
                   │  └─ /analyze (Claude API)
                   └───────────▲───────────┘
                               │ HTTP
                     ┌─────────┴──────────┐
                     │   n8n (Hetzner)    │  cron + WhatsApp I/O only
                     │   weekly-scrape    │
                     │   weekly-insights  │
                     │   whatsapp-in/out  │
                     └────────────────────┘
```

## Key phase-0 decisions (differ from original spec)

1. **One service, not two.** Scraper + renderer + AI share Playwright, Supabase client, and deploy target. Splitting is theology at MVP scale. `services/core` hosts all three.
2. **Playwright only.** Used for both scraping (page navigation) and rendering (HTML → PNG via `page.screenshot()`). Dropped Puppeteer — two Chromium bundles is wasteful.
3. **n8n is not the orchestrator.** n8n owns cron triggers and WhatsApp in/out only. The approval state machine (pending → approved/rejected → posted) lives in `services/core` where it can be versioned and tested.
4. **`league_slug` is text + CHECK, not enum.** Easier to add leagues without migrations.

## Why each tech

| Tech             | Why                                                                |
| ---------------- | ------------------------------------------------------------------ |
| Supabase         | Postgres + auth + storage + RLS in one, direct REST from frontend  |
| Node + Playwright| Same runtime for scraping and rendering, mature stealth ecosystem  |
| n8n              | Visual cron + WhatsApp webhook plumbing without writing a scheduler |
| Claude Sonnet 4.6| Structured JSON extraction is its sweet spot                       |
| Hostinger        | User already runs it; one static file fits                         |
| Hetzner          | User already runs it; cheap enough for Playwright                  |

## Outstanding (tracked, not done)

- **League ToS.** WCL/NEUCC permission email before any real scraping runs.
- **Instagram posting.** Graph API requires Business accounts; likely pivot to "copy caption + open IG" flow at phase 5.
