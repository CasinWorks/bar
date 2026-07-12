import { createClient } from '@supabase/supabase-js';
import ws from 'ws';

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const anonKey = process.env.SUPABASE_ANON_KEY;

if (!url || !serviceKey || !anonKey) {
  throw new Error(
    'Missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or SUPABASE_ANON_KEY. ' +
      'Copy .env.example to .env and fill in real values from Supabase project settings.',
  );
}

// Supabase Realtime requires a WebSocket implementation on Node < 22.
// The admin API doesn't need realtime, but supabase-js initializes it by default.
// Providing ws avoids runtime crashes on Node 20.
if (typeof globalThis.WebSocket === 'undefined') {
  globalThis.WebSocket = ws;
}

export const supabaseAdmin = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

export function supabaseAsUser(jwt) {
  return createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
