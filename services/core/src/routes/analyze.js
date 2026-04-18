import { Router } from 'express';

export const analyzeRouter = Router();

/**
 * POST /analyze/player
 * body: { user_id, period_days }
 * Implemented in PHASE 4.
 */
analyzeRouter.post('/player', (_req, res) => {
  res.status(501).json({ error: 'not_implemented', phase: 4 });
});
