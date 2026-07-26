import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatDate, formatDuration } from '../lib/api';

function phaseLabel(phase) {
  if (phase === 'inside_club') return 'Inside';
  if (phase === 'awaiting_exit_scan') return 'Exiting';
  return phase || '—';
}

export default function BranchesPage() {
  const { token } = useAuth();
  const [data, setData] = useState(null);
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const [openBranch, setOpenBranch] = useState(null);

  async function refresh() {
    setBusy(true);
    setErr('');
    try {
      const next = await api('/api/branches/live', { token });
      setData(next);
      setOpenBranch((prev) => {
        if (prev) return prev;
        const firstWithGuests = next.branches?.find((b) => b.count > 0);
        return firstWithGuests?.name ?? next.branches?.[0]?.name ?? null;
      });
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    let cancelled = false;
    setErr('');
    api('/api/branches/live', { token })
      .then((next) => {
        if (cancelled) return;
        setData(next);
        const firstWithGuests = next.branches?.find((b) => b.count > 0);
        setOpenBranch(firstWithGuests?.name ?? next.branches?.[0]?.name ?? null);
      })
      .catch((e) => {
        if (!cancelled) setErr(e.message);
      });

    const timer = setInterval(() => {
      api('/api/branches/live', { token })
        .then((next) => {
          if (!cancelled) setData(next);
        })
        .catch(() => {});
    }, 15000);

    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [token]);

  if (err) return <p className="error">{err}</p>;
  if (!data) return <p>Loading live floor…</p>;

  return (
    <>
      <div className="section-heading">
        <div>
          <h2 className="page-title">Branches · Live Floor</h2>
          <p className="page-sub">
            Guests currently inside each branch (and those waiting on exit scan). Updates every
            15 seconds.
          </p>
        </div>
        <button className="btn btn-sm" type="button" onClick={refresh} disabled={busy}>
          {busy ? 'Refreshing…' : 'Refresh'}
        </button>
      </div>

      <div className="grid grid-4" style={{ marginBottom: 16 }}>
        <div className="card">
          <div className="stat-value stat-timer">{data.totalInside}</div>
          <div className="stat-label">Guests inside now</div>
        </div>
        <div className="card">
          <div className="stat-value">{data.awaitingEntry}</div>
          <div className="stat-label">At door (awaiting entry)</div>
        </div>
        <div className="card">
          <div className="stat-value">
            {data.branches.filter((b) => b.count > 0).length}
          </div>
          <div className="stat-label">Branches with guests</div>
        </div>
        <div className="card">
          <div className="stat-value" style={{ fontSize: 14 }}>
            {data.refreshedAt ? formatDate(data.refreshedAt) : '—'}
          </div>
          <div className="stat-label">Last refresh</div>
        </div>
      </div>

      <div className="grid grid-2">
        {data.branches.map((branch) => {
          const open = openBranch === branch.name;
          return (
            <div className="card" key={branch.id || branch.name}>
              <button
                type="button"
                className="section-heading"
                style={{
                  width: '100%',
                  background: 'transparent',
                  border: 0,
                  padding: 0,
                  cursor: 'pointer',
                  textAlign: 'left',
                  color: 'inherit',
                }}
                onClick={() =>
                  setOpenBranch((prev) => (prev === branch.name ? null : branch.name))
                }
              >
                <div>
                  <h3 style={{ margin: 0 }}>{branch.name}</h3>
                  <p style={{ margin: '4px 0 0' }}>
                    {branch.city ? `${branch.city} · ` : ''}
                    {branch.count} guest{branch.count === 1 ? '' : 's'}
                  </p>
                </div>
                <span className={`badge ${branch.count > 0 ? 'badge-green' : 'badge-gold'}`}>
                  {branch.count > 0 ? 'LIVE' : 'EMPTY'}
                </span>
              </button>

              {open && (
                <div style={{ marginTop: 14 }}>
                  <table>
                    <thead>
                      <tr>
                        <th>Guest</th>
                        <th>Status</th>
                        <th>Entered</th>
                        <th>Time left</th>
                      </tr>
                    </thead>
                    <tbody>
                      {branch.guests.length === 0 ? (
                        <tr>
                          <td colSpan={4} style={{ color: 'var(--muted)' }}>
                            No one inside this branch right now.
                          </td>
                        </tr>
                      ) : (
                        branch.guests.map((guest) => (
                          <tr key={guest.id}>
                            <td>
                              <strong>{guest.memberName}</strong>
                              {guest.email ? (
                                <div style={{ color: 'var(--muted)', fontSize: 12 }}>
                                  {guest.email}
                                </div>
                              ) : null}
                            </td>
                            <td>
                              <span
                                className={`badge ${
                                  guest.phase === 'awaiting_exit_scan'
                                    ? 'badge-gold'
                                    : 'badge-green'
                                }`}
                              >
                                {phaseLabel(guest.phase)}
                              </span>
                            </td>
                            <td>{formatDate(guest.enteredAt)}</td>
                            <td>{formatDuration(guest.walletSeconds)}</td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </>
  );
}
