# @digiblast/core

Combined Node.js service for the cricket portal. Three concerns, one deploy:

- **Scraper** (phase 2) — Playwright-based, pulls match scorecards from league sites.
- **Card renderer** (phase 3) — Playwright renders HTML templates to PNG for Instagram.
- **AI analysis** (phase 4) — Claude API wraps innings stats into structured insights.

Split into microservices later if any one concern actually needs it.

## Run locally

```bash
cp .env.example .env
npm install
npm start
curl http://localhost:3000/health
```

## Endpoints

| Method | Path              | Phase | Status       |
| ------ | ----------------- | ----- | ------------ |
| GET    | `/health`         | 0     | ready        |
| POST   | `/scrape/player`  | 2     | stub (501)   |
| POST   | `/scrape/match`   | 2     | stub (501)   |
| POST   | `/render/card`    | 3     | stub (501)   |
| POST   | `/analyze/player` | 4     | stub (501)   |

## Layout

```
src/
  index.js          Express bootstrap
  routes/           one file per concern
  parsers/          league-specific HTML parsers (phase 2)
  templates/        HTML/CSS card templates (phase 3)
  lib/              supabase client, browser launcher, logger
tests/parsers/      parser snapshot tests (phase 2)
failures/           scraper dumps raw HTML here on parse failure
```

## Docker

```bash
docker build -t digiblast-core .
docker run -p 3000:3000 --env-file .env digiblast-core
```

The Dockerfile swaps to the Playwright base image in phase 2.
