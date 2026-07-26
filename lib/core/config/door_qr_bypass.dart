/// Emails that may enter without a staff door QR scan.
///
/// Prefer toggling `profiles.is_whitelisted` in admin for ongoing VIP access;
/// this list is for founders / pilot accounts that should always skip.
const kDoorQrBypassEmails = [
  'christianjoshuacasin@gmail.com',
];

bool isDoorQrBypassEmail(String? email) {
  if (email == null || email.isEmpty) return false;
  return kDoorQrBypassEmails.contains(email.trim().toLowerCase());
}

/// True when the member may skip the entry door QR handshake.
bool canSkipDoorQrScan({String? email, bool isWhitelisted = false}) {
  return isWhitelisted || isDoorQrBypassEmail(email);
}
