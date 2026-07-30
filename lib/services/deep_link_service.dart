import 'dart:async';

import 'package:app_links/app_links.dart';

class DeepLinkService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  static const inviteRoute = '/event-invite';
  static const customScheme = 'blindtiger';

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  Future<void> start({
    required void Function(String location) onInviteLink,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      final initial = await _appLinks.getInitialLink();
      final location = mapInviteLocation(initial);
      if (location != null) onInviteLink(location);
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }

    _subscription ??= _appLinks.uriLinkStream.listen(
      (uri) {
        final location = mapInviteLocation(uri);
        if (location != null) onInviteLink(location);
      },
      onError: (Object error, StackTrace stackTrace) {
        onError?.call(error, stackTrace);
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  static String? mapInviteLocation(Uri? uri) {
    if (uri == null) return null;

    final path = _normalizedPath(uri);
    if (path != inviteRoute) return null;

    final token = _normalizedParam(uri, 'token');
    final code = _normalizedParam(uri, 'code')?.toUpperCase();
    if (token == null && code == null) return null;

    final query = <String, String>{};
    if (token != null) query['token'] = token;
    if (code != null) query['code'] = code;
    return Uri(path: inviteRoute, queryParameters: query).toString();
  }

  static String? _normalizedParam(Uri uri, String key) {
    final value = uri.queryParameters[key]?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String _normalizedPath(Uri uri) {
    if (uri.scheme.toLowerCase() == customScheme && uri.host.isNotEmpty) {
      final route = '/${uri.host}${uri.path}'.replaceAll(RegExp('/+'), '/');
      return route.endsWith('/') && route.length > 1
          ? route.substring(0, route.length - 1)
          : route;
    }

    final path = uri.path.isEmpty ? '/' : uri.path;
    return path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
  }
}
