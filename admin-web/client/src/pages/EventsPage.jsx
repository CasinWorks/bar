import { useEffect, useMemo, useState } from 'react';
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

function toLocalDateKey(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function defaultEndsAt(startsAt) {
  if (!startsAt) return '';
  const d = new Date(startsAt);
  if (Number.isNaN(d.getTime())) return '';
  d.setHours(d.getHours() + 4);
  return toLocalInputValue(d.toISOString());
}

function computeLifecycleStatus(startsAt, endsAt, cancelled) {
  if (cancelled) return 'cancelled';
  if (!startsAt || !endsAt) return 'scheduled';
  const now = Date.now();
  const start = new Date(startsAt).getTime();
  const end = new Date(endsAt).getTime();
  if (Number.isNaN(start) || Number.isNaN(end)) return 'scheduled';
  if (now >= end) return 'completed';
  if (now >= start) return 'live';
  return 'scheduled';
}

function formatWindow(startsAt, endsAt) {
  if (!startsAt) return '—';
  const startLabel = formatDate(startsAt);
  if (!endsAt) return startLabel;
  const end = new Date(endsAt);
  if (Number.isNaN(end.getTime())) return startLabel;
  const endLabel = end.toLocaleString(undefined, {
    hour: 'numeric',
    minute: '2-digit',
  });
  return `${startLabel} → ${endLabel}`;
}

function approvalBadgeClass(status) {
  switch (status) {
    case 'approved':
      return 'badge badge-green';
    case 'rejected':
      return 'badge badge-red';
    case 'needs_revision':
      return 'badge badge-gold';
    case 'pending_review':
    default:
      return 'badge badge-amber';
  }
}

function approvalLabel(status) {
  switch (status) {
    case 'pending_review':
      return 'pending approval';
    case 'needs_revision':
      return 'needs revision';
    default:
      return status || '—';
  }
}

function ConflictList({ conflicts }) {
  if (!conflicts?.length) return null;
  return (
    <div className="conflict-box">
      <strong>Conflict{conflicts.length > 1 ? 's' : ''}</strong>
      <ul>
        {conflicts.map((c) => (
          <li key={c.id}>
            {c.title} · {formatWindow(c.starts_at, c.ends_at)}
            {c.approval_status ? ` · ${approvalLabel(c.approval_status)}` : ''}
          </li>
        ))}
      </ul>
    </div>
  );
}

const emptyForm = {
  title: '',
  startsAt: '',
  endsAt: '',
  branch: 'The Blind Tiger — BGC',
  vipOnly: false,
  cancelled: false,
  force: false,
};

export default function EventsPage() {
  const { token } = useAuth();
  const [events, setEvents] = useState([]);
  const [pending, setPending] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [reviewingId, setReviewingId] = useState(null);
  const [reviewNotes, setReviewNotes] = useState({});
  const [formConflicts, setFormConflicts] = useState([]);
  const [err, setErr] = useState('');
  const [okMsg, setOkMsg] = useState('');

  const previewStatus = useMemo(
    () => computeLifecycleStatus(form.startsAt, form.endsAt, form.cancelled),
    [form.startsAt, form.endsAt, form.cancelled],
  );

  const windowValid =
    Boolean(form.startsAt) &&
    Boolean(form.endsAt) &&
    new Date(form.endsAt) > new Date(form.startsAt);

  const busyDates = useMemo(() => {
    const keys = new Set();
    for (const ev of events) {
      if (ev.status === 'cancelled' || ev.approval_status === 'rejected') continue;
      if (!ev.starts_at || !ev.ends_at) continue;
      const start = new Date(ev.starts_at);
      const end = new Date(ev.ends_at);
      if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) continue;
      const cursor = new Date(start.getFullYear(), start.getMonth(), start.getDate());
      const last = new Date(end.getFullYear(), end.getMonth(), end.getDate());
      while (cursor <= last) {
        keys.add(toLocalDateKey(cursor.toISOString()));
        cursor.setDate(cursor.getDate() + 1);
      }
    }
    return [...keys];
  }, [events]);

  async function load() {
    const [all, pendingRes] = await Promise.all([
      api('/api/events', { token }),
      api('/api/events/pending', { token }).catch(() => ({ events: [] })),
    ]);
    setEvents(all.events || []);
    setPending(pendingRes.events || []);
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

  useEffect(() => {
    if (!windowValid) {
      setFormConflicts([]);
      return undefined;
    }
    let cancelled = false;
    const startsAt = new Date(form.startsAt).toISOString();
    const endsAt = new Date(form.endsAt).toISOString();
    const params = new URLSearchParams({ startsAt, endsAt });
    if (editingId) params.set('excludeId', editingId);

    const handle = setTimeout(() => {
      api(`/api/events/conflicts?${params.toString()}`, { token })
        .then((data) => {
          if (!cancelled) setFormConflicts(data.conflicts || []);
        })
        .catch(() => {
          if (!cancelled) setFormConflicts([]);
        });
    }, 250);

    return () => {
      cancelled = true;
      clearTimeout(handle);
    };
  }, [form.startsAt, form.endsAt, editingId, token, windowValid]);

  function resetForm() {
    setEditingId(null);
    setForm(emptyForm);
    setFormConflicts([]);
  }

  function startEdit(ev) {
    setEditingId(ev.id);
    setForm({
      title: ev.title || '',
      startsAt: toLocalInputValue(ev.starts_at),
      endsAt: toLocalInputValue(ev.ends_at) || defaultEndsAt(toLocalInputValue(ev.starts_at)),
      branch: ev.branch || 'The Blind Tiger — BGC',
      vipOnly: Boolean(ev.vip_only),
      cancelled: ev.status === 'cancelled',
      force: false,
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  async function saveEvent(e) {
    e.preventDefault();
    setErr('');
    setOkMsg('');

    if (!form.startsAt || !form.endsAt) {
      setErr('Start and end date/time are required.');
      return;
    }
    if (new Date(form.endsAt) <= new Date(form.startsAt)) {
      setErr('End time must be after start time.');
      return;
    }
    if (formConflicts.length > 0 && !form.force) {
      setErr('This window conflicts with existing events. Review conflicts or check “Force save”.');
      return;
    }

    setSaving(true);
    const body = {
      title: form.title,
      startsAt: new Date(form.startsAt).toISOString(),
      endsAt: new Date(form.endsAt).toISOString(),
      branch: form.branch,
      vipOnly: form.vipOnly,
      status: form.cancelled ? 'cancelled' : previewStatus,
      force: form.force,
    };
    try {
      if (editingId) {
        await api(`/api/events/${editingId}`, { method: 'PATCH', token, body });
      } else {
        await api('/api/events', { method: 'POST', token, body });
      }
      resetForm();
      setOkMsg('Event saved to Supabase.');
      await load();
    } catch (error) {
      if (error?.status === 409 || error?.conflicts) {
        setFormConflicts(error.conflicts || formConflicts);
        setErr(error.message || 'Conflict with existing events.');
      } else {
        setErr(error.message);
      }
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
    setOkMsg('');
    try {
      await api(`/api/events/${ev.id}`, { method: 'DELETE', token });
      if (editingId === ev.id) resetForm();
      setOkMsg('Event deleted from Supabase.');
      await load();
    } catch (e) {
      setErr(e.message);
    }
  }

  async function reviewEvent(ev, decision, force = false) {
    setErr('');
    setOkMsg('');
    setReviewingId(ev.id);
    try {
      await api(`/api/events/${ev.id}/review`, {
        method: 'POST',
        token,
        body: {
          decision,
          notes: reviewNotes[ev.id] || '',
          force,
        },
      });
      setOkMsg(
        decision === 'approved'
          ? `Approved “${ev.title}”. Host notified.`
          : decision === 'rejected'
            ? `Cancelled/rejected “${ev.title}”. Host notified.`
            : `Marked “${ev.title}” as needs revision.`,
      );
      await load();
    } catch (error) {
      if (error?.status === 409 || error?.conflicts?.length) {
        const titles = (error.conflicts || [])
          .map((c) => c.title)
          .filter(Boolean)
          .join(', ');
        const proceed = window.confirm(
          `${error.message || 'Conflict detected.'}\n\nOverlaps: ${titles || 'existing events'}\n\nForce approve anyway?`,
        );
        if (proceed) {
          await reviewEvent(ev, decision, true);
          return;
        }
        setErr(error.message);
      } else {
        setErr(error.message);
      }
    } finally {
      setReviewingId(null);
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
      <p className="page-sub">
        Pending host requests, conflict checks, and venue calendar — all synced to Supabase
      </p>
      {err && <p className="error">{err}</p>}
      {okMsg && <p className="success">{okMsg}</p>}

      <div className="card">
        <h3 style={{ marginTop: 0 }}>
          Pending approval
          {pending.length > 0 ? (
            <span className="badge badge-amber" style={{ marginLeft: 8 }}>
              {pending.length}
            </span>
          ) : null}
        </h3>
        {pending.length === 0 ? (
          <p style={{ color: 'var(--muted)', marginBottom: 0 }}>
            No host event requests waiting for review.
          </p>
        ) : (
          <div className="pending-stack">
            {pending.map((ev) => (
              <div key={ev.id} className="pending-card">
                <div className="pending-card-head">
                  <div>
                    <strong>{ev.title}</strong>
                    <div className="pending-meta">
                      {formatWindow(ev.starts_at, ev.ends_at)}
                      {ev.branch ? ` · ${ev.branch}` : ''}
                    </div>
                    <div className="pending-meta">
                      Host: {ev.host_name || ev.requester_name || '—'}
                      {ev.host_email ? ` (${ev.host_email})` : ''}
                      {ev.minimum_pax != null ? ` · min pax ${ev.minimum_pax}` : ''}
                      {ev.event_type ? ` · ${ev.event_type}` : ''}
                    </div>
                  </div>
                  <span className={approvalBadgeClass(ev.approval_status)}>
                    {approvalLabel(ev.approval_status)}
                  </span>
                </div>

                {ev.request_notes ? (
                  <p className="pending-notes">Host notes: {ev.request_notes}</p>
                ) : null}

                <ConflictList conflicts={ev.conflicts} />

                <label>Review notes (optional)</label>
                <textarea
                  rows={2}
                  value={reviewNotes[ev.id] || ''}
                  onChange={(e) =>
                    setReviewNotes((prev) => ({ ...prev, [ev.id]: e.target.value }))
                  }
                  placeholder="Shown to the host with the decision"
                />

                <div className="row-actions" style={{ marginTop: 10 }}>
                  <button
                    type="button"
                    className="btn btn-sm"
                    disabled={reviewingId === ev.id}
                    onClick={() => reviewEvent(ev, 'approved')}
                  >
                    {reviewingId === ev.id ? 'Working…' : 'Approve'}
                  </button>
                  <button
                    type="button"
                    className="btn btn-sm btn-secondary"
                    disabled={reviewingId === ev.id}
                    onClick={() => reviewEvent(ev, 'needs_revision')}
                  >
                    Needs revision
                  </button>
                  <button
                    type="button"
                    className="btn btn-sm btn-danger"
                    disabled={reviewingId === ev.id}
                    onClick={() => {
                      const ok = window.confirm(
                        `Cancel/reject “${ev.title}”? The host will be notified.`,
                      );
                      if (ok) reviewEvent(ev, 'rejected');
                    }}
                  >
                    Cancel request
                  </button>
                  <button
                    type="button"
                    className="btn btn-sm btn-ghost"
                    onClick={() => startEdit(ev)}
                  >
                    Edit details
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

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
            timeLabel="Start time"
            allowPast={Boolean(editingId)}
            busyDates={busyDates}
            onChange={(startsAt) =>
              setForm((f) => {
                const next = { ...f, startsAt };
                if (!f.endsAt || (startsAt && new Date(f.endsAt) <= new Date(startsAt))) {
                  next.endsAt = defaultEndsAt(startsAt);
                }
                return next;
              })
            }
            required
          />
          <label>Ends at</label>
          <EventDateTimePicker
            value={form.endsAt}
            timeLabel="End time"
            allowPast={Boolean(editingId)}
            busyDates={busyDates}
            onChange={(endsAt) => setForm((f) => ({ ...f, endsAt }))}
            required
          />
          {!windowValid && form.startsAt && form.endsAt && (
            <p className="error" style={{ marginTop: 8 }}>
              End time must be after start time.
            </p>
          )}
          <ConflictList conflicts={formConflicts} />
          <label>Branch</label>
          <input
            value={form.branch}
            onChange={(e) => setForm((f) => ({ ...f, branch: e.target.value }))}
          />
          <label>Lifecycle status</label>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              marginBottom: 8,
              flexWrap: 'wrap',
            }}
          >
            <span className="badge badge-gold">{previewStatus}</span>
            <span style={{ color: 'var(--muted)', fontSize: 13 }}>
              Derived from start/end (scheduled → live → completed). Cancel only if needed.
            </span>
          </div>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, textTransform: 'none' }}>
            <input
              type="checkbox"
              checked={form.cancelled}
              onChange={(e) => setForm((f) => ({ ...f, cancelled: e.target.checked }))}
              style={{ width: 'auto' }}
            />
            Mark as cancelled
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, textTransform: 'none' }}>
            <input
              type="checkbox"
              checked={form.vipOnly}
              onChange={(e) => setForm((f) => ({ ...f, vipOnly: e.target.checked }))}
              style={{ width: 'auto' }}
            />
            VIP / VVIP room event only
          </label>
          {formConflicts.length > 0 && (
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, textTransform: 'none' }}>
              <input
                type="checkbox"
                checked={form.force}
                onChange={(e) => setForm((f) => ({ ...f, force: e.target.checked }))}
                style={{ width: 'auto' }}
              />
              Force save despite conflicts
            </label>
          )}
          <div className="row-actions" style={{ marginTop: 12 }}>
            <button
              className="btn"
              type="submit"
              disabled={!form.startsAt || !form.endsAt || !windowValid || saving}
            >
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
        <h3 style={{ marginTop: 0 }}>All events (Supabase)</h3>
        <table>
          <thead>
            <tr>
              <th>Title</th>
              <th>Window</th>
              <th>Host</th>
              <th>Approval</th>
              <th>Status</th>
              <th>Conflicts</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {events.length === 0 ? (
              <tr>
                <td colSpan={7} style={{ color: 'var(--muted)' }}>
                  No events yet.
                </td>
              </tr>
            ) : (
              events.map((ev) => (
                <tr key={ev.id}>
                  <td>
                    {ev.title}
                    {ev.vip_only ? (
                      <span className="badge badge-gold" style={{ marginLeft: 6 }}>
                        VIP
                      </span>
                    ) : null}
                  </td>
                  <td>{formatWindow(ev.starts_at, ev.ends_at)}</td>
                  <td>{ev.host_name || ev.requester_name || '—'}</td>
                  <td>
                    <span className={approvalBadgeClass(ev.approval_status)}>
                      {approvalLabel(ev.approval_status)}
                    </span>
                  </td>
                  <td>
                    <span className="badge badge-gold">{ev.status}</span>
                  </td>
                  <td>
                    {ev.conflicts?.length ? (
                      <span className="badge badge-red">{ev.conflicts.length} overlap</span>
                    ) : (
                      <span style={{ color: 'var(--muted)' }}>—</span>
                    )}
                  </td>
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
