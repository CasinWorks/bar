import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../providers/app_state.dart';
import '../../services/auth_service.dart';

/// Ceremonial multi-step membership registration.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  static const _stepCount = 4;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _page = PageController();

  late final AnimationController _pulse;

  int _step = 0;
  DateTime? _birthdate;
  bool _acceptedLegal = false;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _page.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _goTo(int step) async {
    HapticFeedback.selectionClick();
    setState(() {
      _step = step;
      _error = null;
    });
    await _page.animateToPage(
      step,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'Confirm you are 21+',
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  int get _age {
    if (_birthdate == null) return 0;
    final now = DateTime.now();
    var age = now.year - _birthdate!.year;
    if (now.month < _birthdate!.month ||
        (now.month == _birthdate!.month && now.day < _birthdate!.day)) {
      age--;
    }
    return age;
  }

  bool get _ofAge => _age >= 21;

  Future<void> _nextFromIdentity() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Tell us the name on your pass.');
      return;
    }
    await _goTo(1);
  }

  Future<void> _nextFromAge() async {
    if (_birthdate == null) {
      setState(() => _error = 'Birthdate required for the velvet door.');
      return;
    }
    if (!_ofAge) {
      setState(() => _error = 'Members must be 21 or older.');
      return;
    }
    await _goTo(2);
  }

  Future<void> _nextFromCredentials() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a real email — we will verify it.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password needs at least 6 characters.');
      return;
    }
    await _goTo(3);
  }

  Future<void> _submit() async {
    if (!_acceptedLegal) {
      setState(() => _error = 'Accept Privacy & Terms to continue.');
      return;
    }
    if (_birthdate == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await context.read<AppState>().signUp(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            birthdate: _birthdate!,
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();

      if (result.needsEmailVerification) {
        context.go(
          '/verify-email?email=${Uri.encodeComponent(result.email)}&name=${Uri.encodeComponent(result.name)}',
        );
        return;
      }

      context.go('/member-tutorial');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error = 'Sign up failed. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: LatticeBackground(
        animate: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _loading
                          ? null
                          : () {
                              if (_step > 0) {
                                _goTo(_step - 1);
                              } else {
                                context.pop();
                              }
                            },
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.goldBrushed,
                    ),
                    Expanded(
                      child: Text(
                        'MEMBERSHIP',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          color: AppColors.goldBright,
                        ),
                      ),
                    ),
                    Text(
                      '${(_step + 1).toString().padLeft(2, '0')} / 0$_stepCount',
                      style: GoogleFonts.shareTechMono(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: _StepRail(step: _step, count: _stepCount, pulse: _pulse),
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _IdentityStep(
                      name: _name,
                      error: _error,
                      onContinue: _nextFromIdentity,
                    ),
                    _AgeStep(
                      birthdate: _birthdate,
                      age: _age,
                      ofAge: _ofAge,
                      error: _error,
                      onPick: _pickBirthdate,
                      onContinue: _nextFromAge,
                    ),
                    _CredentialsStep(
                      email: _email,
                      password: _password,
                      obscure: _obscure,
                      error: _error,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onContinue: _nextFromCredentials,
                    ),
                    _SealStep(
                      name: _name.text.trim(),
                      email: _email.text.trim(),
                      accepted: _acceptedLegal,
                      loading: _loading,
                      error: _error,
                      onAccepted: (v) =>
                          setState(() => _acceptedLegal = v ?? false),
                      onPrivacy: () => context.push('/privacy'),
                      onTerms: () => context.push('/terms'),
                      onSubmit: _submit,
                    ),
                  ],
                ),
              ),
              SizedBox(height: bottom > 0 ? 4 : 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({
    required this.step,
    required this.count,
    required this.pulse,
  });

  final int step;
  final int count;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, _) {
        return Row(
          children: List.generate(count, (i) {
            final done = i < step;
            final active = i == step;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: done || active
                      ? AppColors.goldBright.withValues(
                          alpha: active ? 0.7 + pulse.value * 0.3 : 1,
                        )
                      : AppColors.goldBrushed.withValues(alpha: 0.2),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _StepChrome extends StatelessWidget {
  const _StepChrome({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.ctaLabel,
    required this.onContinue,
    this.error,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final String ctaLabel;
  final VoidCallback onContinue;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
              color: AppColors.goldBrushed,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.cinzel(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(child: SingleChildScrollView(child: child)),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.dangerRed,
              ),
            ),
            const SizedBox(height: 8),
          ],
          TigerButton(label: ctaLabel, onPressed: onContinue),
        ],
      ),
    );
  }
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.name,
    required this.onContinue,
    this.error,
  });

  final TextEditingController name;
  final VoidCallback onContinue;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return _StepChrome(
      eyebrow: 'STEP 01 · IDENTITY',
      title: 'Who walks\nthrough the door?',
      subtitle: 'Your name appears on the guest pass and Who’s Inside.',
      error: error,
      ctaLabel: 'CONTINUE',
      onContinue: onContinue,
      child: TextField(
        controller: name,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onContinue(),
        style: GoogleFonts.cinzel(fontSize: 20, color: AppColors.textLight),
        decoration: InputDecoration(
          labelText: 'Full name',
          prefixIcon: const Icon(Icons.person_outline),
          hintText: 'e.g. Christian',
          hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _AgeStep extends StatelessWidget {
  const _AgeStep({
    required this.birthdate,
    required this.age,
    required this.ofAge,
    required this.onPick,
    required this.onContinue,
    this.error,
  });

  final DateTime? birthdate;
  final int age;
  final bool ofAge;
  final VoidCallback onPick;
  final VoidCallback onContinue;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return _StepChrome(
      eyebrow: 'STEP 02 · THE DOOR',
      title: 'Prove the night\nis yours.',
      subtitle: 'Must be 21+. ID is still checked at the club.',
      error: error,
      ctaLabel: ofAge ? 'I’M OF AGE' : 'CONTINUE',
      onContinue: onContinue,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.goldBrushed.withValues(alpha: 0.35),
                  ),
                  color: const Color(0xEE120A00),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cake_outlined,
                      color: AppColors.goldBright,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      birthdate == null
                          ? 'Tap to select birthdate'
                          : '${birthdate!.month}/${birthdate!.day}/${birthdate!.year}',
                      style: GoogleFonts.cinzel(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                      ),
                    ),
                    if (birthdate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        ofAge ? 'Age $age · welcome' : 'Age $age · too young',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ofAge
                              ? AppColors.timerNeon
                              : AppColors.dangerRed,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialsStep extends StatelessWidget {
  const _CredentialsStep({
    required this.email,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.onContinue,
    this.error,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onContinue;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return _StepChrome(
      eyebrow: 'STEP 03 · KEYS',
      title: 'Your private\naccess.',
      subtitle:
          'We email a verification link before your pass unlocks. Use an inbox you can open tonight.',
      error: error,
      ctaLabel: 'CONTINUE',
      onContinue: onContinue,
      child: Column(
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: password,
            obscureText: obscure,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onContinue(),
            decoration: InputDecoration(
              labelText: 'Password (min 6)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SealStep extends StatelessWidget {
  const _SealStep({
    required this.name,
    required this.email,
    required this.accepted,
    required this.loading,
    required this.onAccepted,
    required this.onPrivacy,
    required this.onTerms,
    required this.onSubmit,
    this.error,
  });

  final String name;
  final String email;
  final bool accepted;
  final bool loading;
  final ValueChanged<bool?> onAccepted;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onSubmit;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP 04 · SEAL',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
              color: AppColors.goldBrushed,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Seal your\nmembership.',
            style: GoogleFonts.cinzel(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'One more tap. Then check your email for the key.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.goldBrushed.withValues(alpha: 0.4),
              ),
              gradient: RadialGradient(
                center: const Alignment(0, -0.9),
                radius: 1.2,
                colors: [
                  AppColors.goldBrushed.withValues(alpha: 0.14),
                  const Color(0xF50C0600),
                ],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.goldBright),
                    color: AppColors.goldBrushed.withValues(alpha: 0.1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '虎',
                    style: GoogleFonts.cinzel(
                      fontSize: 28,
                      color: AppColors.goldBright,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  name.isEmpty ? 'New member' : name,
                  style: GoogleFonts.cinzel(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'MEMBER PASS · PENDING VERIFICATION',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: AppColors.goldBrushed,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (error != null) ...[
            Text(
              error!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.dangerRed,
              ),
            ),
            const SizedBox(height: 8),
          ],
          CheckboxListTile(
            value: accepted,
            onChanged: loading ? null : onAccepted,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.goldBrushed,
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'I agree to the ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onPrivacy,
                  child: Text(
                    'Privacy Policy',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
                Text(' and ', style: Theme.of(context).textTheme.bodySmall),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onTerms,
                  child: Text(
                    'Terms of Use',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TigerButton(
            label: 'SEAL & SEND KEY',
            isLoading: loading,
            onPressed: accepted && !loading ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}
