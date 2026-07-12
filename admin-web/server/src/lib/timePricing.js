/** Cash desk bill denominations — must match admin client. */
export const CASH_PACKAGES = [
  { peso: 1000, minutes: 60, label: '1 hour' },
  { peso: 2000, minutes: 120, label: '2 hours' },
  { peso: 3000, minutes: 180, label: '3 hours' },
  { peso: 5000, minutes: 300, label: '5 hours' },
  { peso: 10000, minutes: 600, label: '10 hours' },
];

export const ALLOWED_BILL_PESO = CASH_PACKAGES.map((p) => p.peso);

export function packageForPeso(peso) {
  return CASH_PACKAGES.find((p) => p.peso === peso) ?? null;
}

export function resolveLoad({ amountPeso, billCount = 1, paymentMethod = 'cash' }) {
  const pkg = packageForPeso(Number(amountPeso));
  if (!pkg) {
    return { error: 'Select a standard bill: ₱1,000 · ₱2,000 · ₱3,000 · ₱5,000 · ₱10,000' };
  }

  const count = Math.max(1, Math.min(20, Number(billCount) || 1));
  const totalPeso = paymentMethod === 'complimentary' ? 0 : pkg.peso * count;
  const totalMinutes = pkg.minutes * count;

  return {
    pkg,
    count,
    totalPeso,
    totalMinutes,
    seconds: totalMinutes * 60,
  };
}
