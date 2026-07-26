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
      <p className="page-sub">
        Analytics pulse — occupancy, revenue, and the Time Currency night.
      </p>

      <div className="grid grid-4">
        <div className="card"><div className="stat-value">{stats.memberCount}</div><div className="stat-label">Members (registration)</div></div>
        <div className="card"><div className="stat-value">{stats.activeSessions}</div><div className="stat-label">Active visits (time engine)</div></div>
        <div className="card"><div className="stat-value">{formatPeso(stats.cashToday)}</div><div className="stat-label">Package / POS cash today</div></div>
        <div className="card"><div className="stat-value stat-timer">{stats.minutesLoadedToday}m</div><div className="stat-label">Minutes loaded (extensions)</div></div>
      </div>

      <div className="grid grid-4">
        <div className="card"><div className="stat-value">{stats.safetyReports}</div><div className="stat-label">Open safety reports</div></div>
        <div className="card"><div className="stat-value">{stats.rideRequests}</div><div className="stat-label">Ride assists pending</div></div>
        <div className="card"><div className="stat-value stat-timer">{stats.staleSessions}</div><div className="stat-label">48h auto badge-out</div></div>
        <div className="card"><div className="stat-value">{stats.staffCount}</div><div className="stat-label">Staff accounts</div></div>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Revenue desk shortcuts</h3>
        <p className="page-sub" style={{ marginBottom: 12 }}>
          Time packages · extensions · events · VIP floor
        </p>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          <a className="btn btn-sm" href="/app/time-load">Load package</a>
          <a className="btn btn-sm btn-secondary" href="/app/platform">Platform & revenue</a>
          <a className="btn btn-sm btn-secondary" href="/app/events">Events</a>
          <a className="btn btn-sm btn-secondary" href="/app/branches">Live floor</a>
        </div>
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
