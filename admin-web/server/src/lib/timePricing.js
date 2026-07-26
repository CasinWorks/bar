/** Entry packages — must match admin client + Flutter ClubPackages. */
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

export function packageForSlug(slug) {
  return ENTRY_PACKAGES.find((p) => p.slug === slug) ?? null;
}

export function packageForPeso(peso) {
  return ENTRY_PACKAGES.find((p) => p.peso === Number(peso)) ?? null;
}

export function resolveLoad({
  packageSlug,
  amountPeso,
  billCount = 1,
  quantity,
  paymentMethod = 'cash',
}) {
  const qty = Math.max(1, Math.min(10, Number(quantity ?? billCount) || 1));
  const pkg =
    packageForSlug(packageSlug) ||
    packageForPeso(amountPeso);

  if (!pkg) {
    return {
      error:
        'Select a package: Quick Escape · Standard Night · After Hours · Unlimited',
    };
  }

  const minutesEach = pkg.minutes ?? 480;
  const totalMinutes = minutesEach * qty;
  const totalPeso = paymentMethod === 'complimentary' ? 0 : pkg.peso * qty;
  const drinks =
    pkg.drinks == null ? null : pkg.drinks * qty;

  return {
    pkg,
    count: qty,
    totalPeso,
    totalMinutes,
    drinks,
    seconds: totalMinutes * 60,
  };
}
