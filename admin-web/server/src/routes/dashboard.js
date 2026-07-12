import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin, requireAdminOnly } from '../middleware/auth.js';

const router = Router();

router.get('/me', requireAdmin, (req, res) => {
  res.json({ user: req.user, profile: req.profile });
});

router.get('/stats', requireAdmin, async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [
      { count: memberCount },
      { count: activeSessions },
      { count: staffCount },
      { data: loadsToday },
      { data: upcomingEvents },
    ] = await Promise.all([
      supabaseAdmin.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'member'),
      supabaseAdmin
        .from('club_sessions')
        .select('*', { count: 'exact', head: true })
        .in('phase', ['inside_club', 'awaiting_exit_scan', 'paid_awaiting_entry']),
      supabaseAdmin.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'staff'),
      supabaseAdmin
        .from('time_loads')
        .select('amount_peso, seconds_loaded, status')
        .gte('created_at', today.toISOString()),
      supabaseAdmin
        .from('club_events')
        .select('id, title, starts_at')
        .gte('starts_at', new Date().toISOString())
        .order('starts_at', { ascending: true })
        .limit(5),
    ]);

    const postedToday = (loadsToday ?? []).filter((r) => (r.status ?? 'posted') === 'posted');
    const cashToday = postedToday.reduce((s, r) => s + (r.amount_peso ?? 0), 0);
    const minutesToday = postedToday.reduce((s, r) => s + (r.seconds_loaded ?? 0), 0) / 60;

    res.json({
      memberCount: memberCount ?? 0,
      activeSessions: activeSessions ?? 0,
      staffCount: staffCount ?? 0,
      cashToday,
      minutesLoadedToday: Math.round(minutesToday),
      loadsTodayCount: postedToday.length,
      upcomingEvents: upcomingEvents ?? [],
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

export default router;
