import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatDate } from '../lib/api';
import EventDateTimePicker from '../components/EventDateTimePicker';

export default function EventsPage() {
  const { token } = useAuth();
  const [events, setEvents] = useState([]);
  const [title, setTitle] = useState('');
  const [startsAt, setStartsAt] = useState('');
  const [branch, setBranch] = useState('The Blind Tiger — BGC');
  const [vipOnly, setVipOnly] = useState(false);
  const [err, setErr] = useState('');

  async function load() {
    const data = await api('/api/events', { token });
    setEvents(data.events);
  }

  useEffect(() => {
    load().catch((e) => setErr(e.message));
  }, [token]);

  async function createEvent(e) {
    e.preventDefault();
    try {
      await api('/api/events', {
        method: 'POST',
        token,
        body: { title, startsAt: new Date(startsAt).toISOString(), branch, vipOnly },
      });
      setTitle('');
      setStartsAt('');
      await load();
    } catch (e) {
      setErr(e.message);
    }
  }

  return (
    <>
      <h2 className="page-title">Calendar & Events</h2>
      <p className="page-sub">Schedule nights, VIP pours, and guest-list events</p>
      {err && <p className="error">{err}</p>}

      <div className="card">
        <h3 style={{ marginTop: 0 }}>New event</h3>
        <form onSubmit={createEvent}>
          <label>Title</label>
          <input value={title} onChange={(e) => setTitle(e.target.value)} required />
          <label>Starts at</label>
          <EventDateTimePicker value={startsAt} onChange={setStartsAt} required />
          <label>Branch</label>
          <input value={branch} onChange={(e) => setBranch(e.target.value)} />
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, textTransform: 'none' }}>
            <input type="checkbox" checked={vipOnly} onChange={(e) => setVipOnly(e.target.checked)} style={{ width: 'auto' }} />
            VIP / VVIP room event only
          </label>
          <button className="btn" type="submit" disabled={!startsAt}>Create event</button>
        </form>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>All events</h3>
        <table>
          <thead><tr><th>Title</th><th>When</th><th>Branch</th><th>Status</th><th>VIP</th></tr></thead>
          <tbody>
            {events.map((ev) => (
              <tr key={ev.id}>
                <td>{ev.title}</td>
                <td>{formatDate(ev.starts_at)}</td>
                <td>{ev.branch}</td>
                <td><span className="badge badge-gold">{ev.status}</span></td>
                <td>{ev.vip_only ? 'Yes' : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
