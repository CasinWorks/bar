import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const links = [
  { to: '/app', label: 'Dashboard', end: true },
  { to: '/app/platform', label: 'Platform & Revenue' },
  { to: '/app/time-load', label: 'Load Package' },
  { to: '/app/packages', label: 'Entry Packages' },
  { to: '/app/drinks', label: 'Drink Inventory' },
  { to: '/app/users', label: 'Members & Access' },
  { to: '/app/events', label: 'Calendar & Events' },
  { to: '/app/guests', label: 'Guest List' },
  { to: '/app/branches', label: 'Branches' },
  { to: '/app/download-invites', label: 'App Downloads' },
  { to: '/app/safety-social', label: 'Safety & Social' },
  { to: '/app/hr', label: 'HR & Employment' },
];

export default function Layout() {
  const { profile, signOut } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [navOpen, setNavOpen] = useState(false);

  useEffect(() => {
    const main = document.querySelector('.main');
    if (main) main.scrollTo({ top: 0, behavior: 'smooth' });
    setNavOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    document.body.classList.toggle('admin-nav-open', navOpen);
    const onKeyDown = (e) => {
      if (e.key === 'Escape') setNavOpen(false);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => {
      document.body.classList.remove('admin-nav-open');
      window.removeEventListener('keydown', onKeyDown);
    };
  }, [navOpen]);

  async function handleSignOut() {
    await signOut();
    navigate('/login');
  }

  return (
    <div className={`app-shell${navOpen ? ' nav-open' : ''}`}>
      <header className="mobile-admin-bar">
        <button
          type="button"
          className="mobile-menu-btn"
          aria-label={navOpen ? 'Close admin navigation' : 'Open admin navigation'}
          aria-expanded={navOpen}
          aria-controls="admin-sidebar"
          onClick={() => setNavOpen((open) => !open)}
        >
          <span />
          <span />
          <span />
        </button>
        <div>
          <strong>BLIND TIGER</strong>
          <small>ADMIN</small>
        </div>
        <span className="badge badge-gold">{profile?.role}</span>
      </header>

      <button
        type="button"
        className="sidebar-backdrop"
        aria-label="Close admin navigation"
        onClick={() => setNavOpen(false)}
      />

      <aside className="sidebar" id="admin-sidebar">
        <h1>
          BLIND TIGER
          <br />
          ADMIN
        </h1>
        {links.map((l) => (
          <NavLink
            key={l.to}
            to={l.to}
            end={l.end}
            className={({ isActive }) => `nav-link${isActive ? ' active' : ''}`}
            onClick={() => setNavOpen(false)}
          >
            {l.label}
          </NavLink>
        ))}
        <div style={{ flex: 1 }} />
        <div style={{ fontSize: 11, color: 'var(--muted)', marginBottom: 8 }}>
          {profile?.name}
          <br />
          <span className="badge badge-gold">{profile?.role}</span>
        </div>
        <button
          className="btn btn-secondary btn-sm"
          onClick={handleSignOut}
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
