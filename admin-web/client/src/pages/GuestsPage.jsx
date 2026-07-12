import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api } from '../lib/api';

export default function GuestsPage() {
  const { token } = useAuth();
  const [events, setEvents] = useState([]);
  const [eventId, setEventId] = useState('');
  const [guests, setGuests] = useState([]);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [plusOnes, setPlusOnes] = useState('0');
  const [err, setErr] = useState('');

  useEffect(() => {
    api('/api/events', { token }).then((d) => {
      setEvents(d.events);
      if (d.events[0]) setEventId(d.events[0].id);
    }).catch((e) => setErr(e.message));
  }, [token]);

  useEffect(() => {
    if (!eventId) return;
    api(`/api/guests/event/${eventId}`, { token })
      .then((d) => setGuests(d.guests))
      .catch((e) => setErr(e.message));
  }, [token, eventId]);

  async function addGuest(e) {
    e.preventDefault();
    try {
      await api('/api/guests', {
        method: 'POST',
        token,
        body: { eventId, name, email, phone, plusOnes: Number(plusOnes) },
      });
      setName('');
      setEmail('');
      setPhone('');
      const d = await api(`/api/guests/event/${eventId}`, { token });
      setGuests(d.guests);
    } catch (e) {
      setErr(e.message);
    }
  }

  async function setStatus(id, status) {
    await api(`/api/guests/${id}`, { method: 'PATCH', token, body: { status } });
    const d = await api(`/api/guests/event/${eventId}`, { token });
    setGuests(d.guests);
  }

  return (
    <>
      <h2 className="page-title">Guest List</h2>
      <p className="page-sub">Door whitelist per event — check-in from admin desk</p>
      {err && <p className="error">{err}</p>}

      <div className="toolbar">
        <label>Event</label>
        <select value={eventId} onChange={(e) => setEventId(e.target.value)}>
          {events.map((ev) => (
            <option key={ev.id} value={ev.id}>{ev.title}</option>
          ))}
        </select>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Add guest</h3>
        <form onSubmit={addGuest}>
          <div className="form-row">
            <div><label>Name</label><input value={name} onChange={(e) => setName(e.target.value)} required /></div>
            <div><label>Email</label><input value={email} onChange={(e) => setEmail(e.target.value)} /></div>
          </div>
          <div className="form-row">
            <div><label>Phone</label><input value={phone} onChange={(e) => setPhone(e.target.value)} /></div>
            <div><label>Plus ones</label><input type="number" min="0" value={plusOnes} onChange={(e) => setPlusOnes(e.target.value)} /></div>
          </div>
          <button className="btn" type="submit">Add to guest list</button>
        </form>
      </div>

      <div className="card">
        <table>
          <thead><tr><th>Name</th><th>Contact</th><th>+1</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            {guests.map((g) => (
              <tr key={g.id}>
                <td>{g.name}</td>
                <td>{g.email || g.phone || '—'}</td>
                <td>{g.plus_ones}</td>
                <td><span className="badge badge-gold">{g.status}</span></td>
                <td>
                  <button className="btn btn-sm btn-secondary" onClick={() => setStatus(g.id, 'checked_in')}>Check in</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
