import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/lattice_background.dart';
import '../../providers/app_state.dart';
import '../../router/member_routes.dart';
import '../../services/auth_service.dart';
import '../../services/credential_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _credentials = CredentialStorage();
  bool _loading = false;
  bool _rememberMe = true;
  bool _loadingSaved = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await _credentials.load();
    if (!mounted) return;

    if (saved != null) {
      _email.text = saved.email;
      _password.text = saved.password;
      _rememberMe = saved.remember;
    }

    setState(() => _loadingSaved = false);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _email.text.trim();
    final password = _password.text;

    try {
      await context.read<AppState>().login(email: email, password: password);

      if (_rememberMe) {
        await _credentials.save(email: email, password: password);
      } else {
        await _credentials.clear();
      }

      if (!mounted) return;
      context.go(routeForAppState(context.read<AppState>()));
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Sign in failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Member Sign In')),
      body: LatticeBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: AppLogo(size: 72)),
                const SizedBox(height: 20),
                Text(
                  'Welcome back.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _rememberMe && _email.text.isNotEmpty
                      ? 'Your saved sign-in is ready — tap Sign In.'
                      : 'Sign in to access your pass.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                if (_loadingSaved)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2))
                else ...[
                  TextField(
                    controller: _email,
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
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _loading ? null : _login(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _rememberMe,
                    onChanged: _loading
                        ? null
                        : (value) =>
                              setState(() => _rememberMe = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.goldBrushed,
                    title: Text(
                      'Remember email & password',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                    subtitle: Text(
                      'Optional autofill — your session already stays signed in',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.dangerRed),
                  ),
                ],
                const Spacer(),
                TigerButton(
                  label: 'Sign In',
                  isLoading: _loading || _loadingSaved,
                  onPressed: _loading || _loadingSaved ? null : _login,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
