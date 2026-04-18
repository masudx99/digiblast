import { Router } from 'express';

export const scrapeRouter = Router();

/**
 * POST /scrape/player
 * body: { league_slug, league_player_id, profile_url }
 * Implemented in PHASE 2.
 */
scrapeRouter.post('/player', (_req, res) => {
  res.status(501).json({ error: 'not_implemented', phase: 2 });
});

/**
 * POST /scrape/match
 * body: { league_slug, match_url }
 * Implemented in PHASE 2.
 */
scrapeRouter.post('/match', (_req, res) => {
  res.status(501).json({ error: 'not_implemented', phase: 2 });
});
