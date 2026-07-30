import 'event_models.dart';

/// VIP / VVIP room occupancy conflicts with an active hosted-event wallet.
///
/// Hosts of a live approved event must leave VIP rooms so the shared event
/// wallet becomes the night's primary decaying pool.
abstract final class VipHostedEventConflict {
  static const bookingBlockedMessage =
      "You can't book a VIP room while hosting a live event.";

  static const autoClearedFeedMessage =
      'left VIP room — hosting a live event (back on lounge time)';

  /// True when the member is hosting an approved event that is live right now.
  static bool blocksVipBooking({required ClubEventRecord? activeHostedEvent}) =>
      activeHostedEvent != null;

  /// Whether an existing VIP occupancy should be cleared for this host.
  static bool shouldClearActiveVip({
    required ClubEventRecord? activeHostedEvent,
    required bool isInVipRoom,
  }) => blocksVipBooking(activeHostedEvent: activeHostedEvent) && isInVipRoom;
}
