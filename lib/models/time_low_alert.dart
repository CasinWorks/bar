import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Guest warning when club time crosses a danger band, hour boundary, or last call.
///
/// Ladder (once per descent; re-arms when wallet climbs back above the mark):
/// | Minutes | Role                         | Tone     |
/// |--------:|------------------------------|----------|
/// |     120 | Yellow band / losing hours   | Caution  |
/// |      60 | Whole hour left              | Caution  |
/// |      30 | Red band entry               | Urgent   |
/// |      10 | Late urgency                 | Urgent   |
/// |       5 | Last call                    | Last call|
/// |       1 | Final minute                 | Last call|
///
/// Multi-threshold drops (big spend) enqueue only the most urgent newly crossed mark.
class TimeLowAlert {
  const TimeLowAlert({required this.minutesThreshold});

  /// Minute marks that trigger a once-per-descent warning.
  static const thresholds = [120, 60, 30, 10, 5, 1];

  final int minutesThreshold;

  String get id => 'time-low-$minutesThreshold';

  String get eyebrow => minutesThreshold <= 5
      ? 'LAST CALL'
      : minutesThreshold <= 30
      ? 'TIME RUNNING LOW'
      : 'TIME';

  String get title => switch (minutesThreshold) {
    120 => 'Under 2 hours left',
    60 => 'Under 1 hour left',
    30 => 'Time running low — 30 min',
    10 => '10 minutes left',
    5 => '5 minutes left',
    1 => '1 minute left',
    _ => '$minutesThreshold minutes left',
  };

  String get body => switch (minutesThreshold) {
    120 => 'Extend when you\'re ready.',
    60 => 'Your night is getting short.',
    30 => 'Extend now to stay inside.',
    10 => 'Extend or start for the door.',
    5 => 'Extend now or start winding toward the door.',
    1 => 'Final minute. Extend or head for the exit.',
    _ => 'Extend your time to keep the night going.',
  };

  /// Sound + critical accent for red-band and last-call marks (not hour cautions).
  bool get isUrgent => minutesThreshold <= 30;

  Color get accent =>
      isUrgent ? AppColors.timerCritical : AppColors.timerCaution;

  IconData get icon => minutesThreshold <= 5
      ? Icons.timer_off_rounded
      : isUrgent
      ? Icons.hourglass_bottom_rounded
      : Icons.timelapse_rounded;
}
