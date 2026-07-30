import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/services/time_economy_service.dart';

void main() {
  group('TimeEconomyService.decaySource', () {
    test(
      'prefers VIP room time while occupied with room seconds remaining',
      () {
        expect(
          TimeEconomyService.decaySource(
            isInVipRoom: true,
            vipRoomSeconds: 120,
            eventWalletActive: true,
            eventWalletSeconds: 3600,
            personalSeconds: 3600,
          ),
          TimeDecaySource.vipRoom,
        );
      },
    );

    test('never decays personal while active room time is available', () {
      final source = TimeEconomyService.decaySource(
        isInVipRoom: true,
        vipRoomSeconds: 1,
        eventWalletActive: false,
        eventWalletSeconds: 0,
        personalSeconds: 999,
      );
      expect(source, isNot(TimeDecaySource.personal));
      expect(source, TimeDecaySource.vipRoom);
    });

    test('event wallet pauses personal while the party is live', () {
      expect(
        TimeEconomyService.decaySource(
          isInVipRoom: false,
          vipRoomSeconds: 0,
          eventWalletActive: true,
          eventWalletSeconds: 1800,
          personalSeconds: 3600,
        ),
        TimeDecaySource.eventWallet,
      );
    });

    test('resumes personal after room time reaches zero', () {
      expect(
        TimeEconomyService.decaySource(
          isInVipRoom: true,
          vipRoomSeconds: 0,
          eventWalletActive: false,
          eventWalletSeconds: 0,
          personalSeconds: 600,
        ),
        TimeDecaySource.personal,
      );
    });

    test('resumes personal when not in a VIP room or event', () {
      expect(
        TimeEconomyService.decaySource(
          isInVipRoom: false,
          vipRoomSeconds: 300,
          eventWalletActive: false,
          eventWalletSeconds: 0,
          personalSeconds: 600,
        ),
        TimeDecaySource.personal,
      );
    });

    test('returns none when every pool is empty', () {
      expect(
        TimeEconomyService.decaySource(
          isInVipRoom: false,
          vipRoomSeconds: 0,
          eventWalletActive: true,
          eventWalletSeconds: 0,
          personalSeconds: 0,
        ),
        TimeDecaySource.none,
      );
    });
  });
}
