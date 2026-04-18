import { Router } from 'express';

export const healthRouter = Router();

healthRouter.get('/', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'digiblast-core',
    version: '0.1.0',
    uptime_s: Math.round(process.uptime()),
    node: process.version,
  });
});
