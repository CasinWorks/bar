/** Cash desk bill denominations — must match server timePricing.js */
export const CASH_PACKAGES = [
  { peso: 1000, minutes: 60, label: '1 hour' },
  { peso: 2000, minutes: 120, label: '2 hours' },
  { peso: 3000, minutes: 180, label: '3 hours' },
  { peso: 5000, minutes: 300, label: '5 hours' },
  { peso: 10000, minutes: 600, label: '10 hours' },
];

export function packageForPeso(peso) {
  return CASH_PACKAGES.find((p) => p.peso === peso);
}

export function previewLoad(amountPeso, billCount = 1, paymentMethod = 'cash') {
  const pkg = packageForPeso(Number(amountPeso));
  if (!pkg) return null;
  const count = Math.max(1, Number(billCount) || 1);
  return {
    totalPeso: paymentMethod === 'complimentary' ? 0 : pkg.peso * count,
    totalMinutes: pkg.minutes * count,
    label: pkg.label,
  };
}
