/// VIP whitelist flag from admin may skip the entry door QR scan.
///
/// Founder/admin accounts always require staff QR scan regardless of whitelist
/// (see [AppState.canSkipDoorQr]).
bool canSkipDoorQrScan({bool isWhitelisted = false}) {
  return isWhitelisted;
}
