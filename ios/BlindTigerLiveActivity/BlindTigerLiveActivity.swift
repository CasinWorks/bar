import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BlindTigerWidgets: WidgetBundle {
  var body: some Widget {
    if #available(iOS 16.1, *) {
      BlindTigerTimeActivity()
    }
  }
}

/// Must be named exactly `LiveActivitiesAppAttributes` for the live_activities plugin.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {}

  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    "\(id)_\(key)"
  }
}

let sharedDefault = UserDefaults(suiteName: "group.com.intime.inTimeBartender")!

/// In Time neon green — timer digits only.
private let timerNeon = Color(red: 0.224, green: 1.0, blue: 0.078) // #39FF14
private let timerNeonGlow = Color(red: 0.0, green: 0.902, blue: 0.463) // #00E676
private let timerUrgent = Color(red: 1.0, green: 0.231, blue: 0.231) // #FF3B3B

@available(iOSApplicationExtension 16.1, *)
struct BlindTigerTimeActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      TimeBannerView(context: context)
    } dynamicIsland: { context in
      let data = TimeActivityData(context: context)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Text("BLIND TIGER")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.36))
              .tracking(1.2)
            Text(data.status)
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(.white.opacity(0.85))
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          CountdownText(data: data, size: 20)
            .frame(minWidth: 96, alignment: .trailing)
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Text(data.member)
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(.white.opacity(0.8))
              .lineLimit(1)
            Spacer()
            Text(data.branch)
              .font(.system(size: 11, weight: .regular))
              .foregroundStyle(.white.opacity(0.55))
              .lineLimit(1)
          }
          .padding(.top, 2)
        }
      } compactLeading: {
        Image(systemName: "clock.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(timerNeon)
      } compactTrailing: {
        // Apple Watch Smart Stack defaults to compact leading+trailing.
        // Fixed 52pt was clipping HH:MM:SS — let digits scale to fit.
        CountdownText(data: data, size: 13)
          .frame(minWidth: 70, maxWidth: 84, alignment: .trailing)
      } minimal: {
        Image(systemName: "clock.fill")
          .foregroundStyle(timerNeon)
      }
      .keylineTint(timerNeon)
    }
    .blindTigerWatchFamilies()
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct TimeBannerView: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>

  var body: some View {
    let data = TimeActivityData(context: context)
    if #available(iOSApplicationExtension 18.0, *) {
      TimeBannerAdaptive(data: data)
    } else {
      PhoneLockScreenView(data: data)
    }
  }
}

@available(iOSApplicationExtension 18.0, *)
private struct TimeBannerAdaptive: View {
  let data: TimeActivityData
  @Environment(\.activityFamily) private var activityFamily

  var body: some View {
    if activityFamily == .small {
      WatchSmartStackView(data: data)
    } else {
      PhoneLockScreenView(data: data)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct PhoneLockScreenView: View {
  let data: TimeActivityData

  var body: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text("THE BLIND TIGER")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.36))
          .tracking(1.2)
        Text(data.status)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Text("\(data.member) · \(data.branch)")
          .font(.system(size: 11))
          .foregroundStyle(.white.opacity(0.65))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
      .layoutPriority(0)

      Spacer(minLength: 6)

      VStack(alignment: .trailing, spacing: 2) {
        Text("TIME LEFT")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.white.opacity(0.45))
          .tracking(0.8)
        CountdownText(data: data, size: 24)
          .frame(minWidth: 108, alignment: .trailing)
      }
      .layoutPriority(1)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .activityBackgroundTint(Color.black.opacity(0.88))
    .activitySystemActionForegroundColor(.white)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct WatchSmartStackView: View {
  let data: TimeActivityData

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 5) {
        Image(systemName: "clock.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(timerNeon)
        Text("BLIND TIGER")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.36))
        Spacer(minLength: 0)
        Text(data.status)
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(.white.opacity(0.7))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }

      // Full-width countdown — hero on Watch, no clipping frame.
      CountdownText(data: data, size: 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)

      Text(data.member)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.75))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .activityBackgroundTint(Color.black.opacity(0.92))
    .activitySystemActionForegroundColor(.white)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct CountdownText: View {
  let data: TimeActivityData
  let size: CGFloat

  private var color: Color {
    data.urgent ? timerUrgent : timerNeon
  }

  var body: some View {
    Group {
      if data.useLiveCountdown {
        Text(timerInterval: data.range, countsDown: true, showsHours: true)
      } else {
        // Large wallets (e.g. 423h) — show exact label, not a capped countdown.
        Text(data.remainingLabel)
      }
    }
    .monospacedDigit()
    .font(.system(size: size, weight: .bold, design: .rounded))
    .foregroundStyle(color)
    .shadow(color: color.opacity(0.95), radius: 1)
    .shadow(color: color.opacity(0.7), radius: 6)
    .shadow(color: color.opacity(0.35), radius: 14)
    .multilineTextAlignment(.trailing)
    .lineLimit(1)
    .minimumScaleFactor(0.5)
    .allowsTightening(true)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct TimeActivityData {
  let member: String
  let branch: String
  let status: String
  let range: ClosedRange<Date>
  let urgent: Bool
  let useLiveCountdown: Bool
  let remainingLabel: String

  init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
    let defaults = sharedDefault
    let prefix = context.attributes.prefixedKey
    member = defaults.string(forKey: prefix("memberName")) ?? "Guest"
    branch = defaults.string(forKey: prefix("branch")) ?? "Club"
    status = defaults.string(forKey: prefix("status")) ?? "INSIDE"
    let startMs = defaults.double(forKey: prefix("timerStartMs"))
    let endMs = defaults.double(forKey: prefix("timerEndMs"))
    let start = Date(timeIntervalSince1970: (startMs > 0 ? startMs : Date().timeIntervalSince1970 * 1000) / 1000)
    let end = Date(timeIntervalSince1970: (endMs > 0 ? endMs : Date().timeIntervalSince1970 * 1000) / 1000)
    range = start...max(start.addingTimeInterval(1), end)
    urgent = defaults.bool(forKey: prefix("urgent"))
    // Default true only when key missing AND duration is short — prefer label if unsure.
    if defaults.object(forKey: prefix("useLiveCountdown")) != nil {
      useLiveCountdown = defaults.bool(forKey: prefix("useLiveCountdown"))
    } else {
      useLiveCountdown = end.timeIntervalSince(start) <= (36 * 3600)
    }
    remainingLabel = defaults.string(forKey: prefix("remainingLabel")) ?? "—"
  }
}

private extension WidgetConfiguration {
  /// Opt into Apple Watch / CarPlay small family when the OS supports it.
  func blindTigerWatchFamilies() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 18.0, *) {
      return supplementalActivityFamilies([.small])
    } else {
      return self
    }
  }
}
