/**
 * Fallback entry packages when `time_packages` is empty/unreachable.
 * Canonical source of truth is Supabase `time_packages` (migration 020/030).
 */
export const ENTRY_PACKAGES = [
  {
    slug: 'quick-escape',
    name: 'Quick Escape',
    peso: 699,
    minutes: 90,
    drinks: 2,
    target: 'After-work crowd',
    label: '90 min · 2 drinks',
  },
  {
    slug: 'standard-night',
    name: 'Standard Night',
    peso: 999,
    minutes: 180,
    drinks: 4,
    target: 'Most guests',
    label: '180 min · 4 drinks',
    popular: true,
  },
  {
    slug: 'after-hours',
    name: 'After Hours',
    peso: 1299,
    minutes: 240,
    drinks: 5,
    target: 'Late-night / weekend',
    label: '240 min · 5 drinks',
  },
  {
    slug: 'unlimited',
    name: 'Unlimited',
    peso: 1799,
    minutes: null,
    drinks: null,
    target: 'VIP / Members',
    label: 'Until closing · drinks incl.',
  },
];

export const CASH_PACKAGES = ENTRY_PACKAGES.map((p) => ({
  peso: p.peso,
  minutes: p.minutes ?? 480,
  label: p.name,
  slug: p.slug,
  drinks: p.drinks,
}));

export const ALLOWED_BILL_PESO = ENTRY_PACKAGES.map((p) => p.peso);

/** Normalize a DB `time_packages` row (or fallback entry) into resolveLoad shape. */
export function normalizePackage(row) {
  if (!row) return null;
  if (row.peso != null && row.minutes !== undefined) {
    return {
      slug: row.slug,
      name: row.name,
      peso: Number(row.peso),
      minutes: row.minutes == null ? null : Number(row.minutes),
      drinks: row.drinks == null ? null : Number(row.drinks),
      target: row.target ?? row.target_guest ?? null,
      popular: Boolean(row.popular),
      label: row.label,
    };
  }
  return {
    slug: row.slug,
    name: row.name,
    peso: Number(row.price_peso ?? row.peso ?? 0),
    minutes:
      row.duration_minutes == null && row.minutes === undefined
        ? null
        : Number(row.duration_minutes ?? row.minutes),
    drinks:
      row.included_drinks == null && row.drinks === undefined
        ? null
        : Number(row.included_drinks ?? row.drinks),
    target: row.target_guest ?? row.target ?? null,
    popular: Boolean(row.popular),
    label: row.label,
  };
}

export function packageForSlug(slug, catalog = ENTRY_PACKAGES) {
  return catalog.map(normalizePackage).find((p) => p?.slug === slug) ?? null;
}

export function packageForPeso(peso, catalog = ENTRY_PACKAGES) {
  return (
    catalog.map(normalizePackage).find((p) => p?.peso === Number(peso)) ?? null
  );
}

export function resolveLoad({
  packageSlug,
  amountPeso,
  billCount = 1,
  quantity,
  paymentMethod = 'cash',
  catalog = ENTRY_PACKAGES,
}) {
  const qty = Math.max(1, Math.min(10, Number(quantity ?? billCount) || 1));
  const list = (catalog?.length ? catalog : ENTRY_PACKAGES).map(normalizePackage);
  const pkg =
    packageForSlug(packageSlug, list) || packageForPeso(amountPeso, list);

  if (!pkg) {
    return {
      error:
        'Select a package: Quick Escape · Standard Night · After Hours · Unlimited',
    };
  }

  const minutesEach = pkg.minutes ?? 480;
  const totalMinutes = minutesEach * qty;
  const totalPeso = paymentMethod === 'complimentary' ? 0 : pkg.peso * qty;
  const drinks = pkg.drinks == null ? null : pkg.drinks * qty;

  return {
    pkg,
    count: qty,
    totalPeso,
    totalMinutes,
    drinks,
    seconds: totalMinutes * 60,
  };
}
