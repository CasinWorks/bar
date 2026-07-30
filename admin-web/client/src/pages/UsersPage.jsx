import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatTimeLoad } from '../lib/api';

export default function UsersPage() {
  const { token, profile } = useAuth();
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all');
  const [err, setErr] = useState('');
  const [msg, setMsg] = useState('');
  const [busyId, setBusyId] = useState(null);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  const [resetResult, setResetResult] = useState(null);

  async function load() {
    const params = new URLSearchParams();
    if (search) params.set('search', search);
    if (filter === 'banned') params.set('banned', 'true');
    if (filter === 'whitelist') params.set('whitelisted', 'true');
    const data = await api(`/api/users?${params}`, { token });
    setUsers(data.users);
    setPage(1);
  }

  useEffect(() => {
    load().catch((e) => setErr(e.message));
  }, [token, filter]);

  const totalPages = Math.max(1, Math.ceil(users.length / pageSize));
  const pageSafe = Math.min(page, totalPages);
  const pagedUsers = useMemo(() => {
    const start = (pageSafe - 1) * pageSize;
    return users.slice(start, start + pageSize);
  }, [users, pageSafe, pageSize]);

  useEffect(() => {
    if (page !== pageSafe) setPage(pageSafe);
  }, [page, pageSafe]);

  async function patchUser(id, patch) {
    try {
      setErr('');
      setMsg('');
      await api(`/api/users/${id}`, { method: 'PATCH', token, body: patch });
      await load();
    } catch (e) {
      setErr(e.message);
    }
  }

  async function resetPassword(user) {
    const confirmed = window.confirm(
      `Reset password for ${user.name} (${user.email})?\n\nA temporary password will be generated for them to sign in.`,
    );
    if (!confirmed) return;

    try {
      setBusyId(user.id);
      setErr('');
      setMsg('');
      const result = await api(`/api/users/${user.id}/reset-password`, {
        method: 'POST',
        token,
        body: {},
      });
      setResetResult(result);
      setMsg(`Password reset for ${result.email}. Share the temporary password privately.`);
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusyId(null);
    }
  }

  async function copyTempPassword() {
    if (!resetResult?.tempPassword) return;
    try {
      await navigator.clipboard.writeText(resetResult.tempPassword);
      setMsg('Temporary password copied.');
    } catch {
      setMsg('Could not copy — select and copy the password manually.');
    }
  }

  return (
    <>
      <h2 className="page-title">Members & Access</h2>
      <p className="page-sub">Ban, whitelist, reset passwords, and manage member accounts</p>
      {err && <p className="error">{err}</p>}
      {msg && <p className="success">{msg}</p>}

      <div className="toolbar">
        <input placeholder="Search name or email…" value={search} onChange={(e) => setSearch(e.target.value)} />
        <select value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="all">All members</option>
          <option value="banned">Banned</option>
          <option value="whitelist">Whitelisted</option>
        </select>
        <button className="btn btn-secondary btn-sm" onClick={() => load().catch((e) => setErr(e.message))}>Search</button>
      </div>

      {resetResult && (
        <div className="card reset-password-card">
          <div className="dashboard-card-heading">
            <div>
              <span className="dashboard-eyebrow">Password reset</span>
              <h3 style={{ margin: '4px 0 0' }}>
                Temporary password for {resetResult.name || resetResult.email}
              </h3>
            </div>
            <button type="button" className="btn btn-sm btn-secondary" onClick={() => setResetResult(null)}>
              Dismiss
            </button>
          </div>
          <p className="page-sub" style={{ marginBottom: 10 }}>
            Share this once with the member. They can change it in the app under Profile.
          </p>
          <code className="temp-password">{resetResult.tempPassword}</code>
          <div style={{ marginTop: 12, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button type="button" className="btn btn-sm" onClick={copyTempPassword}>
              Copy password
            </button>
            <span style={{ color: 'var(--muted)', fontSize: 12, alignSelf: 'center' }}>
              {resetResult.email}
            </span>
          </div>
        </div>
      )}

      <div className="card" style={{ overflowX: 'auto' }}>
        <div className="table-toolbar">
          <h3 style={{ margin: 0 }}>Members</h3>
          <label className="page-size-control">
            Rows per page
            <select
              value={pageSize}
              onChange={(e) => {
                setPageSize(Number(e.target.value));
                setPage(1);
              }}
            >
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
            </select>
          </label>
        </div>
        <table>
          <thead>
            <tr>
              <th>Name</th><th>Email</th><th>Wallet</th><th>Status</th><th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {pagedUsers.length === 0 ? (
              <tr>
                <td colSpan={5} style={{ color: 'var(--muted)' }}>No members found.</td>
              </tr>
            ) : (
              pagedUsers.map((u) => (
                <tr key={u.id}>
                  <td>{u.name}</td>
                  <td>{u.email}</td>
                  <td>{formatTimeLoad(u)}</td>
                  <td>
                    {u.is_banned && <span className="badge badge-red">BANNED</span>}
                    {u.is_whitelisted && <span className="badge badge-green">VIP LIST</span>}
                    {!u.is_banned && !u.is_whitelisted && <span className="badge badge-gold">{u.role}</span>}
                  </td>
                  <td style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    {profile?.role === 'admin' && (
                      <>
                        <button
                          className="btn btn-sm btn-secondary"
                          onClick={() => patchUser(u.id, { is_whitelisted: !u.is_whitelisted })}
                        >
                          {u.is_whitelisted ? 'Remove WL' : 'Whitelist'}
                        </button>
                        <button
                          className="btn btn-sm btn-danger"
                          onClick={() => patchUser(u.id, {
                            is_banned: !u.is_banned,
                            ban_reason: u.is_banned ? null : 'Suspended by admin',
                          })}
                        >
                          {u.is_banned ? 'Unban' : 'Ban'}
                        </button>
                        <button
                          className="btn btn-sm"
                          disabled={busyId === u.id}
                          onClick={() => resetPassword(u)}
                        >
                          {busyId === u.id ? 'Resetting…' : 'Reset password'}
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
        <div className="table-pagination">
          <span>
            {users.length === 0
              ? '0 members'
              : `Showing ${(pageSafe - 1) * pageSize + 1}–${Math.min(
                  pageSafe * pageSize,
                  users.length,
                )} of ${users.length}`}
          </span>
          <div className="table-pagination-actions">
            <button
              type="button"
              className="btn btn-sm btn-secondary"
              disabled={pageSafe <= 1}
              onClick={() => setPage((p) => Math.max(1, p - 1))}
            >
              Previous
            </button>
            <span>
              Page {pageSafe} of {totalPages}
            </span>
            <button
              type="button"
              className="btn btn-sm btn-secondary"
              disabled={pageSafe >= totalPages}
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            >
              Next
            </button>
          </div>
        </div>
      </div>
    </>
  );
}
