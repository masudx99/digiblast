# digiblast

Auto-generated social-media cards for amateur cricket players in US leagues.

> **Status:** phase 1 done — Supabase schema + RLS + storage buckets shipped.
> CricClubs scraping proven viable (Playwright passes Cloudflare silently),
> parser proven on 2 real WCL matches (`7919`, `7948`) with exact figures.
> See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the recon findings
> that shape phase 2.

## The product in one paragraph

A weekend cricketer plays a match in a US amateur league (WCL, NEUCC, CLNJ,
Loudoun County, etc — all run on CricClubs). By the time they shower, a
polished card is in their WhatsApp DM: their face, their numbers, their
team's crest, one Claude-written line that captures the innings. They tap ✅.
It posts to their IG story and FB feed before their parents back home wake up.

Three card types from the same scrape:

| Card | Trigger | Buyer |
| --- | --- | --- |
| **Player Card** | Your innings — every match you appear in | Player ($5/mo) |
| **Match Star Card** | Top performer of THIS match for a team | Team captain ($20/mo, covers 11) |
| **Team Weekly Digest** | Your week — wins/losses, top scorers, points-table movement | Team captain (same sub) |

## Onboarding is one input

Player pastes any CricClubs link — either their player profile
(`viewPlayer.do?playerId=…`) or any single scorecard
(`viewScorecard.do?matchId=…`). We extract `playerId` + `clubId` from the URL,
pull career, render their demo card live, then ask for photo + WhatsApp number.
That's the whole funnel.

## Layout

```
services/core/     Node + Playwright: scraper + card renderer + AI (one deploy)
services/core/tests/fixtures/   hand-verified scorecards used as parser ground truth
frontend/          Single index.html, Hostinger static
db/migrations/     Supabase SQL                         (phase 1 done)
n8n-workflows/     Importable n8n JSON                  (phase 5)
docs/              Architecture, deployment, parser guide
```

## Quick start

```bash
cd services/core
cp .env.example .env
npm install
npm start
# another terminal:
curl http://localhost:3000/health
```

Expected response:

```json
{"status":"ok","service":"digiblast-core","version":"0.1.0",...}
```

## Phase plan

| Phase | Scope | Status |
| --- | --- | --- |
| 0 | Monorepo scaffold, `/health` boots | ✅ done |
| 1 | Supabase schema + RLS + storage buckets | ✅ done |
| 2 | WCL scraper (Playwright + stealth) + header-mapped parser + fixture tests | 🟠 next |
| 3 | 3 card templates, HTML → PNG render (player / match-star / weekly) | queued |
| 4 | Claude-powered captions + insights + MoM reasoning | queued |
| 5 | n8n cron + WhatsApp I/O | queued |
| 6 | Paste-link onboarding + dashboard | queued |
| 7 | Deployment docs + parser guide | queued |

Stop after each phase for verification.

## Phase 2 entry conditions (must hold before any code)

- WCL/NEUCC permission email sent or explicitly deferred (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) Outstanding).
- Parser MUST map columns by header text, never by ordinal position. Header drift is the #1 risk.
- Every scorecard parsed in dev gets hand-verified once and dropped as a JSON
  fixture in `services/core/tests/fixtures/`. Snapshot tests run against the
  fixtures, not against live HTML.
