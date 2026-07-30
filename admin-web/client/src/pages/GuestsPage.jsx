import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api } from '../lib/api';

const UNLINKED_HINT =
  'No app account matches this guest email — the event will not appear in their mobile app.';

export default function GuestsPage() {
  const { token } = useAuth();
  const [events, setEvents] = useState([]);
  const [eventId, setEventId] = useState('');
  const [guests, setGuests] = useState([]);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [plusOnes, setPlusOnes] = useState('0');
  const [loading, setLoading] = useState(true);
  const [guestsLoading, setGuestsLoading] = useState(false);
  const [err, setErr] = useState('');
  const [warning, setWarning] = useState('');

  async function refreshGuests(id = eventId) {
    if (!id) {
      setGuests([]);
      return;
    }
    const d = await api(`/api/guests/event/${id}`, { token });
    setGuests(d.guests);
  }

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setErr('');
    api('/api/events', { token })
      .then((d) => {
        if (cancelled) return;
        setEvents(d.events);
        setEventId((prev) => prev || d.events[0]?.id || '');
      })
      .catch((e) => {
        if (!cancelled) setErr(e.message);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [token]);

  useEffect(() => {
    if (!eventId) {
      setGuests([]);
      return;
    }
    let cancelled = false;
    setGuestsLoading(true);
    setErr('');
    refreshGuests(eventId)
      .catch((e) => {
        if (!cancelled) setErr(e.message);
      })
      .finally(() => {
        if (!cancelled) setGuestsLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [token, eventId]);

  async function addGuest(e) {
    e.preventDefault();
    setErr('');
    setWarning('');
    try {
      const d = await api('/api/guests', {
        method: 'POST',
        token,
        body: { eventId, name, email, phone, plusOnes: Number(plusOnes) },
      });
      if (d.warning) setWarning(d.warning);
      setName('');
      setEmail('');
      setPhone('');
      setPlusOnes('0');
      await refreshGuests();
    } catch (e) {
      setErr(e.message);
    }
  }

  async function setStatus(id, status) {
    setErr('');
    try {
      await api(`/api/guests/${id}`, { method: 'PATCH', token, body: { status } });
      await refreshGuests();
    } catch (e) {
      setErr(e.message);
    }
  }

  async function relinkGuest(g) {
    setErr('');
    setWarning('');
    try {
      const d = await api(`/api/guests/${g.id}`, {
        method: 'PATCH',
        token,
        body: { email: g.email || '' },
      });
      if (d.warning) setWarning(d.warning);
      await refreshGuests();
    } catch (e) {
      setErr(e.message);
    }
  }

  async function removeGuest(g) {
    const ok = window.confirm(`Remove “${g.name}” from this guest list?`);
    if (!ok) return;
    setErr('');
    try {
      await api(`/api/guests/${g.id}`, { method: 'DELETE', token });
      await refreshGuests();
    } catch (e) {
      setErr(e.message);
    }
  }

  if (loading) {
    return (
      <>
        <h2 className="page-title">Guest List</h2>
        <p className="page-sub">Door whitelist per event — check-in from admin desk</p>
        <div className="page-loading">
          <span className="page-loading-dot" />
          Loading guest lists…
        </div>
      </>
    );
  }

  return (
    <>
      <h2 className="page-title">Guest List</h2>
      <p className="page-sub">Door whitelist per event — check-in from admin desk</p>
      {err && <p className="error">{err}</p>}
      {warning && <p className="error">{warning}</p>}

      <div className="toolbar">
        <label>Event</label>
        <select value={eventId} onChange={(e) => setEventId(e.target.value)} disabled={!events.length}>
          {events.length === 0 ? (
            <option value="">No events</option>
          ) : (
            events.map((ev) => (
              <option key={ev.id} value={ev.id}>
                {ev.title}
              </option>
            ))
          )}
        </select>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Add guest</h3>
        <form onSubmit={addGuest}>
          <div className="form-row">
            <div>
              <label>Name</label>
              <input value={name} onChange={(e) => setName(e.target.value)} required disabled={!eventId} />
            </div>
            <div>
              <label>Email (must match their app account)</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={!eventId}
              />
            </div>
          </div>
          <div className="form-row">
            <div>
              <label>Phone</label>
              <input value={phone} onChange={(e) => setPhone(e.target.value)} disabled={!eventId} />
            </div>
            <div>
              <label>Plus ones</label>
              <input
                type="number"
                min="0"
                value={plusOnes}
                onChange={(e) => setPlusOnes(e.target.value)}
                disabled={!eventId}
              />
            </div>
          </div>
          <button className="btn" type="submit" disabled={!eventId}>
            Add to guest list
          </button>
          <p className="page-sub" style={{ marginBottom: 0 }}>
            Email must match their app account. If the account already exists we
            link it immediately; if they sign up later with the same email, the
            guest list peers automatically so the event appears in-app and at
            the door.
          </p>
        </form>
      </div>

      <div className="card">
        {guestsLoading ? (
          <div className="page-loading">
            <span className="page-loading-dot" />
            Loading guests…
          </div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Contact</th>
                <th>+1</th>
                <th>App account</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {guests.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ color: 'var(--muted)' }}>
                    {eventId ? 'No guests on this list yet.' : 'Create an event first.'}
                  </td>
                </tr>
              ) : (
                guests.map((g) => (
                  <tr key={g.id}>
                    <td>{g.name}</td>
                    <td>{g.email || g.phone || '—'}</td>
                    <td>{g.plus_ones}</td>
                    <td>
                      {g.member_id ? (
                        <span className="badge">Linked</span>
                      ) : (
                        <span className="badge badge-gold" title={UNLINKED_HINT}>
                          Not in app
                        </span>
                      )}
                    </td>
                    <td>
                      <span className="badge badge-gold">{g.status}</span>
                    </td>
                    <td>
                      <div className="row-actions">
                        {!g.member_id && g.email && (
                          <button
                            type="button"
                            className="btn btn-sm btn-secondary"
                            onClick={() => relinkGuest(g)}
                          >
                            Link app account
                          </button>
                        )}
                        {g.status !== 'checked_in' && (
                          <button
                            type="button"
                            className="btn btn-sm btn-secondary"
                            onClick={() => setStatus(g.id, 'checked_in')}
                          >
                            Check in
                          </button>
                        )}
                        <button
                          type="button"
                          className="btn btn-sm btn-danger"
                          onClick={() => removeGuest(g)}
                        >
                          Remove
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
