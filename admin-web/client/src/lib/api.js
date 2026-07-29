function resolveApiUrl() {
  const raw = import.meta.env.VITE_API_URL;
  // Never ship a localhost API URL in production (causes browser "Load failed").
  if (import.meta.env.PROD) {
    if (!raw || raw.includes('localhost') || raw.includes('127.0.0.1')) return '';
    return raw;
  }
  return raw || 'http://localhost:4000';
}

const API_URL = resolveApiUrl();

export async function api(path, { method = 'GET', body, token } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;

  let res;
  try {
    res = await fetch(`${API_URL}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (e) {
    throw new Error(
      `Network error talking to API (${API_URL || 'same-origin'}${path}): ${e.message}`,
    );
  }

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(data.error || `Request failed (${res.status})`);
    err.status = res.status;
    if (data.conflicts) err.conflicts = data.conflicts;
    throw err;
  }
  return data;
}

export function formatDuration(seconds) {
  if (!seconds) return '0m';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

export function formatTimeLoad(user) {
  return formatDuration(user?.time_balance_seconds ?? 0);
}

export function formatPeso(n) {
  return `₱${Number(n || 0).toLocaleString()}`;
}

export function formatDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleString();
}
