import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatPeso } from '../lib/api';

const emptyForm = {
  slug: '',
  name: '',
  pricePeso: '',
  durationMinutes: '',
  includedDrinks: '',
  targetGuest: '',
  tagline: '',
  popular: false,
  active: true,
  sortOrder: '',
  untilClosing: false,
  unlimitedDrinks: false,
};

function packageLabel(pkg) {
  const mins =
    pkg.duration_minutes == null ? 'Until closing' : `${pkg.duration_minutes} min`;
  const drinks =
    pkg.included_drinks == null ? 'Unlimited drinks' : `${pkg.included_drinks} drinks`;
  return `${mins} · ${drinks}`;
}

export default function PackagesPage() {
  const { token } = useAuth();
  const [packages, setPackages] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState('');
  const [msg, setMsg] = useState('');

  const sorted = useMemo(
    () =>
      [...packages].sort(
        (a, b) =>
          (a.sort_order ?? 0) - (b.sort_order ?? 0) ||
          String(a.name).localeCompare(String(b.name)),
      ),
    [packages],
  );

  async function load() {
    const data = await api('/api/packages', { token });
    setPackages(data.packages ?? []);
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

  function startEdit(pkg) {
    setEditingId(pkg.id);
    setForm({
      slug: pkg.slug || '',
      name: pkg.name || '',
      pricePeso: pkg.price_peso ?? '',
      durationMinutes: pkg.duration_minutes ?? '',
      includedDrinks: pkg.included_drinks ?? '',
      targetGuest: pkg.target_guest || '',
      tagline: pkg.tagline || '',
      popular: Boolean(pkg.popular),
      active: pkg.active !== false,
      sortOrder: pkg.sort_order ?? '',
      untilClosing: pkg.duration_minutes == null,
      unlimitedDrinks: pkg.included_drinks == null,
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function startCreate() {
    resetForm();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function buildBody() {
    return {
      slug: form.slug || undefined,
      name: form.name,
      pricePeso: Number(form.pricePeso),
      durationMinutes: form.untilClosing ? null : Number(form.durationMinutes),
      includedDrinks: form.unlimitedDrinks ? null : Number(form.includedDrinks),
      targetGuest: form.targetGuest || null,
      tagline: form.tagline || null,
      popular: form.popular,
      active: form.active,
      sortOrder: form.sortOrder === '' ? undefined : Number(form.sortOrder),
    };
  }

  async function savePackage(e) {
    e.preventDefault();
    setErr('');
    setMsg('');

    if (!form.name.trim()) {
      setErr('Name is required.');
      return;
    }
    if (form.pricePeso === '' || Number(form.pricePeso) < 0) {
      setErr('Price must be >= 0.');
      return;
    }
    if (!form.untilClosing) {
      const mins = Number(form.durationMinutes);
      if (!Number.isFinite(mins) || mins <= 0) {
        setErr('Duration must be > 0 minutes, or enable Until closing.');
        return;
      }
    }
    if (!form.unlimitedDrinks) {
      const drinks = Number(form.includedDrinks);
      if (!Number.isFinite(drinks) || drinks < 0) {
        setErr('Included drinks must be >= 0, or enable Unlimited drinks.');
        return;
      }
    }

    setSaving(true);
    try {
      const body = buildBody();
      if (editingId) {
        await api(`/api/packages/${editingId}`, { method: 'PATCH', token, body });
        setMsg('Package updated.');
      } else {
        await api('/api/packages', { method: 'POST', token, body });
        setMsg('Package created.');
      }
      resetForm();
      await load();
    } catch (e) {
      setErr(e.message);
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(pkg) {
    setErr('');
    setMsg('');
    try {
      await api(`/api/packages/${pkg.id}`, {
        method: 'PATCH',
        token,
        body: { active: !pkg.active },
      });
      setMsg(pkg.active ? 'Package disabled.' : 'Package enabled.');
      await load();
    } catch (e) {
      setErr(e.message);
    }
  }

  async function movePackage(pkg, direction) {
    const index = sorted.findIndex((p) => p.id === pkg.id);
    if (index < 0) return;
    const swapWith = index + direction;
    if (swapWith < 0 || swapWith >= sorted.length) return;

    const next = [...sorted];
    const tmp = next[index];
    next[index] = next[swapWith];
    next[swapWith] = tmp;

    setErr('');
    setMsg('');
    try {
      const data = await api('/api/packages/reorder', {
        method: 'POST',
        token,
        body: { orderedIds: next.map((p) => p.id) },
      });
      setPackages(data.packages ?? next);
      setMsg('Order updated.');
    } catch (e) {
      setErr(e.message);
    }
  }

  async function deactivatePackage(pkg) {
    const ok = window.confirm(
      `Disable “${pkg.name}”? It will no longer appear in Load Package or the member app.`,
    );
    if (!ok) return;
    setErr('');
    setMsg('');
    try {
      await api(`/api/packages/${pkg.id}`, { method: 'DELETE', token });
      if (editingId === pkg.id) resetForm();
      setMsg('Package disabled.');
      await load();
    } catch (e) {
      setErr(e.message);
    }
  }

  if (loading) {
    return (
      <>
        <h2 className="page-title">Entry Packages</h2>
        <p className="page-sub">Manage what packages are available in the Blind Tiger app</p>
        <div className="page-loading">
          <span className="page-loading-dot" />
          Loading packages…
        </div>
      </>
    );
  }

  return (
    <>
      <div className="section-heading">
        <div>
          <h2 className="page-title">Entry Packages</h2>
          <p className="page-sub">
            Edit pricing, time, drink allowances, and which packages are available to sell.
            Cash desk “Load Package” uses the active catalog.
          </p>
        </div>
        <button className="btn btn-sm" type="button" onClick={startCreate}>
          New package
        </button>
      </div>

      {err && <p className="error">{err}</p>}
      {msg && <p className="success">{msg}</p>}

      <div className="card">
        <h3 style={{ marginTop: 0 }}>{editingId ? 'Edit package' : 'New package'}</h3>
        <form onSubmit={savePackage}>
          <div className="form-row">
            <div>
              <label>Name</label>
              <input
                value={form.name}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                required
              />
            </div>
            <div>
              <label>Slug</label>
              <input
                value={form.slug}
                onChange={(e) => setForm((f) => ({ ...f, slug: e.target.value }))}
                placeholder="auto from name"
                disabled={Boolean(editingId)}
              />
            </div>
          </div>

          <div className="form-row">
            <div>
              <label>Price (₱)</label>
              <input
                type="number"
                min="0"
                step="1"
                value={form.pricePeso}
                onChange={(e) => setForm((f) => ({ ...f, pricePeso: e.target.value }))}
                required
              />
            </div>
            <div>
              <label>Sort order</label>
              <input
                type="number"
                min="0"
                step="1"
                value={form.sortOrder}
                onChange={(e) => setForm((f) => ({ ...f, sortOrder: e.target.value }))}
                placeholder="auto"
              />
            </div>
          </div>

          <div className="form-row">
            <div>
              <label>Duration (minutes)</label>
              <input
                type="number"
                min="1"
                step="1"
                value={form.durationMinutes}
                disabled={form.untilClosing}
                onChange={(e) =>
                  setForm((f) => ({ ...f, durationMinutes: e.target.value }))
                }
              />
              <label className="checkbox-inline">
                <input
                  type="checkbox"
                  checked={form.untilClosing}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      untilClosing: e.target.checked,
                      durationMinutes: e.target.checked ? '' : f.durationMinutes,
                    }))
                  }
                />
                Until closing (soft 480 min)
              </label>
            </div>
            <div>
              <label>Included drinks</label>
              <input
                type="number"
                min="0"
                step="1"
                value={form.includedDrinks}
                disabled={form.unlimitedDrinks}
                onChange={(e) =>
                  setForm((f) => ({ ...f, includedDrinks: e.target.value }))
                }
              />
              <label className="checkbox-inline">
                <input
                  type="checkbox"
                  checked={form.unlimitedDrinks}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      unlimitedDrinks: e.target.checked,
                      includedDrinks: e.target.checked ? '' : f.includedDrinks,
                    }))
                  }
                />
                Unlimited (responsible soft cap)
              </label>
            </div>
          </div>

          <label>Target guest</label>
          <input
            value={form.targetGuest}
            onChange={(e) => setForm((f) => ({ ...f, targetGuest: e.target.value }))}
            placeholder="e.g. Most guests"
          />

          <label>Tagline</label>
          <input
            value={form.tagline}
            onChange={(e) => setForm((f) => ({ ...f, tagline: e.target.value }))}
            placeholder="e.g. Every second counts."
          />

          <div className="form-row" style={{ marginTop: 8 }}>
            <label className="checkbox-inline">
              <input
                type="checkbox"
                checked={form.popular}
                onChange={(e) => setForm((f) => ({ ...f, popular: e.target.checked }))}
              />
              Mark as popular
            </label>
            <label className="checkbox-inline">
              <input
                type="checkbox"
                checked={form.active}
                onChange={(e) => setForm((f) => ({ ...f, active: e.target.checked }))}
              />
              Active (available to sell / show in app)
            </label>
          </div>

          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <button className="btn" type="submit" disabled={saving}>
              {saving ? 'Saving…' : editingId ? 'Save changes' : 'Create package'}
            </button>
            {editingId && (
              <button className="btn btn-secondary" type="button" onClick={resetForm}>
                Cancel
              </button>
            )}
          </div>
        </form>
      </div>

      <div className="card" style={{ marginTop: 16 }}>
        <h3 style={{ marginTop: 0 }}>Catalog</h3>
        <table>
          <thead>
            <tr>
              <th>Order</th>
              <th>Package</th>
              <th>Price</th>
              <th>Allowance</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 ? (
              <tr>
                <td colSpan={6}>No packages yet. Create one above.</td>
              </tr>
            ) : (
              sorted.map((pkg, index) => (
                <tr key={pkg.id}>
                  <td>
                    <div style={{ display: 'flex', gap: 4 }}>
                      <button
                        type="button"
                        className="btn btn-secondary btn-sm"
                        disabled={index === 0}
                        onClick={() => movePackage(pkg, -1)}
                        aria-label="Move up"
                      >
                        ↑
                      </button>
                      <button
                        type="button"
                        className="btn btn-secondary btn-sm"
                        disabled={index === sorted.length - 1}
                        onClick={() => movePackage(pkg, 1)}
                        aria-label="Move down"
                      >
                        ↓
                      </button>
                    </div>
                  </td>
                  <td>
                    <strong>{pkg.name}</strong>
                    {pkg.popular ? (
                      <span className="badge badge-gold" style={{ marginLeft: 6 }}>
                        POPULAR
                      </span>
                    ) : null}
                    <div style={{ fontSize: 11, color: 'var(--muted)' }}>
                      {pkg.slug}
                      {pkg.target_guest ? ` · ${pkg.target_guest}` : ''}
                    </div>
                  </td>
                  <td>{formatPeso(pkg.price_peso)}</td>
                  <td>{packageLabel(pkg)}</td>
                  <td>
                    <span className={`badge ${pkg.active ? 'badge-green' : 'badge-gold'}`}>
                      {pkg.active ? 'ACTIVE' : 'OFF'}
                    </span>
                  </td>
                  <td style={{ textAlign: 'right', whiteSpace: 'nowrap' }}>
                    <button
                      type="button"
                      className="btn btn-secondary btn-sm"
                      onClick={() => startEdit(pkg)}
                    >
                      Edit
                    </button>{' '}
                    <button
                      type="button"
                      className="btn btn-secondary btn-sm"
                      onClick={() =>
                        pkg.active ? deactivatePackage(pkg) : toggleActive(pkg)
                      }
                    >
                      {pkg.active ? 'Disable' : 'Enable'}
                    </button>
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
