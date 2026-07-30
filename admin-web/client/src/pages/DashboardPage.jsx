import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { api, formatDate, formatPeso } from '../lib/api';

function StatCard({ value, label, detail, tone = '' }) {
  return (
    <div className={`card dashboard-stat ${tone}`}>
      <div className="stat-value">{value}</div>
      <div className="stat-label">{label}</div>
      {detail ? <div className="stat-detail">{detail}</div> : null}
    </div>
  );
}

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

  const loadsToday = stats.loadsTodayCount ?? 0;
  const averageLoad = loadsToday ? stats.cashToday / loadsToday : 0;
  const averageMinutes = loadsToday
    ? Math.round(stats.minutesLoadedToday / loadsToday)
    : 0;
  const attentionCount =
    stats.safetyReports + stats.rideRequests + stats.staleSessions;
  const operationsStatus = attentionCount === 0 ? 'All clear' : 'Needs attention';

  return (
    <div className="dashboard-page">
      <section className="dashboard-hero">
        <img
          className="dashboard-hero-image"
          src="/gallery/aleksandr-popov-fa5QQ63u5W4-unsplash.jpg"
          alt="Blind Tiger nightlife floor"
        />
        <div className="dashboard-hero-shade" />
        <div className="dashboard-hero-copy">
          <span className="dashboard-eyebrow">Live operations</span>
          <h2 className="page-title">Operations Dashboard</h2>
          <p>
            Your night at a glance — occupancy, revenue, time loaded, and guest
            care.
          </p>
          <div className="dashboard-live-status">
            <span className="dashboard-live-dot" aria-hidden="true" />
            {stats.activeSessions} active {stats.activeSessions === 1 ? 'visit' : 'visits'}
          </div>
        </div>
        <div className={`dashboard-health ${attentionCount ? 'has-alerts' : ''}`}>
          <span>House status</span>
          <strong>{operationsStatus}</strong>
          <small>
            {attentionCount
              ? `${attentionCount} item${attentionCount === 1 ? '' : 's'} to review`
              : 'No open guest-care alerts'}
          </small>
        </div>
      </section>

      <div className="dashboard-section-heading">
        <div>
          <span className="dashboard-eyebrow">Tonight's pulse</span>
          <h3>Key performance</h3>
        </div>
        <span className="dashboard-as-of">Live data</span>
      </div>

      <div className="grid grid-4 dashboard-primary-stats">
        <StatCard
          value={formatPeso(stats.cashToday)}
          label="Revenue today"
          detail={`${loadsToday} posted ${loadsToday === 1 ? 'load' : 'loads'}`}
        />
        <StatCard
          value={stats.activeSessions}
          label="Active visits"
          detail="Guests in the time engine"
          tone="timer"
        />
        <StatCard
          value={`${stats.minutesLoadedToday}m`}
          label="Minutes loaded"
          detail={averageMinutes ? `${averageMinutes}m average per load` : 'No loads yet'}
          tone="timer"
        />
        <StatCard
          value={stats.memberCount}
          label="Registered members"
          detail={`${stats.staffCount} staff accounts`}
        />
      </div>

      <div className="dashboard-insight-grid">
        <section className="card dashboard-insights">
          <div className="dashboard-card-heading">
            <div>
              <span className="dashboard-eyebrow">Revenue intelligence</span>
              <h3>Today at the desk</h3>
            </div>
            <strong>{formatPeso(averageLoad)}</strong>
          </div>
          <p className="dashboard-card-note">Average revenue per posted load</p>
          <div className="dashboard-mini-stats">
            <div>
              <strong>{loadsToday}</strong>
              <span>Transactions</span>
            </div>
            <div>
              <strong>{averageMinutes}m</strong>
              <span>Avg. time load</span>
            </div>
            <div>
              <strong>{stats.upcomingEvents?.length ?? 0}</strong>
              <span>Upcoming events</span>
            </div>
          </div>
        </section>

        <section className="card dashboard-attention">
          <span className="dashboard-eyebrow">Guest care</span>
          <h3>Items requiring attention</h3>
          <div className="dashboard-attention-list">
            <div><span>Open safety reports</span><strong>{stats.safetyReports}</strong></div>
            <div><span>Ride assists pending</span><strong>{stats.rideRequests}</strong></div>
            <div><span>48h auto badge-out</span><strong>{stats.staleSessions}</strong></div>
          </div>
        </section>
      </div>

      <section className="card dashboard-shortcuts">
        <div className="dashboard-card-heading">
          <div>
            <span className="dashboard-eyebrow">Revenue desk</span>
            <h3>Quick actions</h3>
          </div>
          <p>Time packages · extensions · events · VIP floor</p>
        </div>
        <div className="dashboard-shortcut-grid">
          <Link className="dashboard-shortcut primary" to="/app/time-load">
            <span>Load package</span>
            <small>Add time or extend a guest</small>
            <b aria-hidden="true">→</b>
          </Link>
          <Link className="dashboard-shortcut" to="/app/platform">
            <span>Platform & revenue</span>
            <small>Review revenue streams</small>
            <b aria-hidden="true">→</b>
          </Link>
          <Link className="dashboard-shortcut" to="/app/events">
            <span>Events</span>
            <small>Manage the event calendar</small>
            <b aria-hidden="true">→</b>
          </Link>
          <Link className="dashboard-shortcut" to="/app/branches">
            <span>Live floor</span>
            <small>See branches and floor access</small>
            <b aria-hidden="true">→</b>
          </Link>
        </div>
      </section>

      <section className="card dashboard-events">
        <div className="dashboard-card-heading">
          <div>
            <span className="dashboard-eyebrow">Calendar</span>
            <h3>Upcoming events</h3>
          </div>
          <Link to="/app/events">View all →</Link>
        </div>
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
      </section>
    </div>
  );
}
