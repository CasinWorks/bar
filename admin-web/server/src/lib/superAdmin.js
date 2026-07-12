/** Founder / operator emails — protected from demotion & destructive edits. */
export const SUPER_ADMIN_EMAILS = ['christianjoshuacasin@gmail.com'];

export function isSuperAdminEmail(email) {
  if (!email) return false;
  return SUPER_ADMIN_EMAILS.includes(String(email).trim().toLowerCase());
}
