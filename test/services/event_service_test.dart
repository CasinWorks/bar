import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/services/event_service.dart';

void main() {
  group('EventService.friendlyError', () {
    final service = EventService();

    test('maps event invite and wallet backend errors', () {
      expect(
        service.friendlyError(
          Exception('Invite email does not match this account.'),
        ),
        'Sign in with the invited email to accept this invite.',
      );
      expect(
        service.friendlyError(Exception('Event wallet needs more time.')),
        'The event wallet is out of time. Ask the host to extend it.',
      );
      expect(
        service.friendlyError(Exception('Event is not approved yet.')),
        'This invite is pending admin approval.',
      );
    });

    test('strips Exception prefix for unmapped messages', () {
      expect(
        service.friendlyError(Exception('Invite token not found.')),
        'Invite token not found.',
      );
    });
  });
}
