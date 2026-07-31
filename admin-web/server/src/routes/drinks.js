import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin } from '../middleware/auth.js';

const router = Router();

const DRINK_COLUMNS =
  'id, slug, name, kind, time_cost_seconds, price_peso, category, description, flavor, abv, badge, ingredients, bartender_quote, image_color_start, image_color_end, active, sort_order, created_at, updated_at';

function slugify(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
}

function parseOptionalInt(value, { allowNull = true } = {}) {
  if (value === undefined) return { skip: true };
  if (value === null || value === '') {
    return allowNull ? { value: null } : { error: 'Value cannot be empty.' };
  }
  const n = Number(value);
  if (!Number.isFinite(n) || !Number.isInteger(n)) {
    return { error: 'Must be a whole number.' };
  }
  return { value: n };
}

function validateDrinkInput(body, { partial = false } = {}) {
  const errors = [];
  const patch = {};

  if (!partial || body.slug !== undefined) {
    const slug = slugify(body.slug ?? body.name);
    if (!slug) errors.push('Slug is required.');
    else patch.slug = slug;
  }

  if (!partial || body.name !== undefined) {
    const name = String(body.name || '').trim();
    if (!name) errors.push('Name is required.');
    else patch.name = name;
  }

  if (!partial || body.kind !== undefined) {
    const kind = String(body.kind || '').trim().toLowerCase();
    if (!['standard', 'premium'].includes(kind)) {
      errors.push('Kind must be standard or premium.');
    } else {
      patch.kind = kind;
    }
  }

  if (!partial || body.timeCostSeconds !== undefined || body.time_cost_seconds !== undefined) {
    const raw = body.timeCostSeconds ?? body.time_cost_seconds;
    const parsed = parseOptionalInt(raw, { allowNull: false });
    if (parsed.skip && !partial) patch.time_cost_seconds = 0;
    else if (parsed.error) errors.push(`Time cost: ${parsed.error}`);
    else if (!parsed.skip) {
      if (parsed.value < 0) errors.push('Time cost must be >= 0.');
      else patch.time_cost_seconds = parsed.value;
    }
  }

  if (!partial || body.pricePeso !== undefined || body.price_peso !== undefined) {
    const raw = body.pricePeso ?? body.price_peso;
    const parsed = parseOptionalInt(raw, { allowNull: true });
    if (parsed.error) errors.push(`Price: ${parsed.error}`);
    else if (!parsed.skip) {
      if (parsed.value != null && parsed.value < 0) errors.push('Price must be >= 0.');
      else patch.price_peso = parsed.value;
    }
  }

  if (!partial || body.category !== undefined) {
    const category = String(body.category || 'spirits').trim().toLowerCase() || 'spirits';
    patch.category = category;
  }

  for (const [key, col] of [
    ['description', 'description'],
    ['flavor', 'flavor'],
    ['abv', 'abv'],
    ['bartenderQuote', 'bartender_quote'],
    ['bartender_quote', 'bartender_quote'],
  ]) {
    if (!partial || body[key] !== undefined) {
      if (body[key] !== undefined) {
        patch[col] = String(body[key] ?? '').trim();
      }
    }
  }

  if (!partial || body.badge !== undefined) {
    if (body.badge !== undefined) {
      patch.badge = body.badge == null || body.badge === '' ? null : String(body.badge).trim();
    }
  }

  if (!partial || body.ingredients !== undefined) {
    if (body.ingredients !== undefined) {
      if (Array.isArray(body.ingredients)) {
        patch.ingredients = body.ingredients.map((s) => String(s).trim()).filter(Boolean);
      } else if (typeof body.ingredients === 'string') {
        patch.ingredients = body.ingredients
          .split(/\n|,/)
          .map((s) => s.trim())
          .filter(Boolean);
      } else {
        patch.ingredients = [];
      }
    }
  }

  if (!partial || body.active !== undefined) {
    if (body.active !== undefined) patch.active = Boolean(body.active);
  }

  if (!partial || body.sortOrder !== undefined || body.sort_order !== undefined) {
    const raw = body.sortOrder ?? body.sort_order;
    const parsed = parseOptionalInt(raw, { allowNull: false });
    if (parsed.skip && !partial) patch.sort_order = 0;
    else if (parsed.error) errors.push(`Sort order: ${parsed.error}`);
    else if (!parsed.skip) {
      if (parsed.value < 0) errors.push('Sort order must be >= 0.');
      else patch.sort_order = parsed.value;
    }
  }

  return { errors, patch };
}

router.get('/', requireAdmin, async (_req, res) => {
  const { data, error } = await supabaseAdmin
    .from('drink_catalog')
    .select(DRINK_COLUMNS)
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true });

  if (error) return res.status(500).json({ error: error.message });
  res.json({ drinks: data ?? [] });
});

router.post('/', requireAdmin, async (req, res) => {
  const { errors, patch } = validateDrinkInput(req.body, { partial: false });
  if (errors.length) return res.status(400).json({ error: errors.join(' ') });

  if (patch.sort_order === undefined) {
    const { data: maxRow } = await supabaseAdmin
      .from('drink_catalog')
      .select('sort_order')
      .order('sort_order', { ascending: false })
      .limit(1)
      .maybeSingle();
    patch.sort_order = (maxRow?.sort_order ?? 0) + 1;
  }
  if (patch.active === undefined) patch.active = true;
  if (patch.kind === undefined) patch.kind = 'premium';
  if (patch.time_cost_seconds === undefined) patch.time_cost_seconds = 0;
  if (patch.ingredients === undefined) patch.ingredients = [];

  const { data, error } = await supabaseAdmin
    .from('drink_catalog')
    .insert(patch)
    .select(DRINK_COLUMNS)
    .single();

  if (error) {
    if (error.code === '23505') {
      return res.status(400).json({ error: 'A drink with that slug already exists.' });
    }
    return res.status(500).json({ error: error.message });
  }
  res.status(201).json({ drink: data });
});

router.patch('/:id', requireAdmin, async (req, res) => {
  const { errors, patch } = validateDrinkInput(req.body, { partial: true });
  if (errors.length) return res.status(400).json({ error: errors.join(' ') });
  if (!Object.keys(patch).length) {
    return res.status(400).json({ error: 'No changes provided.' });
  }

  // Slug is stable once created.
  delete patch.slug;

  const { data, error } = await supabaseAdmin
    .from('drink_catalog')
    .update(patch)
    .eq('id', req.params.id)
    .select(DRINK_COLUMNS)
    .maybeSingle();

  if (error) return res.status(500).json({ error: error.message });
  if (!data) return res.status(404).json({ error: 'Drink not found.' });
  res.json({ drink: data });
});

router.delete('/:id', requireAdmin, async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('drink_catalog')
    .delete()
    .eq('id', req.params.id)
    .select('id, slug, name')
    .maybeSingle();

  if (error) return res.status(500).json({ error: error.message });
  if (!data) return res.status(404).json({ error: 'Drink not found.' });
  res.json({ deleted: data });
});

export default router;
