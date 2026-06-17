import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../providers/config_provider.dart';
import 'api_client.dart';

/// Результат попытки OAuth-входа.
class OAuthResult {
  final bool success; // получили JWT (вошли)
  final bool needsLinking; // соцсеть не привязана — нужен договор+пароль
  final String? message; // ошибка / подсказка
  final Map<String, dynamic>? linkData; // данные для шага привязки (apple_token и т.п.)

  const OAuthResult({
    this.success = false,
    this.needsLinking = false,
    this.message,
    this.linkData,
  });
}

/// Нативный OAuth по провайдерам. Какие включены — решает сервер (ConfigProvider).
class OAuthService {
  final ApiClient api;
  final ConfigProvider config;

  OAuthService(this.api, this.config);

  /// Точка входа: по коду провайдера запускает нужный нативный flow.
  Future<OAuthResult> signIn(String provider) async {
    try {
      switch (provider) {
        case 'google':
          return await _google();
        case 'apple':
          return await _apple();
        case 'yandex':
          return await _yandex();
        default:
          return const OAuthResult(message: 'Способ входа не поддерживается');
      }
    } catch (e) {
      return OAuthResult(message: _humanize(e));
    }
  }

  // ── Google: нативный SDK → id_token → /auth/google ──
  Future<OAuthResult> _google() async {
    final serverClientId = config.oauthValue('google', 'web_client_id');
    final iosClientId = config.oauthValue('google', 'ios_client_id');
    final gsi = GoogleSignIn(
      scopes: const ['email', 'profile'],
      // serverClientId нужен, чтобы id_token имел aud = web client (его проверяет сервер).
      serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
      clientId: iosClientId.isNotEmpty ? iosClientId : null,
    );
    final account = await gsi.signIn();
    if (account == null) {
      return const OAuthResult(message: 'Вход через Google отменён');
    }
    final gAuth = await account.authentication;
    final idToken = gAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      return const OAuthResult(message: 'Google не вернул токен');
    }
    return _sendToken('/auth/google', {'id_token': idToken},
        link: {'provider': 'google', 'id_token': idToken});
  }

  // ── Apple: нативный flow → identity_token → /auth/apple ──
  Future<OAuthResult> _apple() async {
    final cred = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final identityToken = cred.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      return const OAuthResult(message: 'Apple не вернул токен');
    }
    final name = [cred.givenName, cred.familyName]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    final resp = await api.postPublic('/auth/apple', {
      'identity_token': identityToken,
      if (name.isNotEmpty) 'user_name': name,
    });
    if (resp['access'] != null) {
      return const OAuthResult(success: true);
    }
    if (resp['needs_linking'] == true) {
      // сервер вернул apple_token для шага привязки
      return OAuthResult(needsLinking: true, linkData: {
        'provider': 'apple',
        'apple_token': resp['apple_token'],
      });
    }
    return OAuthResult(message: resp['detail']?.toString() ?? 'Ошибка Apple');
  }

  // ── Yandex: OAuth через системный браузер (implicit) → access_token ──
  Future<OAuthResult> _yandex() async {
    final clientId = config.oauthValue('yandex', 'client_id');
    if (clientId.isEmpty) {
      return const OAuthResult(message: 'Яндекс не настроен');
    }
    final authUrl = Uri.https('oauth.yandex.ru', '/authorize', {
      'response_type': 'token',
      'client_id': clientId,
      'redirect_uri': 'smitbilling://oauth',
      'force_confirm': 'yes',
    });
    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: 'smitbilling',
    );
    // implicit-flow возвращает токен во фрагменте: smitbilling://oauth#access_token=...
    final token = _extractFragmentParam(result, 'access_token');
    if (token == null) {
      return const OAuthResult(message: 'Яндекс не вернул токен');
    }
    return _sendToken('/auth/yandex', {'access_token': token},
        link: {'provider': 'yandex', 'access_token': token});
  }

  /// Общий обработчик ответа `/auth/{provider}`: либо JWT, либо needs_linking.
  Future<OAuthResult> _sendToken(
      String path, Map<String, dynamic> body,
      {required Map<String, dynamic> link}) async {
    final resp = await api.postPublic(path, body);
    if (resp['access'] != null) {
      return const OAuthResult(success: true);
    }
    if (resp['needs_linking'] == true) {
      return OAuthResult(needsLinking: true, linkData: link);
    }
    return OAuthResult(message: resp['detail']?.toString() ?? 'Ошибка входа');
  }

  /// Шаг привязки соцсети к договору (после needs_linking) — нужны логин+пароль.
  Future<OAuthResult> link(
      Map<String, dynamic> linkData, String login, String password) async {
    try {
      final provider = linkData['provider']?.toString() ?? '';
      Map<String, dynamic> body;
      String path;
      switch (provider) {
        case 'google':
          path = '/auth/google/link';
          body = {
            'id_token': linkData['id_token'],
            'login': login,
            'password': password,
          };
          break;
        case 'yandex':
          path = '/auth/yandex/link';
          body = {
            'access_token': linkData['access_token'],
            'login': login,
            'password': password,
          };
          break;
        case 'apple':
          path = '/auth/apple/link';
          body = {
            'apple_token': linkData['apple_token'],
            'contract': login,
            'password': password,
          };
          break;
        default:
          return const OAuthResult(message: 'Неизвестный провайдер');
      }
      final resp = await api.postPublic(path, body);
      if (resp['access'] != null) {
        return const OAuthResult(success: true);
      }
      return OAuthResult(message: resp['detail']?.toString() ?? 'Не удалось привязать');
    } catch (e) {
      return OAuthResult(message: _humanize(e));
    }
  }

  String? _extractFragmentParam(String redirect, String key) {
    try {
      final uri = Uri.parse(redirect);
      final frag = uri.fragment;
      if (frag.isEmpty) return uri.queryParameters[key];
      final params = Uri.splitQueryString(frag);
      return params[key] ?? uri.queryParameters[key];
    } catch (_) {
      return null;
    }
  }

  String _humanize(Object e) {
    if (e is ApiException) return e.message;
    final s = e.toString();
    if (s.contains('canceled') || s.contains('cancelled')) {
      return 'Вход отменён';
    }
    return 'Ошибка входа. Попробуйте позже';
  }
}
