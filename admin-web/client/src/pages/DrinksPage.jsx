import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api, formatPeso } from '../lib/api';

const emptyForm = {
  slug: '',
  name: '',
  kind: 'premium',
  timeCostSeconds: '600',
  pricePeso: '',
  category: 'spirits',
  description: '',
  flavor: '',
  abv: '',
  badge: '',
  ingredients: '',
  bartenderQuote: '',
  active: true,
  sortOrder: '',
};

function minutesLabel(seconds) {
  const s = Number(seconds || 0);
  if (s <= 0) return '0 min';
  if (s % 60 === 0) return `${s / 60} min`;
  return `${Math.floor(s / 60)}m ${s % 60}s`;
}

function priceLabel(peso) {
  if (peso == null || peso === '') return '—';
  return formatPeso(peso);
}

export default function DrinksPage() {
  const { token } = useAuth();
  const [drinks, setDrinks] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [busyId, setBusyId] = useState(null);
  const [err, setErr] = useState('');
  const [msg, setMsg] = useState('');
  const [priceDrafts, setPriceDrafts] = useState({});

  const sorted = useMemo(
    () =>
      [...drinks].sort(
        (a, b) =>
          (a.sort_order ?? 0) - (b.sort_order ?? 0) ||
          String(a.name).localeCompare(String(b.name)),
      ),
    [drinks],
  );

  async function load() {
    const data = await api('/api/drinks', { token });
    const rows = data.drinks ?? [];
    setDrinks(rows);
    const drafts = {};
    for (const drink of rows) {
      drafts[drink.id] = drink.price_peso == null ? '' : String(drink.price_peso);
    }
    setPriceDrafts(drafts);
  }

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
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
    setErr('');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function startEdit(drink) {
    setEditingId(drink.id);
    setForm({
      slug: drink.slug || '',
      name: drink.name || '',
      kind: drink.kind || 'premium',
      timeCostSeconds: String(drink.time_cost_seconds ?? 0),
      pricePeso: drink.price_peso == null ? '' : String(drink.price_peso),
      category: drink.category || 'spirits',
      description: drink.description || '',
      flavor: drink.flavor || '',
      abv: drink.abv || '',
      badge: drink.badge || '',
      ingredients: Array.isArray(drink.ingredients) ? drink.ingredients.join('\n') : '',
      bartenderQuote: drink.bartender_quote || '',
      active: drink.active !== false,
      sortOrder: drink.sort_order == null ? '' : String(drink.sort_order),
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function buildBody() {
    return {
      slug: form.slug || undefined,
      name: form.name,
      kind: form.kind,
      timeCostSeconds: Number(form.timeCostSeconds || 0),
      pricePeso: form.pricePeso === '' ? null : Number(form.pricePeso),
      category: form.category,
      description: form.description,
      flavor: form.flavor,
      abv: form.abv,
      badge: form.badge || null,
      ingredients: form.ingredients,
      bartenderQuote: form.bartenderQuote,
      active: form.active,
      sortOrder: form.sortOrder === '' ? undefined : Number(form.sortOrder),
    };
  }

  async function saveDrink(event) {
    event.preventDefault();
    setSaving(true);
    setErr('');
    setMsg('');
    try {
      const body = buildBody();
      if (body.pricePeso != null && (!Number.isFinite(body.pricePeso) || body.pricePeso < 0)) {
        throw new Error('Price must be a whole number ₱ amount (or leave blank).');
      }
      if (editingId) {
        await api(`/api/drinks/${editingId}`, { method: 'PATCH', token, body });
        setMsg(`Updated ${body.name}`);
      } else {
        await api('/api/drinks', { method: 'POST', token, body });
        setMsg(`Added ${body.name} to the menu`);
      }
      resetForm();
      await load();
    } catch (e) {
      setErr(e.message);
    } finally {
      setSaving(false);
    }
  }

  async function savePrice(drink) {
    const raw = priceDrafts[drink.id];
    const pricePeso = raw === '' || raw == null ? null : Number(raw);
    if (pricePeso != null && (!Number.isFinite(pricePeso) || !Number.isInteger(pricePeso) || pricePeso < 0)) {
      setErr('Price must be a whole number ₱ amount (or empty).');
      return;
    }
    if (pricePeso === drink.price_peso || (pricePeso == null && drink.price_peso == null)) {
      setMsg('Price unchanged.');
      return;
    }

    try {
      setBusyId(drink.id);
      setErr('');
      setMsg('');
      await api(`/api/drinks/${drink.id}`, {
        method: 'PATCH',
        token,
        body: { pricePeso },
      });
      setMsg(
        pricePeso == null
          ? `Cleared price on ${drink.name}`
          : `Set ${drink.name} to ${formatPeso(pricePeso)}`,
      );
      await load();
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusyId(null);
    }
  }

  async function toggleActive(drink) {
    try {
      setBusyId(drink.id);
      setErr('');
      await api(`/api/drinks/${drink.id}`, {
        method: 'PATCH',
        token,
        body: { active: !drink.active },
      });
      await load();
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusyId(null);
    }
  }

  async function removeDrink(drink) {
    const confirmed = window.confirm(
      `Remove "${drink.name}" from the menu?\n\nThis deletes it from inventory. Staff POS and the guest lounge will stop offering it.`,
    );
    if (!confirmed) return;

    try {
      setBusyId(drink.id);
      setErr('');
      setMsg('');
      await api(`/api/drinks/${drink.id}`, { method: 'DELETE', token });
      if (editingId === drink.id) resetForm();
      setMsg(`Removed ${drink.name}`);
      await load();
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, alignItems: 'flex-start' }}>
        <div>
          <h2 className="page-title">Drink inventory</h2>
          <p className="page-sub">
            Add, price, edit, or remove drinks for the bartender POS and guest lounge. Price is the
            menu ₱ amount; time cost is what the guest wallet burns (premium) or package allowance
            (standard).
          </p>
        </div>
        <button className="btn btn-sm" type="button" onClick={resetForm}>
          Add drink
        </button>
      </div>

      {err && <p className="error">{err}</p>}
      {msg && <p className="success">{msg}</p>}

      <div className="card">
        <h3 style={{ marginTop: 0 }}>{editingId ? 'Edit drink' : 'Add drink'}</h3>
        <form onSubmit={saveDrink}>
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
              <label>Menu price (₱)</label>
              <input
                type="number"
                min="0"
                step="1"
                value={form.pricePeso}
                onChange={(e) => setForm((f) => ({ ...f, pricePeso: e.target.value }))}
                placeholder="e.g. 480"
              />
              <p className="page-sub" style={{ margin: '4px 0 0' }}>
                Shown on POS / menu. Leave blank if package-included only.
              </p>
            </div>
            <div>
              <label>Kind</label>
              <select
                value={form.kind}
                onChange={(e) => setForm((f) => ({ ...f, kind: e.target.value }))}
              >
                <option value="standard">Standard (package drink)</option>
                <option value="premium">Premium (time cost)</option>
              </select>
            </div>
          </div>

          <div className="form-row">
            <div>
              <label>Time cost (seconds)</label>
              <input
                type="number"
                min="0"
                step="60"
                value={form.timeCostSeconds}
                onChange={(e) => setForm((f) => ({ ...f, timeCostSeconds: e.target.value }))}
              />
              <p className="page-sub" style={{ margin: '4px 0 0' }}>
                {minutesLabel(form.timeCostSeconds)} charged from time wallet when not covered by
                package
              </p>
            </div>
            <div>
              <label>Category</label>
              <input
                value={form.category}
                onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}
                placeholder="spirits / beer / cocktail"
              />
            </div>
          </div>

          <div className="form-row">
            <div>
              <label>Badge</label>
              <input
                value={form.badge}
                onChange={(e) => setForm((f) => ({ ...f, badge: e.target.value }))}
                placeholder="Signature"
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

          <label>Description</label>
          <textarea
            rows={3}
            value={form.description}
            onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
          />

          <div className="form-row">
            <div>
              <label>Flavor</label>
              <input
                value={form.flavor}
                onChange={(e) => setForm((f) => ({ ...f, flavor: e.target.value }))}
              />
            </div>
            <div>
              <label>ABV</label>
              <input
                value={form.abv}
                onChange={(e) => setForm((f) => ({ ...f, abv: e.target.value }))}
                placeholder="14% ABV"
              />
            </div>
          </div>

          <label>Ingredients (one per line)</label>
          <textarea
            rows={3}
            value={form.ingredients}
            onChange={(e) => setForm((f) => ({ ...f, ingredients: e.target.value }))}
          />

          <label>Bartender quote</label>
          <input
            value={form.bartenderQuote}
            onChange={(e) => setForm((f) => ({ ...f, bartenderQuote: e.target.value }))}
          />

          <label className="checkbox-inline" style={{ marginTop: 12 }}>
            <input
              type="checkbox"
              checked={form.active}
              onChange={(e) => setForm((f) => ({ ...f, active: e.target.checked }))}
            />
            Offered on POS / menu
          </label>

          <div style={{ marginTop: 16, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button className="btn" type="submit" disabled={saving}>
              {saving ? 'Saving…' : editingId ? 'Save changes' : 'Add to menu'}
            </button>
            {editingId && (
              <>
                <button className="btn btn-secondary" type="button" onClick={resetForm}>
                  Cancel
                </button>
                <button
                  className="btn btn-secondary"
                  type="button"
                  disabled={busyId === editingId}
                  onClick={() => {
                    const drink = drinks.find((d) => d.id === editingId);
                    if (drink) removeDrink(drink);
                  }}
                  style={{ color: 'var(--red)' }}
                >
                  Remove drink
                </button>
              </>
            )}
          </div>
        </form>
      </div>

      <div className="card" style={{ marginTop: 16 }}>
        <h3 style={{ marginTop: 0 }}>Current menu</h3>
        {loading ? (
          <p className="page-sub">Loading…</p>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table>
              <thead>
                <tr>
                  <th>Drink</th>
                  <th>Kind</th>
                  <th>Price ₱</th>
                  <th>Time</th>
                  <th>Status</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {sorted.length === 0 && (
                  <tr>
                    <td colSpan={6} className="page-sub">
                      No drinks yet — add one above (or run migration 040 for the seed menu).
                    </td>
                  </tr>
                )}
                {sorted.map((drink) => {
                  const draft = priceDrafts[drink.id] ?? '';
                  const current = drink.price_peso == null ? '' : String(drink.price_peso);
                  const priceDirty = draft !== current;
                  return (
                    <tr key={drink.id}>
                      <td>
                        <strong>{drink.name}</strong>
                        <div className="page-sub" style={{ margin: 0 }}>
                          {drink.slug}
                          {drink.badge ? ` · ${drink.badge}` : ''}
                        </div>
                      </td>
                      <td>{drink.kind}</td>
                      <td style={{ minWidth: 140 }}>
                        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                          <input
                            type="number"
                            min="0"
                            step="1"
                            value={draft}
                            placeholder="—"
                            style={{ width: 88, marginBottom: 0 }}
                            onChange={(e) =>
                              setPriceDrafts((prev) => ({
                                ...prev,
                                [drink.id]: e.target.value,
                              }))
                            }
                          />
                          <button
                            type="button"
                            className="btn btn-secondary btn-sm"
                            disabled={!priceDirty || busyId === drink.id}
                            onClick={() => savePrice(drink)}
                          >
                            Set
                          </button>
                        </div>
                        <div className="page-sub" style={{ margin: '4px 0 0' }}>
                          Now: {priceLabel(drink.price_peso)}
                        </div>
                      </td>
                      <td>{minutesLabel(drink.time_cost_seconds)}</td>
                      <td>
                        <span className={`badge ${drink.active ? 'badge-green' : ''}`}>
                          {drink.active ? 'offered' : 'hidden'}
                        </span>
                      </td>
                      <td style={{ whiteSpace: 'nowrap' }}>
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          onClick={() => startEdit(drink)}
                        >
                          Edit
                        </button>{' '}
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          disabled={busyId === drink.id}
                          onClick={() => toggleActive(drink)}
                        >
                          {drink.active ? 'Hide' : 'Offer'}
                        </button>{' '}
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          disabled={busyId === drink.id}
                          onClick={() => removeDrink(drink)}
                          style={{ color: 'var(--red)' }}
                        >
                          Remove
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
