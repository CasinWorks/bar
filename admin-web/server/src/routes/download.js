import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin, requireAdminOnly } from '../middleware/auth.js';

const router = Router();

const DEFAULT_IOS_URL = 'https://testflight.apple.com/join/9yKpM4rz';
const DEFAULT_ANDROID_BUCKET = 'app-releases';
const SIGNED_URL_TTL_SECONDS = 60 * 15; // 15 minutes

// The universal APK is ~90 MB, over the 50 MB per-file ceiling on Supabase's
// free plan, so per-ABI splits are the shipped artifacts. arm64-v8a covers
// current Android hardware; the others are fallbacks for older/emulated devices.
const ANDROID_OBJECT_CANDIDATES = [
  { object: 'app-arm64-v8a-release.apk', abi: 'arm64-v8a' },
  { object: 'app-armeabi-v7a-release.apk', abi: 'armeabi-v7a' },
  { object: 'app-x86_64-release.apk', abi: 'x86_64' },
  { object: 'app-release.apk', abi: 'universal' },
];

/** Simple in-memory rate limit for public unlock (per IP). */
const unlockAttempts = new Map();
const UNLOCK_WINDOW_MS = 60_000;
const UNLOCK_MAX_PER_WINDOW = 12;

function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim()) {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || req.socket?.remoteAddress || 'unknown';
}

function rateLimitUnlock(req, res) {
  const ip = clientIp(req);
  const now = Date.now();
  let bucket = unlockAttempts.get(ip);
  if (!bucket || now - bucket.windowStart > UNLOCK_WINDOW_MS) {
    bucket = { windowStart: now, count: 0 };
    unlockAttempts.set(ip, bucket);
  }
  bucket.count += 1;
  if (bucket.count > UNLOCK_MAX_PER_WINDOW) {
    res.status(429).json({ error: 'Too many attempts. Try again in a minute.' });
    return false;
  }
  return true;
}

function normalizeCode(raw) {
  return String(raw || '')
    .trim()
    .toUpperCase()
    .replace(/\s+/g, '');
}

function iosDownloadUrl() {
  return (process.env.APP_IOS_DOWNLOAD_URL || DEFAULT_IOS_URL).trim();
}

async function resolveAndroidDownloadUrl() {
  const direct = (process.env.APP_ANDROID_DOWNLOAD_URL || '').trim();
  if (direct) return { url: direct, abi: null };

  const bucket = (process.env.APP_ANDROID_STORAGE_BUCKET || DEFAULT_ANDROID_BUCKET).trim();
  const override = (process.env.APP_ANDROID_STORAGE_OBJECT || '').trim();
  const candidates = override
    ? [{ object: override, abi: null }, ...ANDROID_OBJECT_CANDIDATES]
    : ANDROID_OBJECT_CANDIDATES;

  const storage = supabaseAdmin.storage.from(bucket);
  let lastError = null;

  for (const candidate of candidates) {
    const { data, error } = await storage.createSignedUrl(
      candidate.object,
      SIGNED_URL_TTL_SECONDS,
    );
    if (!error && data?.signedUrl) {
      return { url: data.signedUrl, abi: candidate.abi };
    }
    lastError = error;
  }

  throw new Error(
    'Android build is not available yet. Upload the split APKs from ' +
      '`flutter build apk --split-per-abi` to Supabase Storage ' +
      `(${bucket}/app-arm64-v8a-release.apk).` +
      (lastError?.message ? ` Last storage error: ${lastError.message}` : ''),
  );
}

function mapInviteRow(row) {
  return {
    id: row.id,
    code: row.code,
    label: row.label,
    note: row.note,
    maxRedemptions: row.max_redemptions,
    redemptionCount: row.redemption_count,
    expiresAt: row.expires_at,
    revokedAt: row.revoked_at,
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/**
 * Public: redeem invite code → iOS + Android download URLs (never leak APK without code).
 */
router.post('/unlock', async (req, res) => {
  if (!rateLimitUnlock(req, res)) return;

  const code = normalizeCode(req.body?.code);
  if (!code) {
    return res.status(400).json({ error: 'Invite code is required.' });
  }

  // Ensure download targets are ready before consuming a redemption.
  let iosUrl;
  let android;
  try {
    iosUrl = iosDownloadUrl();
    if (!iosUrl) {
      return res.status(503).json({ error: 'iOS download is not configured.' });
    }
    android = await resolveAndroidDownloadUrl();
  } catch (err) {
    console.error('download unlock urls failed', err);
    return res.status(503).json({
      error: err.message || 'Download links are temporarily unavailable.',
    });
  }

  const { data: redeem, error: redeemError } = await supabaseAdmin.rpc(
    'redeem_app_download_invite',
    { p_code: code },
  );

  if (redeemError) {
    const message = redeemError.message || 'Invalid invite code.';
    const status = /required|invalid|revoked|expired|redemptions/i.test(message) ? 400 : 500;
    return res.status(status).json({ error: message });
  }

  if (!redeem?.ok) {
    return res.status(400).json({ error: 'Invalid invite code.' });
  }

  return res.json({
    iosUrl,
    androidUrl: android.url,
    androidAbi: android.abi,
    code: redeem.code,
  });
});

/**
 * Admin: list invite codes.
 */
router.get('/invites', requireAdmin, requireAdminOnly, async (_req, res) => {
  const { data, error } = await supabaseAdmin
    .from('app_download_invites')
    .select(
      'id, code, label, note, max_redemptions, redemption_count, expires_at, revoked_at, created_by, created_at, updated_at',
    )
    .order('created_at', { ascending: false })
    .limit(200);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ invites: (data ?? []).map(mapInviteRow) });
});

/**
 * Admin: mint a new invite code.
 */
router.post('/invites', requireAdmin, requireAdminOnly, async (req, res) => {
  const label =
    req.body?.label == null || req.body.label === ''
      ? null
      : String(req.body.label).trim().slice(0, 120);
  const note =
    req.body?.note == null || req.body.note === ''
      ? null
      : String(req.body.note).trim().slice(0, 500);

  let maxRedemptions = 25;
  if (req.body?.maxRedemptions !== undefined || req.body?.max_redemptions !== undefined) {
    const raw = req.body.maxRedemptions ?? req.body.max_redemptions;
    if (raw === null || raw === '' || raw === 'unlimited') {
      maxRedemptions = null;
    } else {
      const n = Number(raw);
      if (!Number.isFinite(n) || !Number.isInteger(n) || n < 1) {
        return res.status(400).json({ error: 'maxRedemptions must be a positive integer or unlimited.' });
      }
      maxRedemptions = n;
    }
  }

  let expiresAt = null;
  if (req.body?.expiresAt || req.body?.expires_at) {
    const parsed = new Date(req.body.expiresAt ?? req.body.expires_at);
    if (Number.isNaN(parsed.getTime())) {
      return res.status(400).json({ error: 'expiresAt must be a valid date.' });
    }
    expiresAt = parsed.toISOString();
  }

  let code = normalizeCode(req.body?.code);
  if (!code) {
    const { data: generated, error: genError } = await supabaseAdmin.rpc(
      'generate_app_download_invite_code',
    );
    if (genError || !generated) {
      return res.status(500).json({ error: genError?.message || 'Could not generate invite code.' });
    }
    code = normalizeCode(generated);
  }

  if (!/^[A-Z0-9-]{4,32}$/.test(code)) {
    return res.status(400).json({
      error: 'Code must be 4–32 characters: letters, numbers, and hyphens only.',
    });
  }

  const { data, error } = await supabaseAdmin
    .from('app_download_invites')
    .insert({
      code,
      label,
      note,
      max_redemptions: maxRedemptions,
      expires_at: expiresAt,
      created_by: req.user.id,
    })
    .select(
      'id, code, label, note, max_redemptions, redemption_count, expires_at, revoked_at, created_by, created_at, updated_at',
    )
    .single();

  if (error) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'That invite code already exists.' });
    }
    return res.status(500).json({ error: error.message });
  }

  res.status(201).json({ invite: mapInviteRow(data) });
});

/**
 * Admin: revoke an invite code.
 */
router.post('/invites/:id/revoke', requireAdmin, requireAdminOnly, async (req, res) => {
  const id = req.params.id;
  const { data, error } = await supabaseAdmin
    .from('app_download_invites')
    .update({ revoked_at: new Date().toISOString() })
    .eq('id', id)
    .is('revoked_at', null)
    .select(
      'id, code, label, note, max_redemptions, redemption_count, expires_at, revoked_at, created_by, created_at, updated_at',
    )
    .maybeSingle();

  if (error) return res.status(500).json({ error: error.message });
  if (!data) return res.status(404).json({ error: 'Invite not found or already revoked.' });
  res.json({ invite: mapInviteRow(data) });
});

export default router;
