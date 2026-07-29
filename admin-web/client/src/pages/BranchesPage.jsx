import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { api, formatDate, formatDuration } from '../lib/api';

function phaseLabel(phase) {
  if (phase === 'inside_club') return 'Inside';
  if (phase === 'awaiting_exit_scan') return 'Exiting';
  return phase || '—';
}

function SetupSequence({ branchCount }) {
  return (
    <div className="setup-sequence card">
      <h3 style={{ marginTop: 0 }}>Event setup sequence</h3>
      <ol className="setup-steps">
        <li className={branchCount > 0 ? 'done' : 'current'}>
          <strong>Create branch</strong>
          <span>Add each venue location before scheduling nights.</span>
        </li>
        <li className={branchCount > 0 ? 'current' : ''}>
          <strong>Schedule event</strong>
          <span>Pick a branch and time window — conflicts are checked per branch.</span>
        </li>
        <li>
          <strong>Add / link guests</strong>
          <span>Guest list and check-in attach to the scheduled event.</span>
        </li>
      </ol>
      {branchCount > 0 ? (
        <Link className="btn btn-sm" to="/app/events">
          Continue to Calendar & Events →
        </Link>
      ) : (
        <p className="page-sub" style={{ margin: '12px 0 0' }}>
          Start by creating your first branch below.
        </p>
      )}
    </div>
  );
}

export default function BranchesPage() {
  const { token, profile } = useAuth();
  const isAdmin = profile?.role === 'admin';

  const [catalog, setCatalog] = useState([]);
  const [live, setLive] = useState(null);
  const [err, setErr] = useState('');
  const [okMsg, setOkMsg] = useState('');
  const [busy, setBusy] = useState(false);
  const [openBranch, setOpenBranch] = useState(null);

  const [createForm, setCreateForm] = useState({ name: '', slug: '' });
  const [editingId, setEditingId] = useState(null);
  const [editForm, setEditForm] = useState({ name: '', slug: '', sortOrder: 0 });

  const activeCount = catalog.filter((b) => b.is_active).length;

  const refreshCatalog = useCallback(async () => {
    const data = await api('/api/branches', { token });
    setCatalog(data.branches || []);
    return data.branches || [];
  }, [token]);

  const refreshLive = useCallback(async () => {
    const next = await api('/api/branches/live', { token });
    setLive(next);
    setOpenBranch((prev) => {
      if (prev) return prev;
      const firstWithGuests = next.branches?.find((b) => b.count > 0);
      return firstWithGuests?.name ?? next.branches?.[0]?.name ?? null;
    });
    return next;
  }, [token]);

  async function refreshAll() {
    setBusy(true);
    setErr('');
    try {
      await Promise.all([refreshCatalog(), refreshLive()]);
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    let cancelled = false;
    setErr('');
    Promise.all([refreshCatalog(), refreshLive()]).catch((e) => {
      if (!cancelled) setErr(e.message);
    });
    const timer = setInterval(() => {
      refreshLive().catch(() => {});
    }, 15000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [refreshCatalog, refreshLive]);

  async function createBranch(e) {
    e.preventDefault();
    setErr('');
    setOkMsg('');
    const name = createForm.name.trim();
    if (!name) {
      setErr('Branch name is required.');
      return;
    }
    setBusy(true);
    try {
      const data = await api('/api/branches', {
        method: 'POST',
        token,
        body: {
          name,
          slug: createForm.slug.trim() || undefined,
        },
      });
      setCreateForm({ name: '', slug: '' });
      setOkMsg(`Created “${data.branch.name}”. You can now schedule events at this branch.`);
      await refreshAll();
    } catch (error) {
      setErr(error.message);
    } finally {
      setBusy(false);
    }
  }

  function startEdit(branch) {
    setEditingId(branch.id);
    setEditForm({
      name: branch.name,
      slug: branch.slug,
      sortOrder: branch.sort_order ?? 0,
    });
  }

  async function saveEdit(branch) {
    setErr('');
    setOkMsg('');
    setBusy(true);
    try {
      const data = await api(`/api/branches/${branch.id}`, {
        method: 'PATCH',
        token,
        body: {
          name: editForm.name.trim(),
          slug: editForm.slug.trim() || undefined,
          sortOrder: Number(editForm.sortOrder),
        },
      });
      setEditingId(null);
      const warn = data.warnings?.length ? ` ${data.warnings.join(' ')}` : '';
      setOkMsg(`Updated “${data.branch.name}”.${warn}`);
      await refreshAll();
    } catch (error) {
      setErr(error.message);
    } finally {
      setBusy(false);
    }
  }

  async function toggleActive(branch) {
    setErr('');
    setOkMsg('');
    setBusy(true);
    try {
      const data = await api(`/api/branches/${branch.id}`, {
        method: 'PATCH',
        token,
        body: { isActive: !branch.is_active },
      });
      const warn = data.warnings?.length ? ` ${data.warnings.join(' ')}` : '';
      setOkMsg(
        `${data.branch.is_active ? 'Activated' : 'Deactivated'} “${data.branch.name}”.${warn}`,
      );
      await refreshAll();
    } catch (error) {
      setErr(error.message);
    } finally {
      setBusy(false);
    }
  }

  async function setDefault(branch) {
    setErr('');
    setOkMsg('');
    setBusy(true);
    try {
      const data = await api(`/api/branches/${branch.id}`, {
        method: 'PATCH',
        token,
        body: { isDefault: true },
      });
      setOkMsg(`“${data.branch.name}” is now the default branch.`);
      await refreshAll();
    } catch (error) {
      setErr(error.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className="section-heading">
        <div>
          <h2 className="page-title">Branches</h2>
          <p className="page-sub">
            Step 1 of event setup — create and manage venue locations, then schedule events against
            them.
          </p>
        </div>
        <button className="btn btn-sm" type="button" onClick={refreshAll} disabled={busy}>
          {busy ? 'Refreshing…' : 'Refresh'}
        </button>
      </div>

      {err && <p className="error">{err}</p>}
      {okMsg && <p className="success">{okMsg}</p>}

      <SetupSequence branchCount={activeCount} />

      {isAdmin ? (
        <>
          <div className="card">
            <h3 style={{ marginTop: 0 }}>Create branch</h3>
            <p className="page-sub" style={{ marginTop: 0 }}>
              Each branch is a physical venue. Events, guest check-in, and live floor counts are
              scoped to the branch name.
            </p>
            <form onSubmit={createBranch}>
              <div className="form-row">
                <div>
                  <label>Branch name</label>
                  <input
                    value={createForm.name}
                    onChange={(e) => setCreateForm((f) => ({ ...f, name: e.target.value }))}
                    placeholder="e.g. Cubao Branch"
                    required
                  />
                </div>
                <div>
                  <label>Slug (optional)</label>
                  <input
                    value={createForm.slug}
                    onChange={(e) => setCreateForm((f) => ({ ...f, slug: e.target.value }))}
                    placeholder="Auto-generated from name"
                  />
                </div>
              </div>
              <button className="btn" type="submit" disabled={busy}>
                {busy ? 'Saving…' : 'Create branch'}
              </button>
            </form>
          </div>

          <div className="card">
            <h3 style={{ marginTop: 0 }}>Branch catalog</h3>
            {catalog.length === 0 ? (
              <p style={{ color: 'var(--muted)', marginBottom: 0 }}>
                No branches yet. Create your first branch above before scheduling events.
              </p>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Slug</th>
                    <th>Status</th>
                    <th>Usage</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {catalog.map((branch) => (
                    <tr key={branch.id}>
                      <td>
                        {editingId === branch.id ? (
                          <input
                            value={editForm.name}
                            onChange={(e) =>
                              setEditForm((f) => ({ ...f, name: e.target.value }))
                            }
                            style={{ marginBottom: 0 }}
                          />
                        ) : (
                          <>
                            <strong>{branch.name}</strong>
                            {branch.is_default ? (
                              <span className="badge badge-gold" style={{ marginLeft: 6 }}>
                                DEFAULT
                              </span>
                            ) : null}
                          </>
                        )}
                      </td>
                      <td>
                        {editingId === branch.id ? (
                          <input
                            value={editForm.slug}
                            onChange={(e) =>
                              setEditForm((f) => ({ ...f, slug: e.target.value }))
                            }
                            style={{ marginBottom: 0 }}
                          />
                        ) : (
                          <code>{branch.slug}</code>
                        )}
                      </td>
                      <td>
                        <span
                          className={`badge ${branch.is_active ? 'badge-green' : 'badge-amber'}`}
                        >
                          {branch.is_active ? 'ACTIVE' : 'INACTIVE'}
                        </span>
                      </td>
                      <td style={{ color: 'var(--muted)', fontSize: 12 }}>
                        {branch.eventCount ?? 0} event{(branch.eventCount ?? 0) === 1 ? '' : 's'}
                        {(branch.liveCount ?? 0) > 0
                          ? ` · ${branch.liveCount} live now`
                          : ''}
                      </td>
                      <td>
                        <div className="row-actions">
                          {editingId === branch.id ? (
                            <>
                              <button
                                type="button"
                                className="btn btn-sm"
                                disabled={busy}
                                onClick={() => saveEdit(branch)}
                              >
                                Save
                              </button>
                              <button
                                type="button"
                                className="btn btn-sm btn-secondary"
                                onClick={() => setEditingId(null)}
                              >
                                Cancel
                              </button>
                            </>
                          ) : (
                            <>
                              <button
                                type="button"
                                className="btn btn-sm btn-secondary"
                                onClick={() => startEdit(branch)}
                              >
                                Edit
                              </button>
                              <button
                                type="button"
                                className="btn btn-sm btn-secondary"
                                disabled={busy || branch.is_default}
                                onClick={() => setDefault(branch)}
                              >
                                Set default
                              </button>
                              <Link
                                className="btn btn-sm"
                                to={`/app/events?branch=${encodeURIComponent(branch.name)}`}
                              >
                                Schedule event
                              </Link>
                              <button
                                type="button"
                                className="btn btn-sm btn-ghost"
                                disabled={busy}
                                onClick={() => toggleActive(branch)}
                              >
                                {branch.is_active ? 'Deactivate' : 'Activate'}
                              </button>
                            </>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </>
      ) : (
        <div className="card warning-card">
          <p>
            Branch catalog editing requires <strong>admin</strong> access. You can still view the
            live floor below.
          </p>
        </div>
      )}

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Live floor</h3>
        <p className="page-sub" style={{ marginTop: 0 }}>
          Guests currently inside each branch (and those waiting on exit scan). Updates every 15
          seconds.
        </p>

        {!live ? (
          <p>Loading live floor…</p>
        ) : (
          <>
            <div className="grid grid-4" style={{ marginBottom: 16 }}>
              <div className="card">
                <div className="stat-value stat-timer">{live.totalInside}</div>
                <div className="stat-label">Guests inside now</div>
              </div>
              <div className="card">
                <div className="stat-value">{live.awaitingEntry}</div>
                <div className="stat-label">At door (awaiting entry)</div>
              </div>
              <div className="card">
                <div className="stat-value">
                  {live.branches.filter((b) => b.count > 0).length}
                </div>
                <div className="stat-label">Branches with guests</div>
              </div>
              <div className="card">
                <div className="stat-value" style={{ fontSize: 14 }}>
                  {live.refreshedAt ? formatDate(live.refreshedAt) : '—'}
                </div>
                <div className="stat-label">Last refresh</div>
              </div>
            </div>

            <div className="grid grid-2">
              {live.branches.map((branch) => {
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
                          {branch.count} guest{branch.count === 1 ? '' : 's'}
                          {!branch.configured ? ' · not in catalog' : ''}
                        </p>
                      </div>
                      <span
                        className={`badge ${branch.count > 0 ? 'badge-green' : 'badge-gold'}`}
                      >
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
        )}
      </div>
    </>
  );
}
