/** Entry packages — must match Flutter ClubPackages + server timePricing.js */
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
    minutes: null, // until closing
    drinks: null, // unlimited (soft cap server-side)
    target: 'VIP / Members',
    label: 'Until closing · drinks incl.',
  },
];

/** @deprecated Use ENTRY_PACKAGES — kept for older call sites during migration */
export const CASH_PACKAGES = ENTRY_PACKAGES.map((p) => ({
  peso: p.peso,
  minutes: p.minutes ?? 480,
  label: p.name,
  slug: p.slug,
  drinks: p.drinks,
}));

export function packageForSlug(slug) {
  return ENTRY_PACKAGES.find((p) => p.slug === slug) ?? null;
}

export function packageForPeso(peso) {
  return ENTRY_PACKAGES.find((p) => p.peso === Number(peso)) ?? null;
}

export function previewLoad(packageSlug, quantity = 1, paymentMethod = 'cash') {
  const pkg = packageForSlug(packageSlug) ?? packageForPeso(packageSlug);
  if (!pkg) return null;
  const count = Math.max(1, Number(quantity) || 1);
  const minutes = (pkg.minutes ?? 480) * count;
  const drinks =
    pkg.drinks == null ? null : pkg.drinks * count;
  return {
    slug: pkg.slug,
    name: pkg.name,
    totalPeso: paymentMethod === 'complimentary' ? 0 : pkg.peso * count,
    totalMinutes: minutes,
    drinks,
    label: pkg.label,
  };
}
