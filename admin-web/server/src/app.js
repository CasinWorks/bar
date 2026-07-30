import express from 'express';
import cors from 'cors';
import dashboardRoutes from './routes/dashboard.js';
import usersRoutes from './routes/users.js';
import timeLoadsRoutes from './routes/timeLoads.js';
import eventsRoutes from './routes/events.js';
import guestsRoutes from './routes/guests.js';
import employeesRoutes from './routes/employees.js';
import leaderboardRoutes from './routes/leaderboard.js';
import safetySocialRoutes from './routes/safetySocial.js';
import branchesRoutes from './routes/branches.js';
import packagesRoutes from './routes/packages.js';
import pushRoutes from './routes/push.js';
import downloadRoutes from './routes/download.js';

const app = express();

const allowedOrigins = (process.env.CLIENT_ORIGIN || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

app.use(
  cors({
    origin(origin, callback) {
      // Allow same-origin / server-to-server / local Vite
      if (!origin) return callback(null, true);
      if (
        allowedOrigins.length === 0 ||
        allowedOrigins.includes(origin) ||
        origin.includes('localhost') ||
        origin.endsWith('.vercel.app')
      ) {
        return callback(null, true);
      }
      return callback(new Error(`CORS blocked for origin: ${origin}`));
    },
    credentials: true,
  }),
);

app.use(express.json());

app.get('/health', (_, res) => res.json({ ok: true, service: 'blind-tiger-admin' }));
app.get('/api/health', (_, res) => res.json({ ok: true, service: 'blind-tiger-admin' }));

app.use('/api/dashboard', dashboardRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/time-loads', timeLoadsRoutes);
app.use('/api/events', eventsRoutes);
app.use('/api/guests', guestsRoutes);
app.use('/api/employees', employeesRoutes);
app.use('/api/leaderboard', leaderboardRoutes);
app.use('/api/safety-social', safetySocialRoutes);
app.use('/api/branches', branchesRoutes);
app.use('/api/packages', packagesRoutes);
app.use('/api/push', pushRoutes);
app.use('/api/download', downloadRoutes);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: err.message || 'Internal server error.' });
});

export default app;
