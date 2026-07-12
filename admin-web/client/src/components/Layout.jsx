import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const links = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/time-load', label: 'Load Time (Cash)' },
  { to: '/users', label: 'Members & Access' },
  { to: '/events', label: 'Calendar & Events' },
  { to: '/guests', label: 'Guest List' },
  { to: '/hr', label: 'HR & Employment' },
];

export default function Layout() {
  const { profile, signOut } = useAuth();
  const navigate = useNavigate();

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <h1>BLIND TIGER<br />ADMIN</h1>
        {links.map((l) => (
          <NavLink key={l.to} to={l.to} end={l.end} className={({ isActive }) => `nav-link${isActive ? ' active' : ''}`}>
            {l.label}
          </NavLink>
        ))}
        <div style={{ flex: 1 }} />
        <div style={{ fontSize: 11, color: 'var(--muted)', marginBottom: 8 }}>
          {profile?.name}<br />
          <span className="badge badge-gold">{profile?.role}</span>
        </div>
        <button
          className="btn btn-secondary btn-sm"
          onClick={async () => {
            await signOut();
            navigate('/login');
          }}
        >
          Sign out
        </button>
      </aside>
      <main className="main">
        <Outlet />
      </main>
    </div>
  );
}
