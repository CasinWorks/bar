import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/services/deep_link_service.dart';

void main() {
  group('DeepLinkService.mapInviteLocation', () {
    test('normalizes custom scheme token links', () {
      final location = DeepLinkService.mapInviteLocation(
        Uri.parse('blindtiger://event-invite?token=tok_123'),
      );

      expect(location, '/event-invite?token=tok_123');
    });

    test('normalizes custom scheme code links to uppercase', () {
      final location = DeepLinkService.mapInviteLocation(
        Uri.parse('blindtiger:///event-invite?code=vip-007'),
      );

      expect(location, '/event-invite?code=VIP-007');
    });

    test('keeps token and code from https invite links', () {
      final location = DeepLinkService.mapInviteLocation(
        Uri.parse(
          'https://blind-tiger-admin.vercel.app/event-invite?token=tok_123&code=vip-007',
        ),
      );

      expect(location, '/event-invite?token=tok_123&code=VIP-007');
    });

    test('trims token, uppercases code, and drops blank params', () {
      final location = DeepLinkService.mapInviteLocation(
        Uri.parse(
          'blindtiger:///event-invite/?token=%20tok_123%20&code=%20vip-007%20&unused=1',
        ),
      );

      expect(location, '/event-invite?token=tok_123&code=VIP-007');
    });

    test('keeps valid code when token is blank', () {
      final location = DeepLinkService.mapInviteLocation(
        Uri.parse('blindtiger://event-invite?token=%20%20&code=vip-007'),
      );

      expect(location, '/event-invite?code=VIP-007');
    });

    test('ignores non invite routes', () {
      final location = DeepLinkService.mapInviteLocation(
        Uri.parse('blindtiger://pricing?token=tok_123'),
      );

      expect(location, isNull);
    });

    test('ignores invite links with no token or code', () {
      final location = DeepLinkService.mapInviteLocation(
        Uri.parse('blindtiger://event-invite'),
      );

      expect(location, isNull);
    });
  });
}
