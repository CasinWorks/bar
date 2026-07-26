import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin } from '../middleware/auth.js';

const router = Router();

/** Known club branches (match Flutter MockData.clubBranches display names). */
const KNOWN_BRANCHES = [
  { id: 'bgc', name: 'BGC Secret Cellar', city: 'Taguig' },
  { id: 'poblacion', name: 'Poblacion Velvet Room', city: 'Makati' },
  { id: 'glasshouse', name: 'Makati Glasshouse', city: 'Makati' },
  { id: 'tomas', name: 'Tomas Morato Lounge', city: 'Quezon City' },
];

const LIVE_PHASES = ['inside_club', 'awaiting_exit_scan'];

function formatGuest(row, profile) {
  return {
    id: row.id,
    memberId: row.member_id,
    memberName: row.member_name || profile?.name || 'Guest',
    email: profile?.email || null,
    phone: profile?.phone || null,
    phase: row.phase,
    branch: row.branch,
    enteredAt: row.entered_at,
    /** Live wallet = profiles.time_balance_seconds (not session.remaining_seconds). */
    walletSeconds: profile?.time_balance_seconds ?? 0,
    drinksOrdered: row.drinks_ordered ?? 0,
  };
}

router.get('/live', requireAdmin, async (_req, res) => {
  try {
    const { data: sessions, error } = await supabaseAdmin
      .from('club_sessions')
      .select(
        'id, member_id, member_name, branch, phase, entered_at, remaining_seconds, drinks_ordered',
      )
      .in('phase', LIVE_PHASES)
      .order('entered_at', { ascending: true });

    if (error) throw error;

    const rows = sessions ?? [];
    const memberIds = [...new Set(rows.map((r) => r.member_id).filter(Boolean))];

    let profilesById = {};
    if (memberIds.length > 0) {
      const { data: profiles, error: profileError } = await supabaseAdmin
        .from('profiles')
        .select('id, name, email, phone, time_balance_seconds')
        .in('id', memberIds);
      if (profileError) throw profileError;
      profilesById = Object.fromEntries((profiles ?? []).map((p) => [p.id, p]));
    }

    const byBranch = new Map();
    for (const known of KNOWN_BRANCHES) {
      byBranch.set(known.name, {
        id: known.id,
        name: known.name,
        city: known.city,
        count: 0,
        guests: [],
      });
    }

    for (const row of rows) {
      const branchName = (row.branch || '').trim() || 'Unknown branch';
      if (!byBranch.has(branchName)) {
        byBranch.set(branchName, {
          id: branchName.toLowerCase().replace(/\s+/g, '-'),
          name: branchName,
          city: '',
          count: 0,
          guests: [],
        });
      }
      const bucket = byBranch.get(branchName);
      bucket.guests.push(formatGuest(row, profilesById[row.member_id]));
      bucket.count = bucket.guests.length;
    }

    // Known branches first (even if empty), then any extras.
    const knownNames = new Set(KNOWN_BRANCHES.map((b) => b.name));
    const branches = [
      ...KNOWN_BRANCHES.map((b) => byBranch.get(b.name)),
      ...[...byBranch.values()].filter((b) => !knownNames.has(b.name)),
    ];

    const awaitingEntry = await supabaseAdmin
      .from('club_sessions')
      .select('id', { count: 'exact', head: true })
      .eq('phase', 'paid_awaiting_entry');

    res.json({
      totalInside: rows.length,
      awaitingEntry: awaitingEntry.count ?? 0,
      branches,
      refreshedAt: new Date().toISOString(),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

export default router;
