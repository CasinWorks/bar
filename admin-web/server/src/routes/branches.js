import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin, requireAdminOnly } from '../middleware/auth.js';

const router = Router();

const LIVE_PHASES = ['inside_club', 'awaiting_exit_scan'];

/** Matches supabase/migrations/023_branches.sql. There is no `city` column. */
const BRANCH_COLUMNS =
  'id, slug, name, sort_order, is_active, is_default, created_at, updated_at';

/** Tables that denormalise the branch *name* and must follow a rename. */
const BRANCH_NAME_REFERENCES = ['club_events', 'club_sessions', 'profiles'];

function slugify(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
}

function normalizeName(value) {
  return String(value ?? '').trim().replace(/\s+/g, ' ');
}

function isUniqueViolation(error) {
  return error?.code === '23505';
}

function uniqueMessage(error) {
  return /slug/.test(error?.message || '')
    ? 'A branch with that slug already exists.'
    : 'A branch with that name already exists.';
}

async function listBranches() {
  const { data, error } = await supabaseAdmin
    .from('branches')
    .select(BRANCH_COLUMNS)
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

/** Guest/event counts per branch name so admins can see impact before editing. */
async function loadBranchUsage() {
  const usage = new Map();
  const bump = (name, key) => {
    const branchName = normalizeName(name);
    if (!branchName) return;
    const entry = usage.get(branchName) || { eventCount: 0, liveCount: 0 };
    entry[key] += 1;
    usage.set(branchName, entry);
  };

  const [events, sessions] = await Promise.all([
    supabaseAdmin.from('club_events').select('branch'),
    supabaseAdmin.from('club_sessions').select('branch').in('phase', LIVE_PHASES),
  ]);

  for (const row of events.data ?? []) bump(row.branch, 'eventCount');
  for (const row of sessions.data ?? []) bump(row.branch, 'liveCount');
  return usage;
}

function decorate(branches, usage) {
  return branches.map((branch) => {
    const stats = usage.get(normalizeName(branch.name)) || {};
    return {
      ...branch,
      eventCount: stats.eventCount ?? 0,
      liveCount: stats.liveCount ?? 0,
    };
  });
}

async function clearOtherDefaults(keepId) {
  const { error } = await supabaseAdmin
    .from('branches')
    .update({ is_default: false })
    .eq('is_default', true)
    .neq('id', keepId);
  if (error) throw error;
}

/**
 * Branch names are stored as text on sessions/events/profiles, so a rename has
 * to carry those rows along or live guests and scheduled events get orphaned.
 */
async function cascadeRename(oldName, newName) {
  const warnings = [];
  for (const table of BRANCH_NAME_REFERENCES) {
    const { error } = await supabaseAdmin
      .from(table)
      .update({ branch: newName })
      .eq('branch', oldName);
    if (error) {
      warnings.push(`Could not re-point ${table}.branch to “${newName}”: ${error.message}`);
    }
  }
  return warnings;
}

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

/** Active branches only — powers the branch picker on event creation. */
router.get('/active', requireAdmin, async (_req, res) => {
  try {
    const branches = (await listBranches()).filter((branch) => branch.is_active);
    res.json({ branches });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/** Full catalog including deactivated branches (admin branch manager). */
router.get('/', requireAdmin, async (_req, res) => {
  try {
    const [branches, usage] = await Promise.all([listBranches(), loadBranchUsage()]);
    res.json({ branches: decorate(branches, usage) });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/', requireAdmin, requireAdminOnly, async (req, res) => {
  const name = normalizeName(req.body?.name);
  if (!name) return res.status(400).json({ error: 'Branch name is required.' });

  const slug = slugify(req.body?.slug ?? name);
  if (!slug) {
    return res.status(400).json({ error: 'Branch name must contain letters or numbers.' });
  }

  try {
    const existing = await listBranches();
    const isFirstBranch = existing.length === 0;

    let sortOrder = Number(req.body?.sortOrder ?? req.body?.sort_order);
    if (!Number.isInteger(sortOrder) || sortOrder < 0) {
      sortOrder = existing.reduce((max, b) => Math.max(max, b.sort_order ?? 0), 0) + 1;
    }

    const isActive = req.body?.isActive === undefined ? true : Boolean(req.body.isActive);
    const isDefault = isFirstBranch || Boolean(req.body?.isDefault);

    const { data, error } = await supabaseAdmin
      .from('branches')
      .insert({
        slug,
        name,
        sort_order: sortOrder,
        is_active: isFirstBranch ? true : isActive,
        is_default: isDefault && (isFirstBranch || isActive),
      })
      .select(BRANCH_COLUMNS)
      .single();

    if (error) {
      if (isUniqueViolation(error)) {
        return res.status(400).json({ error: uniqueMessage(error) });
      }
      return res.status(500).json({ error: error.message });
    }

    if (data.is_default) await clearOtherDefaults(data.id);
    res.json({ branch: { ...data, eventCount: 0, liveCount: 0 } });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.patch('/:id', requireAdmin, requireAdminOnly, async (req, res) => {
  try {
    const branches = await listBranches();
    const current = branches.find((b) => b.id === req.params.id);
    if (!current) return res.status(404).json({ error: 'Branch not found.' });

    const patch = {};
    const warnings = [];

    if (req.body?.name !== undefined) {
      const name = normalizeName(req.body.name);
      if (!name) return res.status(400).json({ error: 'Branch name cannot be empty.' });
      if (name !== current.name) patch.name = name;
    }

    if (req.body?.slug !== undefined) {
      const slug = slugify(req.body.slug);
      if (!slug) return res.status(400).json({ error: 'Slug cannot be empty.' });
      if (slug !== current.slug) patch.slug = slug;
    }

    if (req.body?.sortOrder !== undefined || req.body?.sort_order !== undefined) {
      const sortOrder = Number(req.body.sortOrder ?? req.body.sort_order);
      if (!Number.isInteger(sortOrder) || sortOrder < 0) {
        return res.status(400).json({ error: 'Sort order must be a whole number >= 0.' });
      }
      patch.sort_order = sortOrder;
    }

    const nextActive =
      req.body?.isActive === undefined ? current.is_active : Boolean(req.body.isActive);
    if (nextActive !== current.is_active) {
      const otherActive = branches.filter((b) => b.id !== current.id && b.is_active);
      if (!nextActive && otherActive.length === 0) {
        return res.status(400).json({
          error: 'At least one branch must stay active — activate another branch first.',
        });
      }
      patch.is_active = nextActive;
    }

    const askedDefault =
      req.body?.isDefault === undefined ? current.is_default : Boolean(req.body.isDefault);
    if (askedDefault && !nextActive) {
      return res.status(400).json({ error: 'A deactivated branch cannot be the default.' });
    }
    // Deactivating always drops the default flag; it is handed on further down.
    const wantsDefault = nextActive ? askedDefault : false;
    if (nextActive && !wantsDefault && current.is_default) {
      return res.status(400).json({
        error: 'Set another branch as default instead of clearing this one.',
      });
    }
    if (wantsDefault !== current.is_default) {
      patch.is_default = wantsDefault;
    }

    if (Object.keys(patch).length === 0) {
      return res.json({ branch: current, warnings });
    }

    const { data, error } = await supabaseAdmin
      .from('branches')
      .update(patch)
      .eq('id', current.id)
      .select(BRANCH_COLUMNS)
      .single();

    if (error) {
      if (isUniqueViolation(error)) {
        return res.status(400).json({ error: uniqueMessage(error) });
      }
      return res.status(500).json({ error: error.message });
    }

    if (patch.name) {
      warnings.push(...(await cascadeRename(current.name, patch.name)));
    }
    if (data.is_default) {
      await clearOtherDefaults(data.id);
    }

    // Deactivating the default hands the crown to the next active branch.
    if (patch.is_active === false && current.is_default) {
      const nextDefault = branches
        .filter((b) => b.id !== current.id && b.is_active)
        .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))[0];
      if (nextDefault) {
        await supabaseAdmin
          .from('branches')
          .update({ is_default: true })
          .eq('id', nextDefault.id);
        await clearOtherDefaults(nextDefault.id);
        warnings.push(`“${nextDefault.name}” is now the default branch.`);
      }
    }

    const usage = await loadBranchUsage();
    const [fresh] = decorate([data], usage);
    res.json({ branch: fresh, warnings });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/** Soft delete: deactivate so historical sessions/events keep a resolvable name. */
router.delete('/:id', requireAdmin, requireAdminOnly, async (req, res) => {
  try {
    const branches = await listBranches();
    const current = branches.find((b) => b.id === req.params.id);
    if (!current) return res.status(404).json({ error: 'Branch not found.' });

    const otherActive = branches.filter((b) => b.id !== current.id && b.is_active);
    if (current.is_active && otherActive.length === 0) {
      return res.status(400).json({
        error: 'At least one branch must stay active — activate another branch first.',
      });
    }

    const { data, error } = await supabaseAdmin
      .from('branches')
      .update({ is_active: false, is_default: false })
      .eq('id', current.id)
      .select(BRANCH_COLUMNS)
      .single();
    if (error) return res.status(500).json({ error: error.message });

    const warnings = [];
    if (current.is_default) {
      const nextDefault = otherActive.sort(
        (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
      )[0];
      if (nextDefault) {
        await supabaseAdmin
          .from('branches')
          .update({ is_default: true })
          .eq('id', nextDefault.id);
        await clearOtherDefaults(nextDefault.id);
        warnings.push(`“${nextDefault.name}” is now the default branch.`);
      }
    }

    res.json({ branch: data, ok: true, warnings });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/live', requireAdmin, async (_req, res) => {
  try {
    const { data: configuredBranches, error: branchError } = await supabaseAdmin
      .from('branches')
      .select('id, slug, name, is_active, is_default')
      .eq('is_active', true)
      .order('sort_order', { ascending: true })
      .order('name', { ascending: true });

    if (branchError) throw branchError;

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
    for (const branch of configuredBranches ?? []) {
      byBranch.set(branch.name, {
        id: branch.slug || branch.id,
        name: branch.name,
        slug: branch.slug || null,
        isDefault: Boolean(branch.is_default),
        configured: true,
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
          slug: null,
          isDefault: false,
          configured: false,
          count: 0,
          guests: [],
        });
      }
      const bucket = byBranch.get(branchName);
      bucket.guests.push(formatGuest(row, profilesById[row.member_id]));
      bucket.count = bucket.guests.length;
    }

    const configuredNames = new Set((configuredBranches ?? []).map((branch) => branch.name));
    const branches = [
      ...(configuredBranches ?? []).map((branch) => byBranch.get(branch.name)),
      ...[...byBranch.values()].filter((branch) => !configuredNames.has(branch.name)),
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
