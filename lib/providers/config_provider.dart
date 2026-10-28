import 'dart:convert';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';

/// Описание одного способа входа (приходит из /mobile-api/v1/auth/methods).
class AuthProviderInfo {
  final String code; // vk | telegram | google | apple | yandex
  final String label;
  final String icon; // код иконки для маппинга
  final Color color;
  final bool native; // есть нативный mobile-endpoint (id_token)

  const AuthProviderInfo({
    required this.code,
    required this.label,
    required this.icon,
    required this.color,
    required this.native,
  });

  factory AuthProviderInfo.fromJson(Map<String, dynamic> j) {
    return AuthProviderInfo(
      code: (j['code'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      icon: (j['icon'] ?? '').toString(),
      color: _parseColor(j['color']?.toString()),
      native: j['native'] == true,
    );
  }

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF5BA89D);
    var s = hex.replaceAll('#', '').trim();
    if (s.length == 6) s = 'FF$s';
    return Color(int.tryParse(s, radix: 16) ?? 0xFF5BA89D);
  }
}

/// Слайд онбординга (настраивается на сервере: «Брендинг → Онбординг приложения»).
class OnboardingSlide {
  final String icon;
  final String title;
  final String text;
  final String imageUrl;
  const OnboardingSlide(this.icon, this.title, this.text, [this.imageUrl = '']);
}

// Стандартные слайды — пока сервер не ответил (первый запуск без сети).
const _defaultSlides = [
  OnboardingSlide('wallet', 'Баланс и оплата',
      'Баланс всегда перед глазами. Пополняйте счёт картой или по СБП за пару касаний, а если не хватает — возьмите обещанный платёж.'),
  OnboardingSlide('services', 'Все услуги в одном месте',
      'Интернет, телевидение, видеонаблюдение и гостевой Wi-Fi — смотрите, что подключено, и управляйте сами.'),
  OnboardingSlide('video', 'Видеонаблюдение',
      'Камеры онлайн, архив записей и события: кто пришёл и когда. Уведомление со снимком придёт сразу на телефон.'),
  OnboardingSlide('support', 'Поддержка рядом',
      'Пишите в чат, создавайте обращения и следите за ответами. Мы сообщим о списаниях, работах на линии и новостях.'),
];

/// Конфигурация приложения, синхронизируемая с настройками ЛК на сервере.
/// Кэшируется в SharedPreferences, чтобы экран входа не зависел от сети.
class ConfigProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  bool _loaded = false;
  bool get loaded => _loaded;

  // Брендинг
  Color _primaryColor = const Color(0xFF5BA89D);
  String _brandName = 'СмИТ Биллинг';
  String _logoUrl = '';
  String _supportPhone = '';
  String _supportEmail = '';

  Color get primaryColor => _primaryColor;
  String get brandName => _brandName;
  String get logoUrl => _logoUrl;
  String get supportPhone => _supportPhone;
  String get supportEmail => _supportEmail;

  // Онбординг при первом запуске
  bool _onboardingEnabled = true;
  int _onboardingVersion = 1;
  List<OnboardingSlide> _onboardingSlides = _defaultSlides;
  bool get onboardingEnabled => _onboardingEnabled && _onboardingSlides.isNotEmpty;
  int get onboardingVersion => _onboardingVersion;
  List<OnboardingSlide> get onboardingSlides => _onboardingSlides;

  // Способы входа
  List<AuthProviderInfo> _providers = [];
  Map<String, dynamic> _oauthConfig = {};
  bool _loginByContract = true;
  bool _loginByPhone = true;
  bool _loginByEmail = false;
  bool _recoverEmail = false;
  bool _recoverSms = false;
  bool _biometryAllowed = true;

  List<AuthProviderInfo> get providers => _providers;
  Map<String, dynamic> get oauthConfig => _oauthConfig;
  bool get loginByContract => _loginByContract;
  bool get loginByPhone => _loginByPhone;
  bool get loginByEmail => _loginByEmail;
  bool get recoverEmail => _recoverEmail;
  bool get recoverSms => _recoverSms;
  bool get biometryAllowed => _biometryAllowed;

  // Визуальные эффекты / тема
  bool _themeSwitch = true; // абонент может менять тему
  bool _glassEffect = true; // жидкое стекло
  bool _bgAnimation = true; // анимация фона
  bool _darkThemeDefault = false;

  bool get themeSwitch => _themeSwitch;
  bool get glassEffect => _glassEffect;
  bool get bgAnimation => _bgAnimation;
  bool get darkThemeDefault => _darkThemeDefault;

  // Feature-flags (имя → bool) для остальных разделов приложения.
  Map<String, bool> _features = {};
  bool feature(String key, {bool fallback = true}) =>
      _features[key] ?? fallback;

  String get platform => defaultTargetPlatform == TargetPlatform.iOS
      ? 'ios'
      : 'android';

  /// Грузим из кэша мгновенно, затем обновляем с сервера в фоне.
  Future<void> load() async {
    await _loadCache();
    _loaded = true;
    notifyListeners();
    // фоновое обновление (не блокирует UI)
    refresh();
  }

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        _api.getPublic('/branding'),
        _api.getPublic('/features'),
        _api.getPublic('/auth/methods?platform=$platform'),
      ]);
      _applyBranding(results[0]);
      _applyFeatures(results[1]);
      _applyAuthMethods(results[2]);
      await _saveCache(results[0], results[1], results[2]);
      notifyListeners();
    } catch (_) {
      // оффлайн / сервер недоступен — остаёмся на кэше / дефолтах
    }
  }

  void _applyBranding(Map<String, dynamic> j) {
    if (j['primary_color'] != null) {
      _primaryColor = AuthProviderInfo._parseColor(j['primary_color'].toString());
    }
    _brandName = (j['short'] ?? j['name'] ?? _brandName).toString();
    _logoUrl = ApiClient.absUrl((j['logo_url'] ?? '').toString());
    final support = (j['support'] as Map?) ?? {};
    _supportPhone = (support['phone'] ?? '').toString();
    _supportEmail = (support['email'] ?? '').toString();
    final onb = j['onboarding'];
    if (onb is Map) {
      _onboardingEnabled = onb['enabled'] != false;
      _onboardingVersion = int.tryParse('${onb['version'] ?? 1}') ?? 1;
      final list = (onb['slides'] as List?) ?? const [];
      final parsed = list
          .whereType<Map>()
          .map((m) => OnboardingSlide(
                '${m['icon'] ?? 'star'}',
                '${m['title'] ?? ''}',
                '${m['text'] ?? ''}',
                ApiClient.absUrl('${m['image_url'] ?? ''}'),
              ))
          .toList();
      _onboardingSlides = parsed.isNotEmpty ? parsed : _defaultSlides;
    }
  }

  void _applyFeatures(Map<String, dynamic> j) {
    final f = (j['features'] as Map?)?.cast<String, dynamic>() ?? {};
    _features = f.map((k, v) => MapEntry(k, v == true));
    _themeSwitch = _features['theme_switch'] ?? true;
    _glassEffect = _features['glass_effect'] ?? true;
    _bgAnimation = _features['bg_animation'] ?? true;
    _darkThemeDefault = _features['dark_theme_default'] ?? false;
    _biometryAllowed = _features['biometry'] ?? true;
  }

  void _applyAuthMethods(Map<String, dynamic> j) {
    final list = (j['providers'] as List?) ?? [];
    _providers = list
        .map((e) => AuthProviderInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    _oauthConfig = (j['oauth_config'] as Map?)?.cast<String, dynamic>() ?? {};
    final form = (j['form'] as Map?) ?? {};
    _loginByContract = form['login_by_contract'] != false;
    _loginByPhone = form['login_by_phone'] == true;
    _loginByEmail = form['login_by_email'] == true;
    final recover = (j['recover'] as Map?) ?? {};
    _recoverEmail = recover['email'] == true;
    _recoverSms = recover['sms'] == true;
    if (j['biometry_allowed'] != null) {
      _biometryAllowed = j['biometry_allowed'] == true;
    }
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final b = prefs.getString('cfg_branding');
      final f = prefs.getString('cfg_features');
      final a = prefs.getString('cfg_auth');
      if (b != null) _applyBranding(jsonDecode(b) as Map<String, dynamic>);
      if (f != null) _applyFeatures(jsonDecode(f) as Map<String, dynamic>);
      if (a != null) _applyAuthMethods(jsonDecode(a) as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _saveCache(Map b, Map f, Map a) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cfg_branding', jsonEncode(b));
      await prefs.setString('cfg_features', jsonEncode(f));
      await prefs.setString('cfg_auth', jsonEncode(a));
    } catch (_) {}
  }

  String oauthValue(String provider, String key) {
    final p = (_oauthConfig[provider] as Map?) ?? {};
    return (p[key] ?? '').toString();
  }
}
