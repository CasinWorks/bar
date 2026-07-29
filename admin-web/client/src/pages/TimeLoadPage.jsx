import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatDate, formatDuration, formatPeso, formatTimeLoad } from '../lib/api';
import { ENTRY_PACKAGES, previewLoad } from '../lib/timePricing';

const BONUS_RULES = [
  { slug: 'birthday', name: 'Birthday Celebration', minutes: 15 },
  { slug: 'bring-a-friend', name: 'Bring a Friend', minutes: 20 },
  { slug: 'club-games', name: 'Win Club Games', minutes: 30 },
  { slug: 'dance-competition', name: 'Dance Competition', minutes: 60 },
  { slug: 'social-media', name: 'Social Media', minutes: 10 },
  { slug: 'loyalty-daily', name: 'Loyalty Daily', minutes: 10 },
  { slug: 'special-events', name: 'Special Events', minutes: null },
];

function toDeskPackage(row) {
  if (!row) return null;
  if (row.peso != null && row.label) return row;
  const minutes = row.duration_minutes ?? row.minutes ?? null;
  const drinks = row.included_drinks ?? row.drinks ?? null;
  const minsLabel = minutes == null ? 'Until closing' : `${minutes} min`;
  const drinksLabel =
    drinks == null ? 'drinks incl.' : `${drinks} drink${drinks === 1 ? '' : 's'}`;
  return {
    slug: row.slug,
    name: row.name,
    peso: Number(row.price_peso ?? row.peso ?? 0),
    minutes,
    drinks,
    target: row.target_guest ?? row.target ?? '',
    label: row.label || `${minsLabel} · ${drinksLabel}`,
    popular: Boolean(row.popular),
  };
}

export default function TimeLoadPage() {
  const { token } = useAuth();
  const [accounts, setAccounts] = useState([]);
  const [loads, setLoads] = useState([]);
  const [packages, setPackages] = useState(ENTRY_PACKAGES);
  const [recipientId, setRecipientId] = useState('');
  const [selectedSlug, setSelectedSlug] = useState('standard-night');
  const [quantity, setQuantity] = useState(1);
  const [paymentMethod, setPaymentMethod] = useState('cash');
  const [notes, setNotes] = useState('');
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const [voidingId, setVoidingId] = useState(null);
  const [voidReason, setVoidReason] = useState('');
  const [bonusRule, setBonusRule] = useState('birthday');
  const [bonusMinutes, setBonusMinutes] = useState('');
  const [bonusRecipient, setBonusRecipient] = useState('');

  const preview = useMemo(
    () => previewLoad(selectedSlug, quantity, paymentMethod, packages),
    [selectedSlug, quantity, paymentMethod, packages],
  );

  async function refresh() {
    const [u, l, p] = await Promise.all([
      api('/api/users?loadable=true', { token }),
      api('/api/time-loads', { token }),
      api('/api/packages/active', { token }).catch(() =>
        api('/api/time-loads/packages', { token }),
      ),
    ]);
    setAccounts(u.users);
    setLoads(l.loads);
    const nextPackages = (p.packages ?? []).map(toDeskPackage).filter(Boolean);
    if (nextPackages.length) {
      setPackages(nextPackages);
      setSelectedSlug((prev) =>
        nextPackages.some((pkg) => pkg.slug === prev)
          ? prev
          : nextPackages.find((pkg) => pkg.popular)?.slug || nextPackages[0].slug,
      );
    }
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
          packageSlug: selectedSlug,
          quantity,
          paymentMethod,
          notes,
        },
      });
      const tender =
        paymentMethod === 'complimentary'
          ? `${result.totalMinutes} min comp`
          : `${formatPeso(result.totalPeso)} collected`;
      const drinksBit =
        result.drinks == null ? 'drinks unlimited (soft cap)' : `${result.drinks} drinks`;
      setMsg(
        `Loaded ${result.packageName ?? selectedSlug}: ${result.totalMinutes} min · ${drinksBit} — ${tender}.`,
      );
      setNotes('');
      setQuantity(1);
      await refresh();
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleBonus(e) {
    e.preventDefault();
    setErr('');
    setMsg('');
    setBusy(true);
    try {
      const rule = BONUS_RULES.find((r) => r.slug === bonusRule);
      const mins = bonusMinutes ? Number(bonusMinutes) : rule?.minutes;
      await api('/api/time-loads/bonus', {
        method: 'POST',
        token,
        body: {
          recipientId: bonusRecipient || recipientId,
          ruleSlug: bonusRule,
          minutes: mins,
          notes: notes || undefined,
        },
      });
      setMsg(`Bonus time awarded (${mins ?? '?'} min).`);
      setBonusMinutes('');
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
      <h2 className="page-title">Load Package — Cash Desk</h2>
      <p className="page-sub">
        Time is the currency. Sell an entry package — minutes and drink allowance credit automatically.
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

          <label>Entry package</label>
          <div className="bill-grid">
            {packages.map((pkg) => (
              <button
                key={pkg.slug}
                type="button"
                className={`bill-btn${selectedSlug === pkg.slug ? ' selected' : ''}`}
                onClick={() => setSelectedSlug(pkg.slug)}
              >
                <span className="bill-amount">{pkg.name}</span>
                <span className="bill-time">{formatPeso(pkg.peso)}</span>
                <span className="bill-time">{pkg.label}</span>
              </button>
            ))}
          </div>

          <div className="form-row">
            <div>
              <label>Quantity</label>
              <select value={quantity} onChange={(e) => setQuantity(Number(e.target.value))}>
                {[1, 2, 3, 4, 5].map((n) => (
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
                <span className="stat-label">Drinks included</span>
                <div className="stat-value">
                  {preview.drinks == null ? 'Unlimited*' : preview.drinks}
                </div>
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
            {busy ? 'Loading…' : `Credit ${preview?.name ?? 'package'}`}
          </button>
        </form>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Award bonus time</h3>
        <form onSubmit={handleBonus}>
          <label>Account</label>
          <select
            value={bonusRecipient || recipientId}
            onChange={(e) => setBonusRecipient(e.target.value)}
            required
          >
            <option value="">Select account…</option>
            {accounts.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name} — {a.email}
              </option>
            ))}
          </select>
          <div className="form-row">
            <div>
              <label>Bonus</label>
              <select value={bonusRule} onChange={(e) => setBonusRule(e.target.value)}>
                {BONUS_RULES.map((r) => (
                  <option key={r.slug} value={r.slug}>
                    {r.name}
                    {r.minutes != null ? ` (+${r.minutes}m)` : ' (variable)'}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label>Minutes (override)</label>
              <input
                type="number"
                min="1"
                value={bonusMinutes}
                onChange={(e) => setBonusMinutes(e.target.value)}
                placeholder="Auto from rule"
              />
            </div>
          </div>
          <button className="btn btn-secondary" type="submit" disabled={busy}>
            Award bonus minutes
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
              <th>Package</th>
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
                <td>{l.package_slug ?? '—'}</td>
                <td>
                  {formatDuration(l.seconds_loaded)}
                  {l.drinks_granted != null && (
                    <span style={{ color: 'var(--muted)', fontSize: 11 }}> · {l.drinks_granted} drinks</span>
                  )}
                  {voided && <span className="badge badge-red" style={{ marginLeft: 6 }}>VOIDED</span>}
                </td>
                <td>
                  {l.payment_method === 'complimentary'
                    ? 'Comp'
                    : formatPeso(l.amount_peso)}
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
