import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/core/config/door_qr_bypass.dart';
import 'package:in_time_bartender/core/config/super_admin.dart';
import 'package:in_time_bartender/models/member_user.dart';

void main() {
  group('canSkipDoorQrScan', () {
    test('returns false when not whitelisted', () {
      expect(canSkipDoorQrScan(isWhitelisted: false), isFalse);
    });

    test('returns true for whitelisted members', () {
      expect(canSkipDoorQrScan(isWhitelisted: true), isTrue);
    });
  });

  group('founder/admin entry policy', () {
    test('founder email is super admin but admin role', () {
      const email = 'christianjoshuacasin@gmail.com';
      expect(isSuperAdminEmail(email), isTrue);

      const user = MemberUser(
        id: 'founder-id',
        name: 'Founder',
        email: email,
        birthdate: null,
        role: UserRole.admin,
        isWhitelisted: true,
      );

      expect(user.isAdmin, isTrue);
      expect(user.usesMemberSurface, isTrue);
      expect(
        user.isAdmin || isSuperAdminEmail(user.email),
        isTrue,
        reason: 'founder must not auto-enter even when whitelisted',
      );
    });

    test('non-founder admin cannot use member surface bypass', () {
      const user = MemberUser(
        id: 'admin-id',
        name: 'Admin',
        email: 'ops@blindtiger.club',
        birthdate: null,
        role: UserRole.admin,
        isWhitelisted: true,
      );

      expect(user.usesMemberSurface, isFalse);
      expect(user.isAdmin, isTrue);
    });
  });
}
