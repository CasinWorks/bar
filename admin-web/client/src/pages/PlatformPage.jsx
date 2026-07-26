import { Link } from 'react-router-dom';

const MODULES = [
  {
    name: 'Customer Registration',
    purpose: 'Creates guest account',
    status: 'live',
    href: '/app/users',
    action: 'Members',
  },
  {
    name: 'QR Code Generator',
    purpose: 'Digital entry pass (guest app + door scanner)',
    status: 'live',
    href: '/app/branches',
    action: 'Live floor',
  },
  {
    name: 'Time Management Engine',
    purpose: 'Starts, pauses, and deducts time',
    status: 'live',
    href: '/app',
    action: 'Dashboard',
  },
  {
    name: 'POS Integration',
    purpose: 'Processes package purchases and extensions',
    status: 'live',
    href: '/app/time-load',
    action: 'Load package',
  },
  {
    name: 'Drink Tracking',
    purpose: 'Monitors included drink allowance',
    status: 'live',
    href: '/app/time-load',
    action: 'Packages',
  },
  {
    name: 'Experience Access',
    purpose: 'Controls entry to premium areas',
    status: 'live',
    href: '/app/branches',
    action: 'Floor',
  },
  {
    name: 'Time Transfer',
    purpose: 'Enables guest-to-guest transfers (Pass the Glass)',
    status: 'live',
    href: '/app/safety-social',
    action: 'Social',
  },
  {
    name: 'Loyalty System',
    purpose: 'Awards bonus time',
    status: 'live',
    href: '/app/time-load',
    action: 'Bonus time',
  },
  {
    name: 'Analytics Dashboard',
    purpose: 'Occupancy, stay, revenue, and behavior',
    status: 'live',
    href: '/app',
    action: 'Ops pulse',
  },
  {
    name: 'Mobile App',
    purpose: 'Remaining time, rewards, and account',
    status: 'live',
    href: '/app/users',
    action: 'Members',
  },
];

const REVENUE = [
  {
    name: 'Time Packages',
    description: 'Primary revenue stream',
    status: 'live',
    href: '/app/time-load',
  },
  {
    name: 'Time Extensions',
    description: 'Guests purchase additional minutes',
    status: 'live',
    href: '/app/time-load',
  },
  {
    name: 'Premium Cocktails',
    description: 'Optional upgrades (minutes or pay at bar)',
    status: 'live',
    href: '/app/branches',
  },
  {
    name: 'VIP Access',
    description: 'Time-gated premium spaces',
    status: 'live',
    href: '/app/branches',
  },
  {
    name: 'Hidden Experiences',
    description: 'Exclusive paid / time-based experiences',
    status: 'live',
    href: '/app/branches',
  },
  {
    name: 'Membership Program',
    description: 'Monthly recurring subscriptions',
    status: 'pilot',
    href: '/app/users',
  },
  {
    name: 'Merchandise',
    description: 'Apparel, collectibles, accessories',
    status: 'soon',
    href: '/app/events',
  },
  {
    name: 'Events',
    description: 'Special themed nights and collaborations',
    status: 'live',
    href: '/app/events',
  },
  {
    name: 'Software Licensing',
    description: 'Future — license Time Currency to other venues',
    status: 'future',
    href: '/app',
  },
];

function StatusBadge({ status }) {
  const label =
    status === 'live'
      ? 'LIVE'
      : status === 'pilot'
        ? 'PILOT'
        : status === 'soon'
          ? 'SOON'
          : 'FUTURE';
  const cls =
    status === 'live'
      ? 'badge badge-green'
      : status === 'pilot'
        ? 'badge badge-gold'
        : 'badge';
  return <span className={cls}>{label}</span>;
}

export default function PlatformPage() {
  return (
    <>
      <h2 className="page-title">Platform & Revenue</h2>
      <p className="page-sub">
        Time Currency operating system — software modules and how the house earns.
      </p>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Software modules</h3>
        <table>
          <thead>
            <tr>
              <th>Module</th>
              <th>Purpose</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {MODULES.map((m) => (
              <tr key={m.name}>
                <td>
                  <strong>{m.name}</strong>
                </td>
                <td style={{ color: 'var(--muted)' }}>{m.purpose}</td>
                <td>
                  <StatusBadge status={m.status} />
                </td>
                <td>
                  <Link className="btn btn-sm btn-secondary" to={m.href}>
                    {m.action}
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Business revenue streams</h3>
        <table>
          <thead>
            <tr>
              <th>Revenue source</th>
              <th>Description</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {REVENUE.map((r) => (
              <tr key={r.name}>
                <td>
                  <strong>{r.name}</strong>
                </td>
                <td style={{ color: 'var(--muted)' }}>{r.description}</td>
                <td>
                  <StatusBadge status={r.status} />
                </td>
                <td>
                  <Link className="btn btn-sm btn-secondary" to={r.href}>
                    Open
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
