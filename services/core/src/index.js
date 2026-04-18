import 'dotenv/config';
import express from 'express';
import { healthRouter } from './routes/health.js';
import { scrapeRouter } from './routes/scrape.js';
import { renderRouter } from './routes/render.js';
import { analyzeRouter } from './routes/analyze.js';

const app = express();
app.use(express.json({ limit: '2mb' }));

app.use('/health', healthRouter);
app.use('/scrape', scrapeRouter);
app.use('/render', renderRouter);
app.use('/analyze', analyzeRouter);

app.use((err, req, res, _next) => {
  console.error('[error]', err);
  res.status(err.status || 500).json({ error: err.message || 'internal_error' });
});

const port = Number(process.env.PORT) || 3000;
app.listen(port, () => {
  console.log(`[core] listening on :${port}`);
});
