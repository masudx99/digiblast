import { Router } from 'express';

export const renderRouter = Router();

/**
 * POST /render/card
 * body: { innings_performance_id, template_name, player_photo_url }
 * Implemented in PHASE 3.
 */
renderRouter.post('/card', (_req, res) => {
  res.status(501).json({ error: 'not_implemented', phase: 3 });
});
