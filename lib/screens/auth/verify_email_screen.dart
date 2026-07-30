import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../providers/app_state.dart';
import '../../services/auth_service.dart';

/// Waiting room after signup while Supabase email confirmation is pending.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, this.name = ''});

  final String email;
  final String name;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _resending = false;
  String? _message;
  String? _error;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 45]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
      _message = null;
    });
    try {
      await context.read<AppState>().resendSignupConfirmation(widget.email);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _message = 'Fresh key sent — check inbox and spam.');
      _startCooldown();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not resend. Try again shortly.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.name.trim().isEmpty
        ? 'Member'
        : widget.name.trim();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: LatticeBackground(
        animate: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.goldBrushed,
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) {
                    return Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.goldBright.withValues(
                            alpha: 0.55 + _pulse.value * 0.35,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.goldBrushed.withValues(
                              alpha: 0.25 + _pulse.value * 0.25,
                            ),
                            blurRadius: 28,
                          ),
                        ],
                        color: const Color(0xEE120A00),
                      ),
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 42,
                    color: AppColors.goldBright,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'CHECK YOUR MAIL',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.6,
                    color: AppColors.goldBrushed,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your key is\nin the envelope.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$displayName — we sent a verification link to',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldBright,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Open the email → tap Confirm → come back and sign in.\n'
                  'Check spam if it is quiet for a minute.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFFC4B8A8),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.timerNeon,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.dangerRed,
                    ),
                  ),
                ],
                const Spacer(),
                TigerButton(
                  label: 'I VERIFIED — SIGN IN',
                  icon: Icons.login_rounded,
                  onPressed: () => context.go('/login'),
                ),
                const SizedBox(height: 10),
                TigerButton(
                  label: _cooldown > 0
                      ? 'RESEND IN ${_cooldown}s'
                      : 'RESEND EMAIL',
                  secondary: true,
                  isLoading: _resending,
                  onPressed: _cooldown > 0 || _resending ? null : _resend,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
