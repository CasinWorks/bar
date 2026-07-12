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

function getClients() {
  const url = requireEnv('SUPABASE_URL');
  const serviceKey = requireEnv('SUPABASE_SERVICE_ROLE_KEY');
  const anonKey = requireEnv('SUPABASE_ANON_KEY');

  if (typeof globalThis.WebSocket === 'undefined') {
    globalThis.WebSocket = ws;
  }

  return {
    supabaseAdmin: createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    }),
    anonKey,
    url,
  };
}

let cached;

function clients() {
  if (!cached) cached = getClients();
  return cached;
}

export const supabaseAdmin = new Proxy(
  {},
  {
    get(_target, prop) {
      return clients().supabaseAdmin[prop];
    },
  },
);

export function supabaseAsUser(jwt) {
  const { url, anonKey } = clients();
  return createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
