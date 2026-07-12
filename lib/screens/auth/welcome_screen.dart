import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LatticeBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Text(
                  'THE SOCIAL CLUB & SPEAKEASY',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        letterSpacing: 4,
                        fontSize: 10,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'THE BLIND TIGER',
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                Container(
                  height: 2,
                  width: 48,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  color: AppColors.goldBrushed,
                ),
                Text(
                  "Manila's Hidden Sanctuary",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(letterSpacing: 2),
                ),
                const Spacer(flex: 3),
                Text(
                  'Time is currency.\nMake every minute count.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.5),
                ),
                Text(
                  'Members and door staff use the same sign-in.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Enable Remember me on Sign In to save your email and password.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TigerButton(
                  label: 'SIGN IN',
                  icon: Icons.login,
                  onPressed: () => context.push('/login'),
                ),
                const SizedBox(height: 12),
                TigerButton(
                  label: 'CREATE MEMBER ACCOUNT',
                  icon: Icons.person_add,
                  secondary: true,
                  onPressed: () => context.push('/signup'),
                ),
                const SizedBox(height: 24),
                Text(
                  'AGE 21+ • MEMBER PASS REQUIRED',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 9,
                        letterSpacing: 2,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
