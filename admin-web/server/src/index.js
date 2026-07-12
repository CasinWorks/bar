import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import dashboardRoutes from './routes/dashboard.js';
import usersRoutes from './routes/users.js';
import timeLoadsRoutes from './routes/timeLoads.js';
import eventsRoutes from './routes/events.js';
import guestsRoutes from './routes/guests.js';
import employeesRoutes from './routes/employees.js';

const app = express();
const port = process.env.PORT || 4000;

app.use(cors({ origin: process.env.CLIENT_ORIGIN || 'http://localhost:5173', credentials: true }));
app.use(express.json());

app.get('/health', (_, res) => res.json({ ok: true, service: 'blind-tiger-admin' }));

app.use('/api/dashboard', dashboardRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/time-loads', timeLoadsRoutes);
app.use('/api/events', eventsRoutes);
app.use('/api/guests', guestsRoutes);
app.use('/api/employees', employeesRoutes);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error.' });
});

app.listen(port, () => {
  console.log(`Blind Tiger Admin API → http://localhost:${port}`);
});
