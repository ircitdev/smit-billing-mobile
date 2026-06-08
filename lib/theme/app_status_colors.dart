import 'package:flutter/material.dart';

/// Семантические цвета статусов (success / warning / danger / info), адаптивные
/// к светлой и тёмной теме. Заменяют хардкод Colors.green/red/orange/brown +
/// .shade50-фоны, которые ломались в тёмной теме (UX/UI аудит 2026-06-08).
///
/// Использование:
///   final s = AppStatusColors.of(context);
///   Card(color: s.successContainer, child: Text('OK', style: TextStyle(color: s.onSuccessContainer)))
///   Icon(Icons.check, color: s.success)
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  // Акцентные «передние» цвета (иконки, текст-акценты, бордеры)
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  // Контейнеры (фоны карточек/баннеров) + их «on»-цвета (текст поверх)
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color dangerContainer;
  final Color onDangerContainer;
  final Color infoContainer;
  final Color onInfoContainer;

  const AppStatusColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  /// Светлая тема — мягкие пастельные контейнеры, насыщённые акценты.
  static const light = AppStatusColors(
    success: Color(0xFF2E7D52),
    warning: Color(0xFFB26A00),
    danger: Color(0xFFC62828),
    info: Color(0xFF1565C0),
    successContainer: Color(0xFFE3F4EA),
    onSuccessContainer: Color(0xFF1B5E3A),
    warningContainer: Color(0xFFFFF3DF),
    onWarningContainer: Color(0xFF7A4A00),
    dangerContainer: Color(0xFFFDECEC),
    onDangerContainer: Color(0xFF8E1C1C),
    infoContainer: Color(0xFFE6F0FB),
    onInfoContainer: Color(0xFF0D47A1),
  );

  /// Тёмная тема — приглушённые акценты (контраст ≥ AA на тёмном фоне),
  /// тёмные контейнеры со светлым текстом.
  static const dark = AppStatusColors(
    success: Color(0xFF6FD79B),
    warning: Color(0xFFF2B85C),
    danger: Color(0xFFF28B82),
    info: Color(0xFF8AB4F8),
    successContainer: Color(0xFF1E3A2C),
    onSuccessContainer: Color(0xFFB6EFC9),
    warningContainer: Color(0xFF3A2E1A),
    onWarningContainer: Color(0xFFFFE0B2),
    dangerContainer: Color(0xFF3A2222),
    onDangerContainer: Color(0xFFFFD6D2),
    infoContainer: Color(0xFF1B2A3F),
    onInfoContainer: Color(0xFFC9DDF9),
  );

  static AppStatusColors of(BuildContext context) =>
      Theme.of(context).extension<AppStatusColors>() ?? light;

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      onDangerContainer: Color.lerp(onDangerContainer, other.onDangerContainer, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}
