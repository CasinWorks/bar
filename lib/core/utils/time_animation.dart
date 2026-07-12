/// Animation speed scales with how much time is gained or lost.
abstract final class TimeAnimation {
  static Duration durationForDelta(int deltaSeconds) {
    final abs = deltaSeconds.abs();
    if (abs == 0) return Duration.zero;
    // ~45ms per second changed; larger pours take longer to count up/down
    final ms = (500 + abs * 42).clamp(900, 4000);
    return Duration(milliseconds: ms);
  }

  static String formatClock(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String formatDelta(int deltaSeconds) {
    final sign = deltaSeconds >= 0 ? '+' : '−';
    final abs = deltaSeconds.abs();
    final h = abs ~/ 3600;
    final m = (abs % 3600) ~/ 60;
    final s = abs % 60;
    if (h > 0) return '$sign${h}h ${m}m';
    if (m > 0) return '$sign${m}m';
    return '$sign${s}s';
  }
}
