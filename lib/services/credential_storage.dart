import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedCredentials {
  const SavedCredentials({
    required this.email,
    required this.password,
    required this.remember,
  });

  final String email;
  final String password;
  final bool remember;
}

/// Persists login email/password when the member opts in to Remember me.
class CredentialStorage {
  static const _rememberKey = 'remember_credentials';
  static const _emailKey = 'remembered_email';
  static const _passwordKey = 'remembered_password';

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<SavedCredentials?> load() async {
    final remember = await _storage.read(key: _rememberKey);
    if (remember != 'true') return null;

    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || password == null) return null;

    return SavedCredentials(email: email, password: password, remember: true);
  }

  Future<void> save({required String email, required String password}) async {
    await _storage.write(key: _rememberKey, value: 'true');
    await _storage.write(key: _emailKey, value: email.trim().toLowerCase());
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _rememberKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }
}
