import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatDate } from '../lib/api';

function EmptyRow({ colSpan, children = 'No records yet.' }) {
  return (
    <tr>
      <td colSpan={colSpan} style={{ color: 'var(--muted)' }}>
        {children}
      </td>
    </tr>
  );
}

function StatusBadge({ value }) {
  const normalized = String(value || 'pending').toLowerCase();
  const cls =
    normalized.includes('open') || normalized.includes('pending')
      ? 'badge-red'
      : normalized.includes('completed') || normalized.includes('stored')
        ? 'badge-green'
        : 'badge-gold';
  return <span className={`badge ${cls}`}>{value || 'pending'}</span>;
}

export default function SafetySocialPage() {
  const { token } = useAuth();
  const [data, setData] = useState(null);
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  async function refresh() {
    setErr('');
    const next = await api('/api/safety-social/overview', { token });
    setData(next);
  }

  useEffect(() => {
    let cancelled = false;
    setErr('');
    api('/api/safety-social/overview', { token })
      .then((next) => {
        if (!cancelled) setData(next);
      })
      .catch((e) => {
        if (!cancelled) setErr(e.message);
      });
    return () => {
      cancelled = true;
    };
  }, [token]);

  async function runAutoBadgeOut() {
    setBusy(true);
    setErr('');
    try {
      await api('/api/safety-social/auto-badge-out', { method: 'POST', token });
      await refresh();
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }

  if (err) return <p className="error">{err}</p>;
  if (!data) return <p>Loading safety & social desk…</p>;

  return (
    <>
      <h2 className="page-title">Safety & Social Desk</h2>
      <p className="page-sub">
        Admin view for friend requests, mutual social safety, reports, rides, insurance,
        and 48-hour auto badge-out.
      </p>

      {!data.migrationReady && (
        <div className="card warning-card">
          <strong>Database migration pending</strong>
          <p>
            The admin page is ready, but the live Supabase project still needs
            <code> 013_friends_safety.sql </code>
            and
            <code> 014_auto_badge_out.sql </code>
            applied for real cross-device records.
          </p>
        </div>
      )}

      <div className="grid grid-4">
        <div className="card">
          <div className="stat-value">{data.counts.safetyReports}</div>
          <div className="stat-label">Safety reports</div>
        </div>
        <div className="card">
          <div className="stat-value">{data.counts.rideRequests}</div>
          <div className="stat-label">Ride assists</div>
        </div>
        <div className="card">
          <div className="stat-value">{data.counts.friendRequests}</div>
          <div className="stat-label">Friend requests</div>
        </div>
        <div className="card">
          <div className="stat-value stat-timer">{data.counts.staleSessions}</div>
          <div className="stat-label">48h stale sessions</div>
        </div>
      </div>

      <div className="card">
        <div className="section-heading">
          <div>
            <h3>Auto Badge-Out</h3>
            <p>
              Guests still marked inside after 48 hours are completed when this desk
              loads or you click Run check (and when that guest opens the app).
            </p>
          </div>
          <button className="btn btn-sm" type="button" onClick={runAutoBadgeOut} disabled={busy}>
            {busy ? 'Checking…' : 'Run check'}
          </button>
        </div>
        <table>
          <thead>
            <tr>
              <th>Guest</th>
              <th>Branch</th>
              <th>Phase</th>
              <th>Entered</th>
            </tr>
          </thead>
          <tbody>
            {data.staleSessions.length === 0 ? (
              <EmptyRow colSpan={4}>No overdue sessions.</EmptyRow>
            ) : (
              data.staleSessions.map((s) => (
                <tr key={s.id}>
                  <td>{s.member_name}</td>
                  <td>{s.branch}</td>
                  <td><StatusBadge value={s.phase} /></td>
                  <td>{formatDate(s.entered_at)}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Safety Reports</h3>
        <table>
          <thead>
            <tr>
              <th>Category</th>
              <th>Branch</th>
              <th>Status</th>
              <th>Details</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {data.safetyReports.length === 0 ? (
              <EmptyRow colSpan={5} />
            ) : (
              data.safetyReports.map((r) => (
                <tr key={r.id}>
                  <td>{r.category}</td>
                  <td>{r.branch || '—'}</td>
                  <td><StatusBadge value={r.status} /></td>
                  <td>{r.description || '—'}</td>
                  <td>{formatDate(r.created_at)}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="grid grid-2">
        <div className="card">
          <h3 style={{ marginTop: 0 }}>Ride Assist</h3>
          <table>
            <thead>
              <tr>
                <th>Pickup</th>
                <th>Destination</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {data.rideRequests.length === 0 ? (
                <EmptyRow colSpan={3} />
              ) : (
                data.rideRequests.map((r) => (
                  <tr key={r.id}>
                    <td>{r.pickup_branch || '—'}</td>
                    <td>{r.destination || '—'}</td>
                    <td><StatusBadge value={r.status} /></td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <div className="card">
          <h3 style={{ marginTop: 0 }}>Insurance Incidents</h3>
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th>Consent</th>
                <th>Status</th>
                <th>Reference</th>
              </tr>
            </thead>
            <tbody>
              {data.insuranceIncidents.length === 0 ? (
                <EmptyRow colSpan={4} />
              ) : (
                data.insuranceIncidents.map((i) => (
                  <tr key={i.id}>
                    <td>{i.incident_type}</td>
                    <td>{i.consent_to_share ? 'Yes' : 'No'}</td>
                    <td><StatusBadge value={i.status} /></td>
                    <td>{i.partner_reference || '—'}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="grid grid-2">
        <div className="card">
          <h3 style={{ marginTop: 0 }}>Friend Requests</h3>
          <table>
            <thead>
              <tr>
                <th>Status</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {data.friendRequests.length === 0 ? (
                <EmptyRow colSpan={2} />
              ) : (
                data.friendRequests.map((r) => (
                  <tr key={r.id}>
                    <td><StatusBadge value={r.status} /></td>
                    <td>{formatDate(r.created_at)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <div className="card">
          <h3 style={{ marginTop: 0 }}>Blocks & Pings</h3>
          <div className="mini-metric-row">
            <span>Friendships</span>
            <strong>{data.counts.friendships}</strong>
          </div>
          <div className="mini-metric-row">
            <span>Blocks</span>
            <strong>{data.counts.memberBlocks}</strong>
          </div>
          <div className="mini-metric-row">
            <span>Notifications</span>
            <strong>{data.counts.notifications}</strong>
          </div>
        </div>
      </div>
    </>
  );
}
