import { createClient } from '@supabase/supabase-js';
import ws from 'ws';

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(
      `Missing ${name}. Set it in Vercel Project Settings → Environment Variables, ` +
        'or in admin-web/server/.env for local development.',
    );
  }
  return value;
}

let cachedAdmin = null;
let cachedUrl = null;
let cachedAnonKey = null;

function ensureClients() {
  if (cachedAdmin) return;

  const url = requireEnv('SUPABASE_URL');
  const serviceKey = requireEnv('SUPABASE_SERVICE_ROLE_KEY');
  const anonKey = requireEnv('SUPABASE_ANON_KEY');

  if (typeof globalThis.WebSocket === 'undefined') {
    globalThis.WebSocket = ws;
  }

  cachedUrl = url;
  cachedAnonKey = anonKey;
  cachedAdmin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export const supabaseAdmin = {
  from(...args) {
    ensureClients();
    return cachedAdmin.from(...args);
  },
  get auth() {
    ensureClients();
    return cachedAdmin.auth;
  },
  get storage() {
    ensureClients();
    return cachedAdmin.storage;
  },
  rpc(...args) {
    ensureClients();
    return cachedAdmin.rpc(...args);
  },
};

export function supabaseAsUser(jwt) {
  ensureClients();
  return createClient(cachedUrl, cachedAnonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
