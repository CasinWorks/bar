import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatDate, formatDuration, formatPeso, formatTimeLoad } from '../lib/api';
import { CASH_PACKAGES, previewLoad } from '../lib/timePricing';

export default function TimeLoadPage() {
  const { token } = useAuth();
  const [accounts, setAccounts] = useState([]);
  const [loads, setLoads] = useState([]);
  const [recipientId, setRecipientId] = useState('');
  const [selectedBill, setSelectedBill] = useState(1000);
  const [billCount, setBillCount] = useState(1);
  const [paymentMethod, setPaymentMethod] = useState('cash');
  const [notes, setNotes] = useState('');
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const [voidingId, setVoidingId] = useState(null);
  const [voidReason, setVoidReason] = useState('');

  const preview = useMemo(
    () => previewLoad(selectedBill, billCount, paymentMethod),
    [selectedBill, billCount, paymentMethod],
  );

  async function refresh() {
    const [u, l] = await Promise.all([
      api('/api/users?loadable=true', { token }),
      api('/api/time-loads', { token }),
    ]);
    setAccounts(u.users);
    setLoads(l.loads);
  }

  useEffect(() => {
    refresh().catch((e) => setErr(e.message));
  }, [token]);

  async function handleLoad(e) {
    e.preventDefault();
    setErr('');
    setMsg('');
    setBusy(true);
    try {
      const result = await api('/api/time-loads', {
        method: 'POST',
        token,
        body: {
          recipientId,
          amountPeso: selectedBill,
          billCount,
          paymentMethod,
          notes,
        },
      });
      const tender =
        paymentMethod === 'complimentary'
          ? `${result.totalMinutes} min comp`
          : `${formatPeso(result.totalPeso)} collected`;
      setMsg(
        `Loaded ${result.totalMinutes} min — ${tender}. Member phone updates live.`,
      );
      setNotes('');
      setBillCount(1);
      await refresh();
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleVoid(load) {
    if (!voidReason.trim()) {
      setErr('Enter a reason before voiding.');
      return;
    }
    if (!window.confirm(`Void ${formatDuration(load.seconds_loaded)} for ${load.recipient?.name ?? 'this account'}? Time will be removed from their wallet.`)) {
      return;
    }

    setErr('');
    setMsg('');
    setBusy(true);
    try {
      await api(`/api/time-loads/${load.id}/void`, {
        method: 'POST',
        token,
        body: { reason: voidReason.trim() },
      });
      setMsg('Load voided — time removed from wallet.');
      setVoidingId(null);
      setVoidReason('');
      await refresh();
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <h2 className="page-title">Load Time — Cash Desk</h2>
      <p className="page-sub">
        POS-style bills only. Pick what the guest handed you — time credits automatically.
      </p>

      <div className="card">
        {err && <p className="error">{err}</p>}
        {msg && <p className="success">{msg}</p>}
        <form onSubmit={handleLoad}>
          <label>Account</label>
          <select value={recipientId} onChange={(e) => setRecipientId(e.target.value)} required>
            <option value="">Select account…</option>
            {accounts.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name} — {a.email} [{a.role}] ({formatTimeLoad(a)})
              </option>
            ))}
          </select>

          <label>Bill received</label>
          <div className="bill-grid">
            {CASH_PACKAGES.map((pkg) => (
              <button
                key={pkg.peso}
                type="button"
                className={`bill-btn${selectedBill === pkg.peso ? ' selected' : ''}`}
                onClick={() => setSelectedBill(pkg.peso)}
              >
                <span className="bill-amount">{formatPeso(pkg.peso)}</span>
                <span className="bill-time">{pkg.label}</span>
              </button>
            ))}
          </div>

          <div className="form-row">
            <div>
              <label>How many of this bill?</label>
              <select value={billCount} onChange={(e) => setBillCount(Number(e.target.value))}>
                {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((n) => (
                  <option key={n} value={n}>
                    ×{n}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label>Payment</label>
              <select value={paymentMethod} onChange={(e) => setPaymentMethod(e.target.value)}>
                <option value="cash">Cash</option>
                <option value="card">Card</option>
                <option value="complimentary">Complimentary</option>
                <option value="other">Other</option>
              </select>
            </div>
          </div>

          {preview && (
            <div className="load-preview">
              <div>
                <span className="stat-label">Credits to wallet</span>
                <div className="stat-value stat-timer">{preview.totalMinutes} min</div>
              </div>
              <div>
                <span className="stat-label">
                  {paymentMethod === 'complimentary' ? 'Comp value' : 'Cash to drawer'}
                </span>
                <div className="stat-value">
                  {paymentMethod === 'complimentary' ? '₱0' : formatPeso(preview.totalPeso)}
                </div>
              </div>
            </div>
          )}

          <label>Notes</label>
          <textarea
            rows={2}
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Receipt #, promo, who comped…"
          />
          <button className="btn" type="submit" disabled={busy || !recipientId}>
            {busy ? 'Loading…' : `Credit ${preview?.totalMinutes ?? 0} min`}
          </button>
        </form>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Recent loads</h3>
        <table>
          <thead>
            <tr>
              <th>When</th>
              <th>Account</th>
              <th>Time</th>
              <th>Tender</th>
              <th>By</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loads.map((l) => {
              const voided = l.status === 'voided';
              return (
              <tr key={l.id} style={voided ? { opacity: 0.55 } : undefined}>
                <td>{formatDate(l.created_at)}</td>
                <td>{l.recipient?.name ?? l.member?.name}</td>
                <td>
                  {formatDuration(l.seconds_loaded)}
                  {voided && <span className="badge badge-red" style={{ marginLeft: 6 }}>VOIDED</span>}
                </td>
                <td>
                  {l.payment_method === 'complimentary'
                    ? 'Comp'
                    : formatPeso(l.amount_peso)}
                  {l.payment_method !== 'cash' && l.payment_method !== 'complimentary' && (
                    <span className="badge badge-gold" style={{ marginLeft: 6 }}>
                      {l.payment_method}
                    </span>
                  )}
                </td>
                <td>{voided ? l.voider?.name : l.loader?.name}</td>
                <td>
                  {!voided && (
                    voidingId === l.id ? (
                      <div style={{ minWidth: 200 }}>
                        <input
                          value={voidReason}
                          onChange={(e) => setVoidReason(e.target.value)}
                          placeholder="Reason for void…"
                          style={{ marginBottom: 6 }}
                        />
                        <div style={{ display: 'flex', gap: 6 }}>
                          <button type="button" className="btn btn-sm btn-danger" disabled={busy} onClick={() => handleVoid(l)}>
                            Confirm void
                          </button>
                          <button type="button" className="btn btn-sm btn-secondary" onClick={() => { setVoidingId(null); setVoidReason(''); }}>
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : (
                      <button type="button" className="btn btn-sm btn-secondary" onClick={() => { setVoidingId(l.id); setVoidReason(''); setErr(''); }}>
                        Void
                      </button>
                    )
                  )}
                  {voided && l.void_reason && (
                    <span style={{ fontSize: 11, color: 'var(--muted)', display: 'block' }}>
                      Voided {formatDate(l.voided_at)} — {l.void_reason}
                    </span>
                  )}
                </td>
              </tr>
            );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}
