import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatDate } from '../lib/api';

export default function DownloadInvitesPage() {
  const { token } = useAuth();
  const [invites, setInvites] = useState([]);
  const [err, setErr] = useState('');
  const [msg, setMsg] = useState('');
  const [busy, setBusy] = useState(false);
  const [label, setLabel] = useState('');
  const [note, setNote] = useState('');
  const [maxRedemptions, setMaxRedemptions] = useState('25');
  const [customCode, setCustomCode] = useState('');
  const [expiresAt, setExpiresAt] = useState('');

  async function load() {
    const data = await api('/api/download/invites', { token });
    setInvites(data.invites || []);
  }

  useEffect(() => {
    load().catch((e) => setErr(e.message));
  }, [token]);

  async function createInvite(event) {
    event.preventDefault();
    setBusy(true);
    setErr('');
    setMsg('');
    try {
      const body = {
        label: label.trim() || null,
        note: note.trim() || null,
        maxRedemptions:
          maxRedemptions === '' || maxRedemptions === 'unlimited'
            ? null
            : Number(maxRedemptions),
      };
      if (customCode.trim()) body.code = customCode.trim().toUpperCase();
      if (expiresAt) body.expiresAt = new Date(expiresAt).toISOString();

      const data = await api('/api/download/invites', {
        method: 'POST',
        token,
        body,
      });
      setMsg(`Created ${data.invite.code}`);
      setLabel('');
      setNote('');
      setCustomCode('');
      setExpiresAt('');
      setMaxRedemptions('25');
      await load();
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function revokeInvite(invite) {
    const confirmed = window.confirm(`Revoke invite code ${invite.code}?`);
    if (!confirmed) return;
    try {
      setErr('');
      setMsg('');
      await api(`/api/download/invites/${invite.id}/revoke`, {
        method: 'POST',
        token,
        body: {},
      });
      setMsg(`Revoked ${invite.code}`);
      await load();
    } catch (e) {
      setErr(e.message);
    }
  }

  async function copyCode(code) {
    try {
      await navigator.clipboard.writeText(code);
      setMsg(`Copied ${code}`);
    } catch {
      setErr('Could not copy to clipboard.');
    }
  }

  return (
    <div>
      <h2 className="page-title">App download invites</h2>
      <p className="page-sub">
        Mint invite-only codes for the public <code>/download</code> page. Guests unlock iOS
        TestFlight and Android APK QR codes after entering a valid code.
      </p>

      {err && <p className="error">{err}</p>}
      {msg && <p className="success">{msg}</p>}

      <section className="card" style={{ marginBottom: 24 }}>
        <h3 style={{ marginTop: 0 }}>Create code</h3>
        <form onSubmit={createInvite}>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
              gap: 12,
            }}
          >
            <div>
              <label>Label (optional)</label>
              <input
                value={label}
                onChange={(e) => setLabel(e.target.value)}
                placeholder="Pilot batch · Cubao desk"
              />
            </div>
            <div>
              <label>Max redemptions</label>
              <input
                value={maxRedemptions}
                onChange={(e) => setMaxRedemptions(e.target.value)}
                placeholder="25 or unlimited"
              />
            </div>
            <div>
              <label>Custom code (optional)</label>
              <input
                value={customCode}
                onChange={(e) => setCustomCode(e.target.value.toUpperCase())}
                placeholder="Leave blank to auto-generate BT-…"
                autoCapitalize="characters"
              />
            </div>
            <div>
              <label>Expires (optional)</label>
              <input
                type="datetime-local"
                value={expiresAt}
                onChange={(e) => setExpiresAt(e.target.value)}
              />
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <label>Note (optional)</label>
              <input
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="Internal note"
              />
            </div>
          </div>
          <button className="btn" type="submit" disabled={busy} style={{ marginTop: 14 }}>
            {busy ? 'Creating…' : 'Generate invite'}
          </button>
        </form>
      </section>

      <section className="card">
        <h3 style={{ marginTop: 0 }}>Active & recent codes</h3>
        <div style={{ overflowX: 'auto' }}>
          <table>
            <thead>
              <tr>
                <th>Code</th>
                <th>Label</th>
                <th>Uses</th>
                <th>Expires</th>
                <th>Status</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {invites.length === 0 && (
                <tr>
                  <td colSpan={6} className="page-sub">
                    No download invites yet.
                  </td>
                </tr>
              )}
              {invites.map((invite) => {
                const exhausted =
                  invite.maxRedemptions != null &&
                  invite.redemptionCount >= invite.maxRedemptions;
                const expired =
                  invite.expiresAt && new Date(invite.expiresAt).getTime() <= Date.now();
                let status = 'active';
                if (invite.revokedAt) status = 'revoked';
                else if (expired) status = 'expired';
                else if (exhausted) status = 'exhausted';

                return (
                  <tr key={invite.id}>
                    <td>
                      <button
                        type="button"
                        className="btn btn-secondary btn-sm"
                        onClick={() => copyCode(invite.code)}
                      >
                        {invite.code}
                      </button>
                    </td>
                    <td>
                      {invite.label || '—'}
                      {invite.note ? (
                        <div className="page-sub" style={{ margin: 0 }}>
                          {invite.note}
                        </div>
                      ) : null}
                    </td>
                    <td>
                      {invite.redemptionCount}
                      {invite.maxRedemptions == null ? ' / ∞' : ` / ${invite.maxRedemptions}`}
                    </td>
                    <td>{invite.expiresAt ? formatDate(invite.expiresAt) : '—'}</td>
                    <td>
                      <span className={`badge ${status === 'active' ? 'badge-gold' : ''}`}>
                        {status}
                      </span>
                    </td>
                    <td>
                      {!invite.revokedAt && (
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          onClick={() => revokeInvite(invite)}
                        >
                          Revoke
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
