# Architecture

Fully written in phase 7. This stub captures the phase 0–1 decisions plus
the recon findings from 2026-04-25 that shape phase 2.

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

## Key phase-1 / recon decisions (added 2026-04-25)

5. **Cloudflare passes silently for real-Playwright with persistent profile.** Confirmed against `cricclubs.com/wclinc/viewScorecard.do`. Plain `curl` and WebFetch hit the Cloudflare Managed Challenge interstitial (HTTP 403). Real Playwright with `playwright-stealth` and a warm `userDataDir` per league does not. Residential proxy is deferred until WCL/NEUCC permission is denied OR we operate at >50 users from one VPS IP.
6. **Parsers map columns by header TEXT, never by ordinal position.** A scorecard row with N cells and a header row with N cells does not mean `cell[3] = R`. Use `cells[headers.indexOf('R')]`. Header drift on cricclubs.com is the #1 brittleness risk; mapping by header makes the parser tolerant of column reorders. Same rule applies inside name cells: if `cell[idx.name]` contains only an `<img>`, the actual name is at `idx.name + 1` (shift detection required).
7. **Player ID is captured per innings row from `viewPlayer.do?playerId=…` href, not from name match.** This unlocks the cold-start growth loop — we can pre-render cards for *every player who appears in any scraped scorecard*, not just signed-up users. Captain marker (`*` suffix on name) is preserved as a boolean.
8. **Three card types from one scrape.** Player Card (the signed-up player's innings), Match-Star Card (top performer of a match for a team — buyer is the captain), Team Weekly Digest (team-level summary). All three are derivable from the same `innings_performance` rows; no schema changes needed beyond a `card_type` enum on `generated_cards`.
9. **The unit of polling is the team-season, not the player.** A player's profile page gives only aggregate career stats (no per-match log). The per-match log lives at `teamResults.do?teamId=X&clubId=Y` (AJAX). To track a user we track their *current team(s) in their current series* — implies a `team_membership(user_id, team_id, club_id, season_active boolean)` table in phase 2.

## Known WCL URL shape (phase-2 scraper targets)

```
clubId  = league       e.g. 670 (WCL)
teamId  = team         e.g. 3618 (VA Wolves CC)
playerId= player       e.g. 2233608 (Masud Haque)
matchId = match        e.g. 7919

team fixtures (AJAX): /teamSchedule.do?teamId=…&clubId=…
team results  (AJAX): /teamResults.do?teamId=…&clubId=…
scorecard            : /viewScorecard.do?matchId=…&clubId=…
player profile       : /viewPlayer.do?playerId=…&clubId=…
```

A single CricClubs player ID is registered across many leagues. Masud Haque
(`2233608`) appears in 25+ leagues on one profile. Cross-league career
stitching is a real moat — no other tool does it.

## Why each tech

| Tech             | Why                                                                |
| ---------------- | ------------------------------------------------------------------ |
| Supabase         | Postgres + auth + storage + RLS in one, direct REST from frontend  |
| Node + Playwright| Same runtime for scraping and rendering, mature stealth ecosystem  |
| n8n              | Visual cron + WhatsApp webhook plumbing without writing a scheduler |
| Claude Sonnet 4.6| Structured JSON extraction, MoM reasoning, caption drafting        |
| Hostinger        | User already runs it; one static file fits                         |
| Hetzner          | User already runs it; cheap enough for Playwright                  |

## Outstanding (tracked, not done)

- **League ToS.** WCL/NEUCC permission email before any production scraping runs.
- **Instagram posting.** Graph API requires Business accounts; likely pivot to "copy caption + open IG" flow at phase 5.
- **MoM reasoning quality.** Match `7919` had a contested MoM (Masud 79 on winning side vs Rizwan 50* @ SR 172 on losing side). Claude must justify the pick in one line — that justification is the AI value-add, not the pick itself.
- **Parser fixture coverage.** Phase 2 ships with hand-verified fixtures for matches `7919` and `7948` only. Add 1 fixture per new league before scraping it in production.
