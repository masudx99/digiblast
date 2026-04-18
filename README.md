# digiblast

Auto-generated social-media cards for amateur cricket players in US leagues.

> **Status:** phase 0 — scaffold only. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for phase-0 design decisions that differ from the original spec.

## Layout

```
services/core/     Node + Playwright: scraper + card renderer + AI (one deploy)
frontend/          Single index.html, Hostinger static
db/migrations/     Supabase SQL                         (phase 1)
n8n-workflows/     Importable n8n JSON                  (phase 5)
docs/              Architecture, deployment, parser guide
```

## Quick start (phase 0)

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

| Phase | Scope                                              |
| ----- | -------------------------------------------------- |
| 0     | Monorepo scaffold, `/health` boots                 |
| 1     | Supabase schema + RLS + storage buckets            |
| 2     | WCL scraper (Playwright + stealth), parser tests   |
| 3     | 3 card templates, HTML → PNG render                |
| 4     | Claude-powered weekly insights                     |
| 5     | n8n workflows for cron + WhatsApp                  |
| 6     | Frontend (signup, onboarding, dashboard, settings) |
| 7     | Deployment docs + parser guide                     |

Stop after each phase for verification.
