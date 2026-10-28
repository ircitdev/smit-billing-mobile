import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';

/// Онбординг при первом запуске (build 3662). Слайды и включение — в настройках
/// ЛК («Брендинг → Онбординг приложения»), приходят в /branding → onboarding.
/// Закрывается кнопкой «Начать» или «Пропустить»; результат не нужен.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

const _icons = <String, IconData>{
  'wallet': Icons.account_balance_wallet_outlined,
  'services': Icons.apps_rounded,
  'internet': Icons.language,
  'tv': Icons.live_tv_outlined,
  'video': Icons.videocam_outlined,
  'wifi': Icons.wifi,
  'support': Icons.support_agent,
  'chat': Icons.chat_bubble_outline,
  'bell': Icons.notifications_none,
  'shield': Icons.shield_outlined,
  'chart': Icons.show_chart,
  'gift': Icons.card_giftcard,
  'star': Icons.star_outline,
  'phone': Icons.smartphone,
};

// Иллюстрации робота СмИТ (вшиты в приложение) — по значку слайда.
// Своя картинка из настроек (image_url) важнее.
const _robotFor = <String, String>{
  'wallet': 'robot_idea',
  'gift': 'robot_idea',
  'star': 'robot_idea',
  'chart': 'robot_idea',
  'services': 'robot_devices',
  'internet': 'robot_devices',
  'tv': 'robot_devices',
  'wifi': 'robot_devices',
  'phone': 'robot_devices',
  'video': 'robot_biz',
  'shield': 'robot_biz',
  'support': 'robot_help',
  'chat': 'robot_help',
  'bell': 'robot_help',
};

const _backgrounds = [
  'assets/balance/bg2.jpg',
  'assets/balance/bg1.jpg',
  'assets/balance/bg3.jpg',
  'assets/balance/bg4.jpg',
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigProvider>();
    final slides = cfg.onboardingSlides;
    final brand = cfg.primaryColor;
    final last = _page >= slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // фон слайда — плавная смена картинки
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Image.asset(
              _backgrounds[_page % _backgrounds.length],
              key: ValueKey(_page % _backgrounds.length),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0xCC000000), Color(0xF2000000)],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(cfg.brandName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (!last)
                        TextButton(
                          onPressed: _close,
                          style: TextButton.styleFrom(foregroundColor: Colors.white70),
                          child: const Text('Пропустить'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pager,
                    itemCount: slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _Slide(slide: slides[i], brand: brand),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(slides.length, (i) {
                    final on = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: on ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: on ? brand : Colors.white30,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      onPressed: last
                          ? _close
                          : () => _pager.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic),
                      child: Text(last ? 'Начать' : 'Далее'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final OnboardingSlide slide;
  final Color brand;
  const _Slide({required this.slide, required this.brand});

  @override
  Widget build(BuildContext context) {
    final robot = Image.asset(
      'assets/onboarding/${_robotFor[slide.icon] ?? 'robot_idea'}.webp',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _iconCircle(),
    );
    final Widget picture = slide.imageUrl.isNotEmpty
        ? Image.network(slide.imageUrl,
            fit: BoxFit.contain, errorBuilder: (_, __, ___) => robot)
        : robot;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(child: Center(child: picture)),
          const SizedBox(height: 20),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1.2),
          ),
          const SizedBox(height: 14),
          Text(
            slide.text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _iconCircle() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: brand.withValues(alpha: 0.22),
        border: Border.all(color: brand.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Icon(_icons[slide.icon] ?? Icons.star_outline, size: 56, color: Colors.white),
    );
  }
}
