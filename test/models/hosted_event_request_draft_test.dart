import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/models/event_models.dart';

void main() {
  group('HostedEventRequestDraft validation', () {
    HostedEventRequestDraft buildDraft({
      DateTime? startsAt,
      DateTime? endsAt,
      int expectedPax = HostedEventRequestDraft.minimumPax,
      int walletMinutes = HostedEventRequestDraft.minimumWalletMinutes,
    }) {
      final start =
          startsAt ??
          DateTime.now().add(
            HostedEventRequestDraft.minimumLeadTime + const Duration(hours: 2),
          );
      return HostedEventRequestDraft(
        title: 'Sunset Session',
        branch: 'BGC',
        eventType: ClubEventType.privateSocial,
        startsAt: start,
        endsAt: endsAt ?? start.add(const Duration(hours: 4)),
        expectedPax: expectedPax,
        walletMinutes: walletMinutes,
      );
    }

    test('accepts requests at or beyond the 7-day lead time', () {
      final draft = buildDraft();

      expect(draft.hasMinimumLeadTime, isTrue);
    });

    test('rejects requests under the 7-day lead time', () {
      final draft = buildDraft(
        startsAt: DateTime.now().add(
          HostedEventRequestDraft.minimumLeadTime - const Duration(minutes: 5),
        ),
      );

      expect(draft.hasMinimumLeadTime, isFalse);
    });

    test('requires the end time to be after the start time', () {
      final start = DateTime.now().add(
        HostedEventRequestDraft.minimumLeadTime + const Duration(hours: 2),
      );

      expect(
        buildDraft(startsAt: start, endsAt: start).hasValidWindow,
        isFalse,
      );
      expect(
        buildDraft(
          startsAt: start,
          endsAt: start.subtract(const Duration(minutes: 30)),
        ).hasValidWindow,
        isFalse,
      );
      expect(
        buildDraft(
          startsAt: start,
          endsAt: start.add(const Duration(minutes: 30)),
        ).hasValidWindow,
        isTrue,
      );
    });

    test('requires at least 10 expected guests', () {
      expect(
        buildDraft(
          expectedPax: HostedEventRequestDraft.minimumPax - 1,
        ).hasMinimumPax,
        isFalse,
      );
      expect(
        buildDraft(
          expectedPax: HostedEventRequestDraft.minimumPax,
        ).hasMinimumPax,
        isTrue,
      );
    });

    test('requires at least 60 wallet minutes', () {
      expect(
        buildDraft(
          walletMinutes: HostedEventRequestDraft.minimumWalletMinutes - 1,
        ).hasValidWallet,
        isFalse,
      );
      expect(
        buildDraft(
          walletMinutes: HostedEventRequestDraft.minimumWalletMinutes,
        ).hasValidWallet,
        isTrue,
      );
    });
  });
}
