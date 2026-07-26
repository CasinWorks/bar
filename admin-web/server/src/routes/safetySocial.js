import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin } from '../middleware/auth.js';

const router = Router();

const isMissingSchema = (error) => {
  const message = `${error?.message || ''} ${error?.details || ''}`;
  return (
    error?.code === '42P01' ||
    error?.code === '42883' ||
    message.includes('does not exist') ||
    message.includes('schema cache') ||
    message.includes('Could not find the function')
  );
};

async function safeTable(table, queryBuilder, fallback = []) {
  const { data, error, count } = await queryBuilder(supabaseAdmin.from(table));
  if (error) {
    if (isMissingSchema(error)) {
      return { data: fallback, count: 0, missing: true };
    }
    throw error;
  }
  return { data: data ?? fallback, count: count ?? data?.length ?? 0, missing: false };
}

function staleThresholdIso() {
  return new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
}

async function completeStaleSessionsDirect() {
  const { data, error } = await supabaseAdmin
    .from('club_sessions')
    .select('id, entered_at')
    .in('phase', ['inside_club', 'awaiting_exit_scan'])
    .lte('entered_at', staleThresholdIso());

  if (error) throw error;
  let completed = 0;

  for (const session of data ?? []) {
    const enteredAt = new Date(session.entered_at);
    const exitedAt = new Date(enteredAt.getTime() + 48 * 60 * 60 * 1000);
    const { error: updateError } = await supabaseAdmin
      .from('club_sessions')
      .update({ phase: 'completed', exited_at: exitedAt.toISOString() })
      .eq('id', session.id);
    if (updateError) throw updateError;
    completed += 1;
  }

  return completed;
}

async function completeStaleSessions() {
  // Admin uses the service role, so auth.uid() is null inside
  // complete_stale_club_sessions — that RPC returns 0 without updating.
  // Complete stale sessions with a direct service-role update instead.
  return completeStaleSessionsDirect();
}

router.get('/overview', requireAdmin, async (_req, res) => {
  try {
    await completeStaleSessions().catch(() => 0);

    const [
      staleSessions,
      reports,
      rides,
      incidents,
      friendRequests,
      friendships,
      blocks,
      notifications,
    ] = await Promise.all([
      safeTable('club_sessions', (q) =>
        q
          .select('id, member_name, branch, phase, entered_at, exited_at', { count: 'exact' })
          .in('phase', ['inside_club', 'awaiting_exit_scan'])
          .lte('entered_at', staleThresholdIso())
          .order('entered_at', { ascending: true }),
      ),
      safeTable('safety_reports', (q) =>
        q
          .select('id, category, description, branch, status, created_at, reporter_id, reported_member_id', {
            count: 'exact',
          })
          .order('created_at', { ascending: false })
          .limit(25),
      ),
      safeTable('ride_assist_requests', (q) =>
        q
          .select('id, pickup_branch, destination, provider, status, external_url, created_at', {
            count: 'exact',
          })
          .order('created_at', { ascending: false })
          .limit(25),
      ),
      safeTable('insurance_incidents', (q) =>
        q
          .select('id, incident_type, consent_to_share, status, partner_reference, created_at', {
            count: 'exact',
          })
          .order('created_at', { ascending: false })
          .limit(25),
      ),
      safeTable('friend_requests', (q) =>
        q.select('id, status, created_at, requester_id, recipient_id', { count: 'exact' }).order(
          'created_at',
          { ascending: false },
        ),
      ),
      safeTable('member_friendships', (q) => q.select('*', { count: 'exact', head: true })),
      safeTable('member_blocks', (q) =>
        q.select('blocker_id, blocked_id, reason, created_at', { count: 'exact' }).order(
          'created_at',
          { ascending: false },
        ),
      ),
      safeTable('member_notifications', (q) =>
        q.select('id, kind, message, created_at, sender_id, recipient_id', { count: 'exact' }).order(
          'created_at',
          { ascending: false },
        ),
      ),
    ]);

    const missing = [
      reports,
      rides,
      incidents,
      friendRequests,
      friendships,
      blocks,
      notifications,
    ].some((r) => r.missing);

    res.json({
      migrationReady: !missing,
      staleSessions: staleSessions.data,
      safetyReports: reports.data,
      rideRequests: rides.data,
      insuranceIncidents: incidents.data,
      friendRequests: friendRequests.data,
      memberBlocks: blocks.data,
      notifications: notifications.data,
      counts: {
        staleSessions: staleSessions.count,
        safetyReports: reports.count,
        rideRequests: rides.count,
        insuranceIncidents: incidents.count,
        friendRequests: friendRequests.count,
        friendships: friendships.count,
        memberBlocks: blocks.count,
        notifications: notifications.count,
      },
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/auto-badge-out', requireAdmin, async (_req, res) => {
  try {
    const completed = await completeStaleSessions();
    res.json({ completed });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

export default router;
