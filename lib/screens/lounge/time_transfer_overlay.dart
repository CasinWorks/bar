import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

/// NFC-feel transfer: minutes count down on sender and fly into receiver.
class TimeTransferOverlay extends StatefulWidget {
  const TimeTransferOverlay({
    super.key,
    required this.minutes,
    required this.fromLabel,
    required this.toLabel,
    required this.onFinished,
    this.title = 'NFC TIP · PASS THE GLASS',
  });

  final int minutes;
  final String fromLabel;
  final String toLabel;
  final VoidCallback onFinished;
  final String title;

  @override
  State<TimeTransferOverlay> createState() => _TimeTransferOverlayState();
}

class _TimeTransferOverlayState extends State<TimeTransferOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _fly;
  late final AnimationController _count;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _flyProgress;
  late final Animation<double> _countT;

  int _displayedFrom = 0;
  int _displayedTo = 0;

  @override
  void initState() {
    super.initState();
    _displayedFrom = widget.minutes;
    _displayedTo = 0;

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween(
      begin: 0.85,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _flyProgress = CurvedAnimation(parent: _fly, curve: Curves.easeInOutCubic);

    _count = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _countT = CurvedAnimation(parent: _count, curve: Curves.easeOutCubic);
    _count.addListener(() {
      final t = _countT.value;
      setState(() {
        _displayedFrom = (widget.minutes * (1 - t)).round();
        _displayedTo = (widget.minutes * t).round();
      });
    });

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _fly.forward();
    await _count.forward();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _fly.dispose();
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Material(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _fly, _count]),
          builder: (context, _) {
            return Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          letterSpacing: 2,
                          color: AppColors.goldBright,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Node(
                            label: widget.fromLabel,
                            minutes: _displayedFrom,
                            accent: AppColors.tigerOrange,
                            scale: _pulseAnim.value,
                          ),
                          SizedBox(
                            width: 72,
                            child: Icon(
                              Icons.arrow_forward,
                              color: AppColors.goldBrushed.withValues(
                                alpha: 0.4 + 0.6 * _flyProgress.value,
                              ),
                              size: 28,
                            ),
                          ),
                          _Node(
                            label: widget.toLabel,
                            minutes: _displayedTo,
                            accent: AppColors.successGreen,
                            scale: 0.9 + 0.2 * _flyProgress.value,
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      Text(
                        _count.isCompleted
                            ? 'TRANSFER COMPLETE'
                            : 'TRANSFERRING MINUTES…',
                        style: TextStyle(
                          color: _count.isCompleted
                              ? AppColors.successGreen
                              : AppColors.goldBright,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ...List.generate(6, (i) {
                  final stagger = (i / 6);
                  final t = ((_flyProgress.value - stagger * 0.35).clamp(
                    0.0,
                    1.0,
                  ));
                  if (t <= 0) return const SizedBox.shrink();
                  final start = Offset(size.width * 0.22, size.height * 0.42);
                  final end = Offset(size.width * 0.78, size.height * 0.42);
                  final bend = math.sin(t * math.pi) * -80;
                  final pos = Offset(
                    start.dx + (end.dx - start.dx) * t,
                    start.dy + (end.dy - start.dy) * t + bend,
                  );
                  return Positioned(
                    left: pos.dx - 18,
                    top: pos.dy - 12,
                    child: Opacity(
                      opacity: (1 - (t - 0.7).clamp(0.0, 1.0) / 0.3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.goldBrushed.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldBright.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Text(
                          '+${(widget.minutes / 6).ceil()}m',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({
    required this.label,
    required this.minutes,
    required this.accent,
    required this.scale,
  });

  final String label;
  final int minutes;
  final Color accent;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 3),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 24,
                ),
              ],
              gradient: const LinearGradient(
                colors: [Color(0xFF1C0F00), Color(0xFF050000)],
              ),
            ),
            child: Text(
              '${minutes}m',
              style: GoogleFonts.shareTechMono(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: accent,
                shadows: AppColors.timerGlow(accent, intensity: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
