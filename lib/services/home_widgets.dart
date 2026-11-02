import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'api_client.dart';

/// Виджеты на главном экране телефона: «Баланс» и «Видеонаблюдение».
/// Android — нативный код в smit_billing_app/android; iOS 17+ — расширение
/// ios/SmitWidgets (ключ — в общей связке ключей, см. AppDelegate.swift).
///
/// Виджет обновляется сам (раз в 30 минут и по кнопке ⟳), без запуска приложения,
/// поэтому ему нужен свой ключ: приложение берёт у сервера ключ только для чтения
/// (`POST /widget/token`, 90 дней) и передаёт его нативной части. При выходе из
/// учётной записи ключ стирается — виджет просит войти.
class HomeWidgets {
  static const _ch = MethodChannel('ru.smit34.smit_billing/widgets');
  static bool get _on => Platform.isAndroid || Platform.isIOS;

  /// Вкладка, которую попросил открыть виджет (null — обычный запуск).
  static Future<String?> takeLaunchTarget() async {
    if (!_on) return null;
    try {
      return await _ch.invokeMethod<String>('takeLaunchTarget');
    } catch (_) {
      return null;
    }
  }

  /// Передать виджетам свежий ключ и обновить их. Ошибки не мешают приложению.
  static Future<void> sync(ApiClient api) async {
    if (!_on) return;
    try {
      final data = await api.post('/widget/token', {});
      final token = data is Map ? data['token'] as String? : null;
      if (token == null) return;
      await _ch.invokeMethod('configure', {'base': ApiClient.baseUrl, 'token': token});
    } catch (_) {/* старый сервер — виджет покажет «откройте приложение» */}
  }

  static Future<void> clear() async {
    if (!_on) return;
    try {
      await _ch.invokeMethod('clear');
    } catch (_) {}
  }

  /// Подписка на «открыть вкладку» от виджета, когда приложение уже запущено.
  static void listen(void Function(String target) onOpen) {
    if (!_on) return;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) onOpen(call.arguments as String);
    });
  }
}
