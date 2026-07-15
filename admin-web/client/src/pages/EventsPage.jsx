import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatDate } from '../lib/api';
import EventDateTimePicker from '../components/EventDateTimePicker';

function toLocalInputValue(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

const emptyForm = {
  title: '',
  startsAt: '',
  branch: 'The Blind Tiger — BGC',
  vipOnly: false,
  status: 'scheduled',
};

export default function EventsPage() {
  const { token } = useAuth();
  const [events, setEvents] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState('');

  async function load() {
    const data = await api('/api/events', { token });
    setEvents(data.events);
  }

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setErr('');
    load()
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

  function resetForm() {
    setEditingId(null);
    setForm(emptyForm);
  }

  function startEdit(ev) {
    setEditingId(ev.id);
    setForm({
      title: ev.title || '',
      startsAt: toLocalInputValue(ev.starts_at),
      branch: ev.branch || 'The Blind Tiger — BGC',
      vipOnly: Boolean(ev.vip_only),
      status: ev.status || 'scheduled',
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  async function saveEvent(e) {
    e.preventDefault();
    setErr('');
    setSaving(true);
    const body = {
      title: form.title,
      startsAt: new Date(form.startsAt).toISOString(),
      branch: form.branch,
      vipOnly: form.vipOnly,
      status: form.status,
    };
    try {
      if (editingId) {
        await api(`/api/events/${editingId}`, { method: 'PATCH', token, body });
      } else {
        await api('/api/events', { method: 'POST', token, body });
      }
      resetForm();
      await load();
    } catch (e) {
      setErr(e.message);
    } finally {
      setSaving(false);
    }
  }

  async function deleteEvent(ev) {
    const ok = window.confirm(
      `Delete “${ev.title}”? Guest list entries for this event will also be removed.`,
    );
    if (!ok) return;
    setErr('');
    try {
      await api(`/api/events/${ev.id}`, { method: 'DELETE', token });
      if (editingId === ev.id) resetForm();
      await load();
    } catch (e) {
      setErr(e.message);
    }
  }

  if (loading) {
    return (
      <>
        <h2 className="page-title">Calendar & Events</h2>
        <p className="page-sub">Schedule nights, VIP pours, and guest-list events</p>
        <div className="page-loading">
          <span className="page-loading-dot" />
          Loading events…
        </div>
      </>
    );
  }

  return (
    <>
      <h2 className="page-title">Calendar & Events</h2>
      <p className="page-sub">Schedule nights, VIP pours, and guest-list events</p>
      {err && <p className="error">{err}</p>}

      <div className="card">
        <h3 style={{ marginTop: 0 }}>{editingId ? 'Edit event' : 'New event'}</h3>
        <form onSubmit={saveEvent}>
          <label>Title</label>
          <input
            value={form.title}
            onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
            required
          />
          <label>Starts at</label>
          <EventDateTimePicker
            value={form.startsAt}
            onChange={(startsAt) => setForm((f) => ({ ...f, startsAt }))}
            required
          />
          <label>Branch</label>
          <input
            value={form.branch}
            onChange={(e) => setForm((f) => ({ ...f, branch: e.target.value }))}
          />
          <label>Status</label>
          <select
            value={form.status}
            onChange={(e) => setForm((f) => ({ ...f, status: e.target.value }))}
          >
            <option value="scheduled">scheduled</option>
            <option value="live">live</option>
            <option value="completed">completed</option>
            <option value="cancelled">cancelled</option>
          </select>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, textTransform: 'none' }}>
            <input
              type="checkbox"
              checked={form.vipOnly}
              onChange={(e) => setForm((f) => ({ ...f, vipOnly: e.target.checked }))}
              style={{ width: 'auto' }}
            />
            VIP / VVIP room event only
          </label>
          <div className="row-actions" style={{ marginTop: 12 }}>
            <button className="btn" type="submit" disabled={!form.startsAt || saving}>
              {saving ? 'Saving…' : editingId ? 'Save changes' : 'Create event'}
            </button>
            {editingId && (
              <button className="btn btn-secondary" type="button" onClick={resetForm}>
                Cancel edit
              </button>
            )}
          </div>
        </form>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>All events</h3>
        <table>
          <thead>
            <tr>
              <th>Title</th>
              <th>When</th>
              <th>Branch</th>
              <th>Status</th>
              <th>VIP</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {events.length === 0 ? (
              <tr>
                <td colSpan={6} style={{ color: 'var(--muted)' }}>
                  No events yet.
                </td>
              </tr>
            ) : (
              events.map((ev) => (
                <tr key={ev.id}>
                  <td>{ev.title}</td>
                  <td>{formatDate(ev.starts_at)}</td>
                  <td>{ev.branch}</td>
                  <td>
                    <span className="badge badge-gold">{ev.status}</span>
                  </td>
                  <td>{ev.vip_only ? 'Yes' : '—'}</td>
                  <td>
                    <div className="row-actions">
                      <button
                        type="button"
                        className="btn btn-sm btn-secondary"
                        onClick={() => startEdit(ev)}
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        className="btn btn-sm btn-danger"
                        onClick={() => deleteEvent(ev)}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
