/** Hidden from admin lists — still can sign in to the console. */
export const SUPER_ADMIN_EMAILS = ['christianjoshuacasin@gmail.com'];

export function isSuperAdminEmail(email) {
  if (!email) return false;
  return SUPER_ADMIN_EMAILS.includes(String(email).trim().toLowerCase());
}

export function withoutSuperAdmins(rows, emailKey = 'email') {
  return (rows ?? []).filter((row) => !isSuperAdminEmail(row?.[emailKey]));
}
