import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/auth_provider.dart';
import 'providers/account_provider.dart';
import 'providers/theme_provider.dart';
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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, AccountProvider>(
          create: (_) => AccountProvider(),
          update: (_, auth, account) => account!..updateAuth(auth),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          // Общий стиль AppBar для обеих тем (раньше был только в light —
          // в тёмной теме заголовки не центрировались + появлялась тень).
          const appBar = AppBarTheme(centerTitle: true, elevation: 0);
          return MaterialApp(
            title: 'СмИТ Биллинг',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF43B77A),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              appBarTheme: appBar,
              extensions: const [AppStatusColors.light],
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF43B77A),
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
