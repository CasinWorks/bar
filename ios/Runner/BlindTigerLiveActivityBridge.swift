import ActivityKit
import CryptoKit
import Flutter
import Foundation
import UIKit

/// Native ActivityKit bridge that embeds Live Activity display fields in ContentState.
/// Required for Apple Watch: watchOS re-renders `.small` remotely and cannot read the
/// iPhone App Group UserDefaults that the live_activities plugin relies on alone.
final class BlindTigerLiveActivityBridge: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let channelName = "com.intime.inTimeBartender/live_activity"
  private static let tokenEventChannelName = "com.intime.inTimeBartender/live_activity_tokens"

  private var tokenEventSink: FlutterEventSink?
  private var tokenTasks: [String: Task<Void, Never>] = [:]
  private var pushToStartTask: Task<Void, Never>?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = BlindTigerLiveActivityBridge()
    let method = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: method)

    let events = FlutterEventChannel(
      name: tokenEventChannelName,
      binaryMessenger: registrar.messenger()
    )
    events.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "areActivitiesEnabled":
      if #available(iOS 16.1, *) {
        result(ActivityAuthorizationInfo().areActivitiesEnabled)
      } else {
        result(false)
      }
    case "sync":
      guard #available(iOS 16.2, *) else {
        result(FlutterError(code: "UNSUPPORTED", message: "Live Activities require iOS 16.2+", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "BAD_ARGS", message: "Expected map", details: nil))
        return
      }
      Task {
        do {
          let id = try await sync(args: args)
          await MainActor.run { result(id) }
        } catch {
          await MainActor.run {
            result(FlutterError(code: "SYNC_FAILED", message: error.localizedDescription, details: nil))
          }
        }
      }
    case "endAll":
      guard #available(iOS 16.2, *) else {
        result(nil)
        return
      }
      Task {
        await endAll()
        await MainActor.run { result(nil) }
      }
    case "getAllActivityIds":
      guard #available(iOS 16.1, *) else {
        result([])
        return
      }
      result(Activity<LiveActivitiesAppAttributes>.activities.map(\.id))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    tokenEventSink = events
    if #available(iOS 17.2, *) {
      startPushToStartMonitor()
    }
    if #available(iOS 16.1, *) {
      for activity in Activity<LiveActivitiesAppAttributes>.activities {
        monitorPushToken(activity)
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    tokenEventSink = nil
    pushToStartTask?.cancel()
    pushToStartTask = nil
    tokenTasks.values.forEach { $0.cancel() }
    tokenTasks.removeAll()
    return nil
  }

  @available(iOS 16.2, *)
  private func sync(args: [String: Any]) async throws -> String {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw BridgeError.disabled
    }

    let contentState = contentState(from: args)
    let customId = attributesId()
    writeAppGroup(contentState: contentState, attributesId: customId)

    let staleMinutes = (args["staleInMinutes"] as? Int) ?? (8 * 60)
    let enableRemote = (args["enableRemoteUpdates"] as? Bool) ?? true
    let withAlert = args["withSystemAlert"] as? Bool ?? false
    let alertTitle = args["socialAlertTitle"] as? String
    let alertBody = args["socialAlertBody"] as? String

    let live = Activity<LiveActivitiesAppAttributes>.activities.filter {
      $0.activityState != .ended && $0.activityState != .dismissed
    }
    let matches = live.filter { $0.attributes.id == customId }
    let orphans = live.filter { $0.attributes.id != customId }
    for orphan in orphans {
      await orphan.end(nil, dismissalPolicy: .immediate)
    }

    let staleDate = Calendar.current.date(byAdding: .minute, value: staleMinutes, to: Date())
    let content = ActivityContent(state: contentState, staleDate: staleDate)

    if let existing = matches.first {
      var alert: AlertConfiguration?
      if withAlert, let alertTitle, !alertTitle.isEmpty {
        alert = AlertConfiguration(
          title: LocalizedStringResource(stringLiteral: alertTitle),
          body: LocalizedStringResource(stringLiteral: alertBody ?? ""),
          sound: .default
        )
      }
      await existing.update(content, alertConfiguration: alert)
      for extra in matches.dropFirst() {
        await extra.end(nil, dismissalPolicy: .immediate)
      }
      monitorPushToken(existing)
      return existing.id
    }

    let attributes = LiveActivitiesAppAttributes(id: customId)
    let activity: Activity<LiveActivitiesAppAttributes>
    do {
      activity = try Activity.request(
        attributes: attributes,
        content: content,
        pushType: enableRemote ? .token : nil
      )
    } catch {
      activity = try Activity.request(
        attributes: attributes,
        content: content,
        pushType: nil
      )
    }
    monitorPushToken(activity)
    return activity.id
  }

  @available(iOS 16.2, *)
  private func endAll() async {
    for activity in Activity<LiveActivitiesAppAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
    tokenTasks.values.forEach { $0.cancel() }
    tokenTasks.removeAll()
  }

  private func contentState(from args: [String: Any]) -> LiveActivitiesAppAttributes.ContentState {
    // Flutter MethodChannel boxes numbers as NSNumber. `as? Double` / `as? Int` often fail
    // for Int64 millisecond timestamps — always go through NSNumber first.
    func double(_ key: String) -> Double? {
      if let v = args[key] as? NSNumber { return v.doubleValue }
      if let v = args[key] as? Double { return v }
      if let v = args[key] as? Int { return Double(v) }
      if let v = args[key] as? String { return Double(v) }
      return nil
    }
    func bool(_ key: String, fallback: Bool = false) -> Bool {
      if let v = args[key] as? Bool { return v }
      if let v = args[key] as? NSNumber { return v.boolValue }
      return fallback
    }
    func string(_ key: String) -> String? {
      args[key] as? String
    }

    let nowMs = Date().timeIntervalSince1970 * 1000
    // Prefer remainingSeconds (small Int) when ms timestamps fail to decode — that was
    // collapsing the Live Activity range to ~1s so digits looked frozen / zeroed.
    let remaining = max(0, double("remainingSeconds") ?? 0)
    var startMs = double("timerStartMs") ?? 0
    var endMs = double("timerEndMs") ?? 0
    var durationSec = max(0, (endMs - startMs) / 1000)
    // Rebuild from remaining when ms missing/inverted OR when the decoded span is
    // absurdly short vs remaining (partial Int64 truncation → frozen ~1s range).
    let spanLooksBroken =
      startMs <= 0
      || endMs <= startMs
      || (remaining > 2 && durationSec < 2)
    if spanLooksBroken {
      startMs = nowMs
      endMs = nowMs + max(remaining, 1) * 1000
      durationSec = max(0, (endMs - startMs) / 1000)
    }
    // Typical packages (≤4–8h, soft-cap Unlimited ~8h) must use timerInterval.
    // Only huge demo wallets fall back to a static label (refreshes on sync only).
    let liveMax = BlindTigerLiveActivityConstants.liveCountdownMaxSeconds
    let useLive = bool("useLiveCountdown", fallback: durationSec > 0 && durationSec <= liveMax)
      && durationSec > 0
      && durationSec <= liveMax

    return LiveActivitiesAppAttributes.ContentState(
      appGroupId: BlindTigerLiveActivityConstants.appGroupId,
      memberName: string("memberName"),
      branch: string("branch"),
      status: string("status"),
      timerStartMs: startMs,
      timerEndMs: endMs,
      useLiveCountdown: useLive,
      urgent: bool("urgent", fallback: remaining > 0 && remaining <= 10 * 60),
      remainingLabel: string("remainingLabel") ?? "—",
      hasSocialAlert: bool("hasSocialAlert"),
      socialAlertTitle: string("socialAlertTitle"),
      socialAlertBody: string("socialAlertBody"),
      socialAlertSender: string("socialAlertSender")
    )
  }

  private func writeAppGroup(
    contentState: LiveActivitiesAppAttributes.ContentState,
    attributesId: UUID
  ) {
    let defaults = sharedDefault
    let p = { (key: String) in "\(attributesId)_\(key)" }
    defaults.set(contentState.memberName, forKey: p("memberName"))
    defaults.set(contentState.branch, forKey: p("branch"))
    defaults.set(contentState.status, forKey: p("status"))
    defaults.set(contentState.timerStartMs, forKey: p("timerStartMs"))
    defaults.set(contentState.timerEndMs, forKey: p("timerEndMs"))
    defaults.set(contentState.useLiveCountdown, forKey: p("useLiveCountdown"))
    defaults.set(contentState.urgent, forKey: p("urgent"))
    defaults.set(contentState.remainingLabel, forKey: p("remainingLabel"))
    defaults.set(contentState.hasSocialAlert, forKey: p("hasSocialAlert"))
    defaults.set(contentState.socialAlertTitle, forKey: p("socialAlertTitle"))
    defaults.set(contentState.socialAlertBody, forKey: p("socialAlertBody"))
    defaults.set(contentState.socialAlertSender, forKey: p("socialAlertSender"))
  }

  private func attributesId() -> UUID {
    uuid5(name: BlindTigerLiveActivityConstants.activityCustomId)
  }

  private func uuid5(
    namespace: UUID = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!,
    name: String
  ) -> UUID {
    var namespaceBytes = withUnsafeBytes(of: namespace.uuid) { Data($0) }
    namespaceBytes.append(Data(name.utf8))
    let hash = Insecure.SHA1.hash(data: namespaceBytes)
    var bytes = [UInt8](hash.prefix(16))
    bytes[6] = (bytes[6] & 0x0F) | 0x50
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    let uuid = uuid_t(
      bytes[0], bytes[1], bytes[2], bytes[3],
      bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11],
      bytes[12], bytes[13], bytes[14], bytes[15]
    )
    return UUID(uuid: uuid)
  }

  @available(iOS 16.1, *)
  private func monitorPushToken(_ activity: Activity<LiveActivitiesAppAttributes>) {
    let id = activity.id
    tokenTasks[id]?.cancel()
    tokenTasks[id] = Task {
      for await tokenData in activity.pushTokenUpdates {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        await MainActor.run {
          self.tokenEventSink?(
            [
              "kind": "live_activity",
              "token": token,
              "activityId": id,
            ] as [String: Any]
          )
        }
      }
    }
  }

  @available(iOS 17.2, *)
  private func startPushToStartMonitor() {
    pushToStartTask?.cancel()
    pushToStartTask = Task {
      for await tokenData in Activity<LiveActivitiesAppAttributes>.pushToStartTokenUpdates {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        await MainActor.run {
          self.tokenEventSink?(
            [
              "kind": "live_activity_start",
              "token": token,
            ] as [String: Any]
          )
        }
      }
    }
  }

  private enum BridgeError: LocalizedError {
    case disabled
    var errorDescription: String? {
      switch self {
      case .disabled: return "Live Activities disabled in iOS Settings"
      }
    }
  }
}
