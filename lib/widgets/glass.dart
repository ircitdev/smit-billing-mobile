import 'dart:ui';
import 'package:flutter/material.dart';

/// «Жидкое стекло» — карточка с blur-фоном и полупрозрачной заливкой.
/// Согласовано с настройкой ЛК LK_GLASS_EFFECT (ConfigProvider.glassEffect).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double blur;
  final double radius;
  final bool enabled; // если выключено стекло — обычная Card

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.blur = 18,
    this.radius = 24,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!enabled) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius)),
        child: Padding(padding: padding, child: child),
      );
    }
    final fill = dark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.55);
    final border = dark
        ? Colors.white.withOpacity(0.16)
        : Colors.white.withOpacity(0.7);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.35 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Анимированный градиентный фон (мягкий «ken-burns» перелив).
/// Согласовано с LK_BG_ANIMATION (ConfigProvider.bgAnimation).
class AnimatedGradientBackground extends StatefulWidget {
  final Color primary;
  final bool animate;
  final Widget child;

  const AnimatedGradientBackground({
    super.key,
    required this.primary,
    required this.child,
    this.animate = true,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (widget.animate) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).colorScheme;
    final p = widget.primary;
    final c1 = p.withOpacity(dark ? 0.55 : 0.85);
    final c2 = base.tertiary.withOpacity(dark ? 0.45 : 0.55);
    final c3 = dark ? base.surface : Color.lerp(p, Colors.white, 0.85)!;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = widget.animate ? _ctrl.value : 0.5;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 0.5, -1),
              end: Alignment(1, 1 - t * 0.5),
              colors: [c1, c2, c3],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
