import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _contractController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _contractController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final contract = _contractController.text.trim();
    final password = _passwordController.text.trim();

    if (contract.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите номер договора и пароль')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.login(contract, password);

    if (!mounted) return;
    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!)),
      );
    }
  }

  Future<void> _loginWithApple() async {
    final auth = context.read<AuthProvider>();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось получить токен Apple ID')),
        );
        return;
      }

      final result = await auth.loginWithApple(identityToken);
      if (!mounted) return;

      if (result == 'success') {
        Navigator.pushReplacementNamed(context, '/home');
      } else if (result.startsWith('needs_linking:')) {
        final appleToken = result.substring('needs_linking:'.length);
        _showLinkingDialog(appleToken);
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка Apple ID: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Ошибка входа через Apple ID')),
      );
    }
  }

  void _showLinkingDialog(String appleToken) {
    final contractCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Привязать Apple ID'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Для первого входа через Apple ID введите номер договора и пароль, '
                'чтобы привязать аккаунт.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contractCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Номер договора',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                final success = await auth.linkAppleAccount(
                  appleToken,
                  contractCtrl.text.trim(),
                  passwordCtrl.text.trim(),
                );
                if (!mounted) return;
                if (success) {
                  Navigator.pushReplacementNamed(context, '/home');
                } else if (auth.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(auth.error!)),
                  );
                }
              },
              child: const Text('Привязать и войти'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 80,
                    height: 80,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'СмИТ Биллинг',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Личный кабинет абонента',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _contractController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Номер договора',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: auth.isLoading ? null : _login,
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Войти'),
                  ),
                ),
                // Вход через Apple ID — только на iOS (на Android бессмысленно
                // и недоступно). Кнопка обязательна для App Store, если есть
                // сторонние соц-логины.
                if (Platform.isIOS) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'или',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SignInWithAppleButton(
                    onPressed: auth.isLoading ? () {} : _loginWithApple,
                    style: SignInWithAppleButtonStyle.black,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
