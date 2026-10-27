import 'package:flutter/material.dart';

/// Глобальные ключи приложения — для переходов из push-уведомлений,
/// когда под рукой нет BuildContext экрана.
final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();
