import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    final cfg = context.read<ConfigProvider>();
    // свежие настройки (онбординг, брендинг) — не дольше 3 с, иначе кэш
    await Future.wait([
      auth.tryAutoLogin(),
      cfg.refresh().timeout(const Duration(seconds: 3), onTimeout: () {}),
    ]);

    if (!mounted) return;
    await _maybeOnboarding(cfg);
    if (!mounted) return;

    if (auth.isAuthenticated) {
      // If biometric enabled, ask for verification
      if (auth.biometricEnabled) {
        final ok = await auth.authenticateWithBiometric();
        if (!mounted) return;
        if (ok) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  /// Онбординг — пока клиент не видел текущую редакцию (сервер может
  /// поднять номер редакции, чтобы показать его заново всем).
  Future<void> _maybeOnboarding(ConfigProvider cfg) async {
    if (!cfg.onboardingEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt('onboarding_seen') ?? 0) >= cfg.onboardingVersion) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const OnboardingScreen(),
    ));
    await prefs.setInt('onboarding_seen', cfg.onboardingVersion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/icon.png', width: 80, height: 80),
            ),
            const SizedBox(height: 16),
            Text(
              'SmIT34',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
