/// Founder / operator emails that may use both mobile + admin web.
const kSuperAdminEmails = ['christianjoshuacasin@gmail.com'];

bool isSuperAdminEmail(String? email) {
  if (email == null || email.isEmpty) return false;
  return kSuperAdminEmails.contains(email.trim().toLowerCase());
}
