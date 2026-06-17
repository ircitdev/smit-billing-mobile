import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/auth_provider.dart';
import 'providers/account_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/config_provider.dart';
import 'theme/app_status_colors.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  runApp(const SmitBillingApp());
}

class SmitBillingApp extends StatelessWidget {
  const SmitBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()..load()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, AccountProvider>(
          create: (_) => AccountProvider(),
          update: (_, auth, account) => account!..updateAuth(auth),
        ),
      ],
      // Слушаем тему + конфиг: цвет бренда и дефолт темы приходят с сервера.
      child: Consumer2<ThemeProvider, ConfigProvider>(
        builder: (context, themeProvider, config, _) {
          // Применяем серверный дефолт темы (если абонент сам не выбирал).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            themeProvider.applyServerDefault(config.darkThemeDefault);
          });
          // Общий стиль AppBar для обеих тем (раньше был только в light —
          // в тёмной теме заголовки не центрировались + появлялась тень).
          const appBar = AppBarTheme(centerTitle: true, elevation: 0);
          final seed = config.primaryColor;
          return MaterialApp(
            title: 'СмИТ Биллинг',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: seed,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              appBarTheme: appBar,
              extensions: const [AppStatusColors.light],
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: seed,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              appBarTheme: appBar,
              extensions: const [AppStatusColors.dark],
            ),
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}
