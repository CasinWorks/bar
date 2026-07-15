import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatDate, formatPeso } from '../lib/api';

export default function DashboardPage() {
  const { token } = useAuth();
  const [stats, setStats] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    api('/api/dashboard/stats', { token })
      .then(setStats)
      .catch((e) => setError(e.message));
  }, [token]);

  if (error) return <p className="error">{error}</p>;
  if (!stats) return <p>Loading dashboard…</p>;

  return (
    <>
      <h2 className="page-title">Operations Dashboard</h2>
      <p className="page-sub">Live pulse for investor demo & bar pilot — cash-first time economy</p>

      <div className="grid grid-4">
        <div className="card"><div className="stat-value">{stats.memberCount}</div><div className="stat-label">Members</div></div>
        <div className="card"><div className="stat-value">{stats.activeSessions}</div><div className="stat-label">Active visits</div></div>
        <div className="card"><div className="stat-value">{formatPeso(stats.cashToday)}</div><div className="stat-label">Cash today</div></div>
        <div className="card"><div className="stat-value stat-timer">{stats.minutesLoadedToday}m</div><div className="stat-label">Time loaded today</div></div>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Upcoming events</h3>
        {stats.upcomingEvents?.length ? (
          <table>
            <thead><tr><th>Event</th><th>Starts</th></tr></thead>
            <tbody>
              {stats.upcomingEvents.map((e) => (
                <tr key={e.id}><td>{e.title}</td><td>{formatDate(e.starts_at)}</td></tr>
              ))}
            </tbody>
          </table>
        ) : (
          <p style={{ color: 'var(--muted)' }}>No upcoming events — add one in Calendar & Events.</p>
        )}
      </div>
    </>
  );
}
