import ActivityKit
import Foundation

/// Must be named exactly `LiveActivitiesAppAttributes` for ActivityKit.
/// ContentState carries display fields so Apple Watch (which re-renders `.small` remotely
/// without App Group UserDefaults) still has timer/member data.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {
    var appGroupId: String
    var memberName: String?
    var branch: String?
    var status: String?
    /// Epoch milliseconds — always set on sync so Watch / Lock Screen can build a range.
    var timerStartMs: Double
    var timerEndMs: Double
    /// When false, widget shows [remainingLabel] (huge wallets only). Typical packages use
    /// `Text(timerInterval:)` which ticks without app wakes.
    var useLiveCountdown: Bool
    var urgent: Bool
    var remainingLabel: String
    var hasSocialAlert: Bool
    var socialAlertTitle: String?
    var socialAlertBody: String?
    var socialAlertSender: String?

    init(
      appGroupId: String,
      memberName: String? = nil,
      branch: String? = nil,
      status: String? = nil,
      timerStartMs: Double,
      timerEndMs: Double,
      useLiveCountdown: Bool,
      urgent: Bool = false,
      remainingLabel: String = "—",
      hasSocialAlert: Bool = false,
      socialAlertTitle: String? = nil,
      socialAlertBody: String? = nil,
      socialAlertSender: String? = nil
    ) {
      self.appGroupId = appGroupId
      self.memberName = memberName
      self.branch = branch
      self.status = status
      self.timerStartMs = timerStartMs
      self.timerEndMs = timerEndMs
      self.useLiveCountdown = useLiveCountdown
      self.urgent = urgent
      self.remainingLabel = remainingLabel
      self.hasSocialAlert = hasSocialAlert
      self.socialAlertTitle = socialAlertTitle
      self.socialAlertBody = socialAlertBody
      self.socialAlertSender = socialAlertSender
    }

    /// Closed range for `Text(timerInterval:countsDown:)` — system-rendered, no app wakes.
    var timerRange: ClosedRange<Date> {
      let start = Date(timeIntervalSince1970: timerStartMs / 1000)
      let end = Date(timeIntervalSince1970: timerEndMs / 1000)
      return start...max(start.addingTimeInterval(1), end)
    }
  }

  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    "\(id)_\(key)"
  }
}

enum BlindTigerLiveActivityConstants {
  static let appGroupId = "group.com.intime.inTimeBartender"
  static let activityCustomId = "blind-tiger-time"
  /// Matches Dart `TimeLiveActivityService.liveCountdownMaxSeconds`.
  static let liveCountdownMaxSeconds: TimeInterval = 36 * 3600
}

let sharedDefault =
  UserDefaults(suiteName: BlindTigerLiveActivityConstants.appGroupId) ?? UserDefaults.standard
