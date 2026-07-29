import { Router } from 'express';
import { supabaseAdmin, supabaseAsUser } from '../lib/supabase.js';
import { requireAdmin, requireAdminOnly } from '../middleware/auth.js';

const router = Router();

function computeLifecycleStatus(startsAt, endsAt, status) {
  if (status === 'cancelled') return 'cancelled';
  if (!startsAt || !endsAt) return 'scheduled';
  const now = Date.now();
  const start = new Date(startsAt).getTime();
  const end = new Date(endsAt).getTime();
  if (Number.isNaN(start) || Number.isNaN(end)) return 'scheduled';
  if (now >= end) return 'completed';
  if (now >= start) return 'live';
  return 'scheduled';
}

function windowsOverlap(aStart, aEnd, bStart, bEnd) {
  const as = new Date(aStart).getTime();
  const ae = new Date(aEnd).getTime();
  const bs = new Date(bStart).getTime();
  const be = new Date(bEnd).getTime();
  if ([as, ae, bs, be].some((n) => Number.isNaN(n))) return false;
  return as < be && ae > bs;
}

function isConflictCandidate(event) {
  if (!event) return false;
  if (event.status === 'cancelled') return false;
  if (event.approval_status === 'rejected') return false;
  return Boolean(event.starts_at && event.ends_at);
}

function normalizeBranch(value) {
  return String(value ?? '').trim().replace(/\s+/g, ' ').toLowerCase();
}

/** Two nights only clash if they are in the same room — i.e. the same branch. */
function sameBranch(a, b) {
  return normalizeBranch(a) === normalizeBranch(b);
}

async function loadActiveBranches() {
  const { data, error } = await supabaseAdmin
    .from('branches')
    .select('id, slug, name, is_default, sort_order')
    .eq('is_active', true)
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

/** Accepts a branch name or slug and returns the canonical branch name. */
function resolveBranchName(branches, requested) {
  const query = normalizeBranch(requested);
  if (!query) return null;
  const match = branches.find(
    (branch) =>
      normalizeBranch(branch.name) === query || normalizeBranch(branch.slug) === query,
  );
  return match?.name ?? null;
}

function branchChoiceError(branches) {
  if (branches.length === 0) {
    return {
      status: 409,
      body: {
        error:
          'No active branch exists yet. Create a branch first, then schedule the event against it.',
        needsBranchSetup: true,
      },
    };
  }
  return {
    status: 400,
    body: {
      error: `Select a branch for this event. Active branches: ${branches
        .map((b) => b.name)
        .join(', ')}.`,
      branches: branches.map((b) => ({ slug: b.slug, name: b.name })),
    },
  };
}

async function syncEventStatuses() {
  try {
    await supabaseAdmin.rpc('sync_club_event_runtime_statuses');
  } catch (_) {
    // Sync is best-effort; timestamp checks still gate ops RPCs.
  }
}

async function loadEvents(queryBuilder) {
  const { data, error } = await queryBuilder;
  if (error) throw error;
  return data || [];
}

function attachConflicts(events) {
  return events.map((event) => {
    if (!isConflictCandidate(event)) {
      return { ...event, conflicts: [] };
    }
    const conflicts = events
      .filter(
        (other) =>
          other.id !== event.id &&
          isConflictCandidate(other) &&
          sameBranch(other.branch, event.branch) &&
          windowsOverlap(event.starts_at, event.ends_at, other.starts_at, other.ends_at),
      )
      .map((other) => ({
        id: other.id,
        title: other.title,
        starts_at: other.starts_at,
        ends_at: other.ends_at,
        approval_status: other.approval_status,
        status: other.status,
        branch: other.branch,
        host_name: other.host_name || null,
      }));
    return { ...event, conflicts };
  });
}

async function fetchEventsWithHosts(extra = {}) {
  await syncEventStatuses();

  let query = supabaseAdmin
    .from('club_events')
    .select('*')
    .order('starts_at', { ascending: true });

  if (extra.from) query = query.gte('starts_at', extra.from);
  if (extra.to) query = query.lte('starts_at', extra.to);
  if (extra.approvalStatus) {
    if (Array.isArray(extra.approvalStatus)) {
      query = query.in('approval_status', extra.approvalStatus);
    } else {
      query = query.eq('approval_status', extra.approvalStatus);
    }
  }

  const events = await loadEvents(query);
  const hostIds = [
    ...new Set(
      events
        .flatMap((ev) => [ev.host_id, ev.requested_by])
        .filter(Boolean),
    ),
  ];

  let hostMap = {};
  if (hostIds.length > 0) {
    const { data: profiles, error } = await supabaseAdmin
      .from('profiles')
      .select('id, name, email')
      .in('id', hostIds);
    if (error) throw error;
    hostMap = Object.fromEntries((profiles || []).map((p) => [p.id, p]));
  }

  const enriched = events.map((ev) => {
    const host = hostMap[ev.host_id] || hostMap[ev.requested_by] || null;
    return {
      ...ev,
      host_name: host?.name || null,
      host_email: host?.email || null,
      requester_name: hostMap[ev.requested_by]?.name || null,
    };
  });

  return attachConflicts(enriched);
}

async function findConflictsForWindow(startsAt, endsAt, excludeId = null, branch = null) {
  const events = await fetchEventsWithHosts();
  return events.filter(
    (other) =>
      other.id !== excludeId &&
      isConflictCandidate(other) &&
      sameBranch(other.branch, branch) &&
      windowsOverlap(startsAt, endsAt, other.starts_at, other.ends_at),
  );
}

router.get('/', requireAdmin, async (req, res) => {
  try {
    const { from, to, approvalStatus } = req.query;
    const events = await fetchEventsWithHosts({
      from: from || undefined,
      to: to || undefined,
      approvalStatus: approvalStatus || undefined,
    });
    res.json({ events });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/pending', requireAdmin, requireAdminOnly, async (_req, res) => {
  try {
    // Load all events so conflicts vs approved/live calendar bookings are visible.
    const all = await fetchEventsWithHosts();
    const events = all.filter((e) =>
      ['pending_review', 'needs_revision'].includes(e.approval_status),
    );
    res.json({
      events,
      pendingCount: events.filter((e) => e.approval_status === 'pending_review').length,
      needsRevisionCount: events.filter((e) => e.approval_status === 'needs_revision').length,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/conflicts', requireAdmin, async (req, res) => {
  try {
    const { startsAt, endsAt, excludeId, branch } = req.query;
    if (!startsAt || !endsAt) {
      return res.status(400).json({ error: 'startsAt and endsAt are required.' });
    }
    if (new Date(endsAt) <= new Date(startsAt)) {
      return res.status(400).json({ error: 'End time must be after start time.' });
    }
    const conflicts = await findConflictsForWindow(
      startsAt,
      endsAt,
      excludeId || null,
      branch || null,
    );
    res.json({ conflicts, hasConflict: conflicts.length > 0, branch: branch || null });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/', requireAdmin, async (req, res) => {
  const { title, description, branch, startsAt, endsAt, capacity, vipOnly, status } = req.body;
  if (!title || !startsAt || !endsAt) {
    return res.status(400).json({ error: 'Title, start time, and end time are required.' });
  }

  const startDate = new Date(startsAt);
  const endDate = new Date(endsAt);
  if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
    return res.status(400).json({ error: 'Invalid start or end time.' });
  }
  if (endDate <= startDate) {
    return res.status(400).json({ error: 'End time must be after start time.' });
  }

  const cancelled = status === 'cancelled';
  const startIso = startDate.toISOString();
  const endIso = endDate.toISOString();
  const resolvedStatus = cancelled
    ? 'cancelled'
    : computeLifecycleStatus(startIso, endIso, 'scheduled');

  try {
    const activeBranches = await loadActiveBranches();
    const resolvedBranch = resolveBranchName(activeBranches, branch);
    if (!resolvedBranch) {
      const err = branchChoiceError(activeBranches);
      return res.status(err.status).json(err.body);
    }

    const conflicts = await findConflictsForWindow(startIso, endIso, null, resolvedBranch);
    if (conflicts.length > 0 && !req.body.force) {
      return res.status(409).json({
        error: 'This event overlaps one or more existing events at the same branch.',
        conflicts,
      });
    }

    const { data, error } = await supabaseAdmin
      .from('club_events')
      .insert({
        title,
        description: description || null,
        branch: resolvedBranch,
        starts_at: startIso,
        ends_at: endIso,
        capacity: capacity ? Number(capacity) : null,
        vip_only: Boolean(vipOnly),
        status: resolvedStatus,
        // Admin-created events are approved so the window can auto-go live.
        approval_status: 'approved',
        approved_at: new Date().toISOString(),
        host_id: req.profile.id,
        created_by: req.profile.id,
      })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    res.json({ event: data, conflicts });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/:id/review', requireAdmin, requireAdminOnly, async (req, res) => {
  const decision = String(req.body.decision || '').toLowerCase().trim();
  const notes = req.body.notes || req.body.adminReviewNotes || null;
  const force = Boolean(req.body.force);

  if (!['approved', 'rejected', 'needs_revision'].includes(decision)) {
    return res.status(400).json({
      error: 'decision must be approved, rejected, or needs_revision.',
    });
  }

  try {
    const { data: current, error: fetchError } = await supabaseAdmin
      .from('club_events')
      .select('*')
      .eq('id', req.params.id)
      .single();
    if (fetchError) return res.status(404).json({ error: fetchError.message });

    if (!['pending_review', 'needs_revision'].includes(current.approval_status) && !force) {
      return res.status(400).json({
        error: `Event is already ${current.approval_status}.`,
      });
    }

    let conflicts = [];
    if (decision === 'approved') {
      conflicts = await findConflictsForWindow(
        current.starts_at,
        current.ends_at,
        current.id,
        current.branch,
      );
      if (conflicts.length > 0 && !force) {
        return res.status(409).json({
          error: 'Approving this event conflicts with existing events.',
          conflicts,
        });
      }
    }

    // Prefer the authenticated admin JWT so auth.uid()/is_admin() work in the RPC.
    const userClient = supabaseAsUser(req.token);
    const rpc = await userClient.rpc('admin_review_event_request', {
      p_event_id: req.params.id,
      p_decision: decision,
      p_admin_review_notes: notes,
    });

    if (rpc.error) {
      // Service-role fallback if JWT RPC path fails (e.g. RLS/auth edge cases).
      const nowIso = new Date().toISOString();
      const patch = {
        approval_status: decision,
        admin_review_notes: notes ? String(notes).trim() || null : null,
        reviewed_at: nowIso,
        reviewed_by: req.profile.id,
        approved_at: decision === 'approved' ? nowIso : current.approved_at,
        rejected_at: decision === 'rejected' ? nowIso : null,
      };
      if (decision === 'approved') {
        patch.status = computeLifecycleStatus(
          current.starts_at,
          current.ends_at,
          current.status === 'cancelled' ? 'scheduled' : current.status,
        );
      }
      if (decision === 'rejected') {
        patch.status = 'cancelled';
      }

      const { data: updated, error: updateError } = await supabaseAdmin
        .from('club_events')
        .update(patch)
        .eq('id', req.params.id)
        .select()
        .single();
      if (updateError) {
        return res.status(500).json({
          error: rpc.error.message || updateError.message,
        });
      }

      const recipientId = current.requested_by || current.host_id;
      if (recipientId) {
        await supabaseAdmin.from('member_notifications').insert({
          sender_id: req.profile.id,
          recipient_id: recipientId,
          kind:
            decision === 'approved'
              ? 'event_request_approved'
              : decision === 'rejected'
                ? 'event_request_rejected'
                : 'event_request_needs_revision',
          message:
            decision === 'approved'
              ? `Your event request "${current.title}" was approved.`
              : decision === 'rejected'
                ? `Your event request "${current.title}" was rejected.`
                : `Your event request "${current.title}" needs revision.`,
          metadata: {
            event_id: current.id,
            event_title: current.title,
            approval_status: decision,
            review_notes: patch.admin_review_notes,
          },
        });
      }

      return res.json({ event: updated, conflicts, via: 'service_fallback' });
    }

    // After approve via RPC, align lifecycle status for in-window events.
    let event = rpc.data;
    if (decision === 'approved' && event) {
      const nextStatus = computeLifecycleStatus(
        event.starts_at,
        event.ends_at,
        event.status === 'cancelled' ? 'scheduled' : event.status,
      );
      if (nextStatus !== event.status) {
        const { data: synced } = await supabaseAdmin
          .from('club_events')
          .update({ status: nextStatus })
          .eq('id', event.id)
          .select()
          .single();
        if (synced) event = synced;
      }
    }
    if (decision === 'rejected' && event && event.status !== 'cancelled') {
      const { data: cancelled } = await supabaseAdmin
        .from('club_events')
        .update({ status: 'cancelled' })
        .eq('id', event.id)
        .select()
        .single();
      if (cancelled) event = cancelled;
    }

    res.json({ event, conflicts, via: 'rpc' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.patch('/:id', requireAdmin, async (req, res) => {
  const patch = {};
  const map = {
    title: 'title',
    description: 'description',
    branch: 'branch',
    startsAt: 'starts_at',
    endsAt: 'ends_at',
    capacity: 'capacity',
    vipOnly: 'vip_only',
    status: 'status',
  };
  for (const [k, col] of Object.entries(map)) {
    if (req.body[k] !== undefined) patch[col] = req.body[k];
  }

  if (patch.starts_at != null) {
    patch.starts_at = new Date(patch.starts_at).toISOString();
  }
  if (patch.ends_at != null) {
    patch.ends_at = new Date(patch.ends_at).toISOString();
  }

  const { data: current, error: fetchError } = await supabaseAdmin
    .from('club_events')
    .select('starts_at, ends_at, status, branch')
    .eq('id', req.params.id)
    .single();
  if (fetchError) return res.status(404).json({ error: fetchError.message });

  if (patch.branch !== undefined) {
    const activeBranches = await loadActiveBranches();
    const resolvedBranch = resolveBranchName(activeBranches, patch.branch);
    if (!resolvedBranch) {
      const err = branchChoiceError(activeBranches);
      return res.status(err.status).json(err.body);
    }
    patch.branch = resolvedBranch;
  }

  const startIso = patch.starts_at ?? current.starts_at;
  const endIso = patch.ends_at ?? current.ends_at;
  const branchForConflicts = patch.branch ?? current.branch;

  // Validate window when either bound is changing.
  if (patch.starts_at != null || patch.ends_at != null) {
    if (!startIso || !endIso) {
      return res.status(400).json({ error: 'Start and end times are required.' });
    }
    if (new Date(endIso) <= new Date(startIso)) {
      return res.status(400).json({ error: 'End time must be after start time.' });
    }

    // Recompute lifecycle unless explicitly cancelling / un-cancelling.
    if (patch.status !== 'cancelled') {
      const baseStatus =
        patch.status === undefined && current.status === 'cancelled'
          ? 'cancelled'
          : patch.status || current.status || 'scheduled';
      if (baseStatus !== 'cancelled') {
        patch.status = computeLifecycleStatus(startIso, endIso, baseStatus);
      }
    }

    try {
      const conflicts = await findConflictsForWindow(
        startIso,
        endIso,
        req.params.id,
        branchForConflicts,
      );
      if (conflicts.length > 0 && !req.body.force) {
        return res.status(409).json({
          error: 'This event overlaps one or more existing events at the same branch.',
          conflicts,
        });
      }
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  } else if (patch.branch !== undefined) {
    try {
      const conflicts = await findConflictsForWindow(
        startIso,
        endIso,
        req.params.id,
        branchForConflicts,
      );
      if (conflicts.length > 0 && !req.body.force) {
        return res.status(409).json({
          error: 'This event overlaps one or more existing events at the same branch.',
          conflicts,
        });
      }
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  } else if (patch.status != null && patch.status !== 'cancelled') {
    patch.status = computeLifecycleStatus(
      current.starts_at,
      current.ends_at,
      patch.status,
    );
  }

  // Keep admin edits operable for invite/check-in.
  if (patch.status === 'live' || patch.status === 'scheduled' || patch.status === 'completed') {
    patch.approval_status = 'approved';
    patch.approved_at = new Date().toISOString();
  }

  const { data, error } = await supabaseAdmin
    .from('club_events')
    .update(patch)
    .eq('id', req.params.id)
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ event: data });
});

router.delete('/:id', requireAdmin, async (req, res) => {
  const { error } = await supabaseAdmin.from('club_events').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

export default router;
