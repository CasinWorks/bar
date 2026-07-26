import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BlindTigerWidgets: WidgetBundle {
  var body: some Widget {
    if #available(iOSApplicationExtension 18.0, *) {
      BlindTigerTimeActivity()
    }
  }
}

/// In Time neon green — timer digits only.
private let timerNeon = Color(red: 0.224, green: 1.0, blue: 0.078) // #39FF14
private let timerNeonGlow = Color(red: 0.0, green: 0.902, blue: 0.463) // #00E676
private let timerUrgent = Color(red: 1.0, green: 0.231, blue: 0.231) // #FF3B3B

@available(iOSApplicationExtension 18.0, *)
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
            Text(data.hasSocialAlert ? data.socialAlertTitle : data.status)
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(data.hasSocialAlert ? timerUrgent : .white.opacity(0.85))
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          CountdownText(data: data, size: 20)
            .frame(minWidth: 96, alignment: .trailing)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if data.hasSocialAlert {
            VStack(alignment: .leading, spacing: 2) {
              Text(data.socialAlertSender.isEmpty ? data.member : data.socialAlertSender)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
              Text(data.socialAlertBody)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)
            }
            .padding(.top, 2)
          } else {
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
        }
      } compactLeading: {
        // Apple Watch Smart Stack defaults to compact leading+trailing when
        // supplementalActivityFamilies is not used; keep these glanceable.
        Image(systemName: data.hasSocialAlert ? "bell.fill" : "clock.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(data.hasSocialAlert ? timerUrgent : timerNeon)
      } compactTrailing: {
        CountdownText(data: data, size: 13)
          .frame(minWidth: 70, maxWidth: 84, alignment: .trailing)
      } minimal: {
        Image(systemName: data.hasSocialAlert ? "bell.fill" : "clock.fill")
          .foregroundStyle(data.hasSocialAlert ? timerUrgent : timerNeon)
      }
      .keylineTint(timerNeon)
    }
    .supplementalActivityFamilies([.small])
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
    // activityFamily must be read on a View (not the Widget) — see Apple forums.
    switch activityFamily {
    case .small:
      WatchSmartStackView(data: data)
    default:
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
        Text(data.hasSocialAlert ? data.socialAlertTitle : data.status)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(data.hasSocialAlert ? timerUrgent : .white)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Text(
          data.hasSocialAlert
            ? (data.socialAlertBody.isEmpty
              ? "\(data.socialAlertSender) · \(data.branch)"
              : data.socialAlertBody)
            : "\(data.member) · \(data.branch)"
        )
          .font(.system(size: 11))
          .foregroundStyle(.white.opacity(0.65))
          .lineLimit(2)
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
        Image(systemName: data.hasSocialAlert ? "bell.fill" : "clock.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(data.hasSocialAlert ? timerUrgent : timerNeon)
        Text("BLIND TIGER")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.36))
        Spacer(minLength: 0)
        Text(data.hasSocialAlert ? data.socialAlertTitle : data.status)
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(data.hasSocialAlert ? timerUrgent : .white.opacity(0.7))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }

      CountdownText(data: data, size: 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)

      Text(data.hasSocialAlert && !data.socialAlertSender.isEmpty ? data.socialAlertSender : data.member)
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
        // System-rendered countdown — advances on Lock Screen / Island / Watch
        // without waking the app. Do NOT substitute with a static remainingLabel here.
        Text(timerInterval: data.range, countsDown: true, showsHours: true)
      } else {
        // Huge wallets only (>36h): label is accurate but refreshes only on Activity sync.
        Text(data.remainingLabel)
      }
    }
    .monospacedDigit()
    .font(.system(size: size, weight: .bold, design: .rounded))
    .foregroundStyle(color)
    .shadow(color: color.opacity(0.95), radius: 1)
    .shadow(color: color.opacity(0.55), radius: 5)
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
  let hasSocialAlert: Bool
  let socialAlertTitle: String
  let socialAlertBody: String
  let socialAlertSender: String

  init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
    let state = context.state
    let defaults = UserDefaults(suiteName: state.appGroupId) ?? sharedDefault
    let prefix = context.attributes.prefixedKey

    func string(_ stateValue: String?, _ key: String, fallback: String) -> String {
      if let stateValue, !stateValue.isEmpty { return stateValue }
      return defaults.string(forKey: prefix(key)) ?? fallback
    }

    member = string(state.memberName, "memberName", fallback: "Guest")
    branch = string(state.branch, "branch", fallback: "Club")
    status = string(state.status, "status", fallback: "INSIDE")

    // ContentState is authoritative (Watch cannot read App Group). App Group is fallback
    // for older activities that only carried appGroupId.
    let startMs: Double = {
      if state.timerStartMs > 0 { return state.timerStartMs }
      let fallback = defaults.double(forKey: prefix("timerStartMs"))
      return fallback > 0 ? fallback : Date().timeIntervalSince1970 * 1000
    }()
    let endMs: Double = {
      if state.timerEndMs > startMs { return state.timerEndMs }
      let fallback = defaults.double(forKey: prefix("timerEndMs"))
      return fallback > startMs ? fallback : startMs + 1000
    }()
    // Prefer ContentState.timerRange when dates are already coherent.
    if state.timerStartMs > 0, state.timerEndMs > state.timerStartMs {
      range = state.timerRange
    } else {
      let start = Date(timeIntervalSince1970: startMs / 1000)
      let end = Date(timeIntervalSince1970: endMs / 1000)
      range = start...max(start.addingTimeInterval(1), end)
    }

    let duration = range.upperBound.timeIntervalSince(range.lowerBound)
    let liveMax = BlindTigerLiveActivityConstants.liveCountdownMaxSeconds
    // Force live countdown for package-length ranges even if a prior huge-wallet sync
    // left useLiveCountdown=false in App Group / ContentState.
    useLiveCountdown = duration > 1 && duration <= liveMax

    urgent = state.urgent || defaults.bool(forKey: prefix("urgent"))
    remainingLabel = {
      if !state.remainingLabel.isEmpty { return state.remainingLabel }
      return defaults.string(forKey: prefix("remainingLabel")) ?? "—"
    }()
    hasSocialAlert = state.hasSocialAlert || defaults.bool(forKey: prefix("hasSocialAlert"))
    socialAlertTitle = string(state.socialAlertTitle, "socialAlertTitle", fallback: "")
    socialAlertBody = string(state.socialAlertBody, "socialAlertBody", fallback: "")
    socialAlertSender = string(state.socialAlertSender, "socialAlertSender", fallback: "")
  }
}
