import express from 'express';
import { createClient } from '@supabase/supabase-js';
import crypto from 'node:crypto';

const router = express.Router();

function adminClient() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error('Supabase admin env missing.');
  return createClient(url, key, { auth: { persistSession: false } });
}

function assertPushSecret(req, res) {
  const expected = process.env.PUSH_WEBHOOK_SECRET;
  if (!expected) return true;
  const got =
    req.get('x-push-secret') ||
    req.query.secret ||
    // Vercel Cron sends Authorization: Bearer <CRON_SECRET>
    (req.get('authorization') || '').replace(/^Bearer\s+/i, '');
  const cronSecret = process.env.CRON_SECRET;
  if (got === expected || (cronSecret && got === cronSecret)) {
    return true;
  }
  res.status(401).json({ error: 'Unauthorized' });
  return false;
}

function loadServiceAccount() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) {
    throw new Error(
      'FIREBASE_SERVICE_ACCOUNT_JSON missing. Paste the Firebase service account JSON as a single-line env var.',
    );
  }
  return JSON.parse(raw);
}

let cachedAccessToken = null;
let cachedAccessTokenExp = 0;

async function getFirebaseAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessTokenExp > now + 60) {
    return cachedAccessToken;
  }

  const sa = loadServiceAccount();
  const iat = now;
  const exp = now + 3600;
  const header = Buffer.from(
    JSON.stringify({ alg: 'RS256', typ: 'JWT' }),
  ).toString('base64url');
  const claims = Buffer.from(
    JSON.stringify({
      iss: sa.client_email,
      sub: sa.client_email,
      aud: 'https://oauth2.googleapis.com/token',
      iat,
      exp,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
    }),
  ).toString('base64url');
  const unsigned = `${header}.${claims}`;
  const sig = crypto.sign('RSA-SHA256', Buffer.from(unsigned), sa.private_key);
  const jwt = `${unsigned}.${Buffer.from(sig).toString('base64url')}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const json = await res.json();
  if (!res.ok || !json.access_token) {
    throw new Error(`Firebase auth failed: ${JSON.stringify(json)}`);
  }
  cachedAccessToken = json.access_token;
  cachedAccessTokenExp = now + Number(json.expires_in || 3600);
  return cachedAccessToken;
}

async function sendFcm({ projectId, accessToken, token, title, body, data }) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const stringData = {};
  for (const [k, v] of Object.entries(data || {})) {
    if (v == null) continue;
    stringData[k] = typeof v === 'string' ? v : JSON.stringify(v);
  }
  stringData.title = title;
  stringData.body = body;

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data: stringData,
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              alert: { title, body },
              sound: 'default',
              'mutable-content': 1,
            },
          },
        },
        android: {
          priority: 'HIGH',
          notification: {
            channel_id: 'blind_tiger_social',
            sound: 'default',
          },
        },
      },
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    console.error('FCM error', res.status, text);
    return false;
  }
  return true;
}

async function drainQueue(limit = 40) {
  const supabase = adminClient();
  const { data: rows, error } = await supabase
    .from('push_dispatch_queue')
    .select('id, recipient_id, title, body, data')
    .is('dispatched_at', null)
    .order('created_at', { ascending: true })
    .limit(limit);

  if (error) throw error;
  if (!rows?.length) return { processed: 0, sent: 0 };

  const sa = loadServiceAccount();
  const accessToken = await getFirebaseAccessToken();
  const projectId = process.env.FIREBASE_PROJECT_ID || sa.project_id;
  let sent = 0;

  for (const row of rows) {
    const { data: tokens } = await supabase
      .from('device_push_tokens')
      .select('token, kind')
      .eq('user_id', row.recipient_id)
      .in('kind', ['fcm', 'apns']);

    for (const t of tokens || []) {
      // Prefer FCM tokens; skip raw APNs when using Firebase path.
      if (t.kind !== 'fcm') continue;
      const ok = await sendFcm({
        projectId,
        accessToken,
        token: t.token,
        title: row.title,
        body: row.body,
        data: row.data || {},
      });
      if (ok) sent += 1;
    }

    await supabase
      .from('push_dispatch_queue')
      .update({ dispatched_at: new Date().toISOString() })
      .eq('id', row.id);
  }

  return { processed: rows.length, sent };
}

/** Cron / Database webhook: drain pending social push jobs via FCM. */
async function handleDrain(req, res) {
  if (!assertPushSecret(req, res)) return;
  try {
    const result = await drainQueue();
    res.json({ ok: true, ...result });
  } catch (e) {
    res.status(503).json({ ok: false, error: e.message });
  }
}

router.post('/drain', handleDrain);
router.get('/drain', handleDrain);

export default router;
