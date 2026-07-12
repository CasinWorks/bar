import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatDuration, formatTimeLoad } from '../lib/api';

export default function UsersPage() {
  const { token, profile } = useAuth();
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all');
  const [err, setErr] = useState('');

  async function load() {
    const params = new URLSearchParams();
    if (search) params.set('search', search);
    if (filter === 'banned') params.set('banned', 'true');
    if (filter === 'whitelist') params.set('whitelisted', 'true');
    const data = await api(`/api/users?${params}`, { token });
    setUsers(data.users);
  }

  useEffect(() => {
    load().catch((e) => setErr(e.message));
  }, [token, filter]);

  async function patchUser(id, patch) {
    try {
      await api(`/api/users/${id}`, { method: 'PATCH', token, body: patch });
      await load();
    } catch (e) {
      setErr(e.message);
    }
  }

  return (
    <>
      <h2 className="page-title">Members & Access</h2>
      <p className="page-sub">Ban, whitelist, and manage member accounts</p>
      {err && <p className="error">{err}</p>}

      <div className="toolbar">
        <input placeholder="Search name or email…" value={search} onChange={(e) => setSearch(e.target.value)} />
        <select value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="all">All members</option>
          <option value="banned">Banned</option>
          <option value="whitelist">Whitelisted</option>
        </select>
        <button className="btn btn-secondary btn-sm" onClick={() => load()}>Search</button>
      </div>

      <div className="card" style={{ overflowX: 'auto' }}>
        <table>
          <thead>
            <tr>
              <th>Name</th><th>Email</th><th>Wallet</th><th>Status</th><th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
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
                    </>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
