import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import '../services/oauth_service.dart';
import '../services/api_client.dart';
import '../widgets/glass.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _contractController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _oauthBusy = false;

  @override
  void dispose() {
    _contractController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Подпись поля логина зависит от того, какие идентификаторы разрешены в ЛК.
  String _loginLabel(ConfigProvider cfg) {
    final parts = <String>['Номер договора'];
    if (cfg.loginByPhone) parts.add('телефон');
    if (cfg.loginByEmail) parts.add('email');
    if (parts.length == 1) return parts.first;
    return '${parts.first} / ${parts.sublist(1).join(' / ')}';
  }

  Future<void> _login() async {
    final contract = _contractController.text.trim();
    final password = _passwordController.text.trim();

    if (contract.isEmpty || password.isEmpty) {
      _snack('Введите логин и пароль');
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.login(contract, password);

    if (!mounted) return;
    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (auth.error != null) {
      _snack(auth.error!);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Запуск входа через соцсеть. Нативные провайдеры — через SDK,
  /// прочие (VK/Telegram) — через внешний браузер (deep-link).
  Future<void> _social(AuthProviderInfo p) async {
    final cfg = context.read<ConfigProvider>();
    final auth = context.read<AuthProvider>();

    if (!p.native) {
      await _browserSocial(p);
      return;
    }

    setState(() => _oauthBusy = true);
    final svc = OAuthService(auth.api, cfg);
    final res = await svc.signIn(p.code);
    if (!mounted) return;
    setState(() => _oauthBusy = false);

    if (res.success) {
      await auth.finishOAuthLogin();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } else if (res.needsLinking && res.linkData != null) {
      _showLinkDialog(svc, res.linkData!, p.label);
    } else if (res.message != null) {
      _snack(res.message!);
    }
  }

  Future<void> _browserSocial(AuthProviderInfo p) async {
    Uri? uri;
    if (p.code == 'vk') {
      uri = Uri.parse('${ApiClient.baseUrl.replaceFirst('/mobile-api/v1', '')}/lk/auth/vk/');
    } else if (p.code == 'telegram') {
      final cfg = context.read<ConfigProvider>();
      final bot = cfg.oauthValue('telegram', 'bot_username');
      if (bot.isNotEmpty) {
        uri = Uri.parse('https://t.me/$bot?start=login');
      }
    }
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('Не удалось открыть ${p.label}');
    }
  }

  /// Диалог привязки соцсети к договору (после needs_linking).
  void _showLinkDialog(
      OAuthService svc, Map<String, dynamic> linkData, String label) {
    final loginCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    bool busy = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Привязать $label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$label ещё не привязан. Войдите по договору один раз — '
                  'дальше вход будет в одно касание.'),
              const SizedBox(height: 16),
              TextField(
                controller: loginCtrl,
                decoration: const InputDecoration(
                  labelText: 'Номер договора',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setLocal(() => busy = true);
                      final r = await svc.link(linkData,
                          loginCtrl.text.trim(), pwdCtrl.text.trim());
                      if (!mounted) return;
                      if (r.success) {
                        Navigator.pop(ctx);
                        await context.read<AuthProvider>().finishOAuthLogin();
                        if (mounted) {
                          Navigator.pushReplacementNamed(context, '/home');
                        }
                      } else {
                        setLocal(() => busy = false);
                        _snack(r.message ?? 'Не удалось привязать');
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Привязать'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecoverSheet(ConfigProvider cfg) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Восстановление пароля',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (cfg.recoverEmail)
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('По email'),
                onTap: () {
                  Navigator.pop(ctx);
                  _snack('Письмо для восстановления отправлено на ваш email');
                },
              ),
            if (cfg.recoverSms)
              ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: const Text('По SMS'),
                onTap: () {
                  Navigator.pop(ctx);
                  _snack('Код восстановления отправлен по SMS');
                },
              ),
            ListTile(
              leading: Icon(Icons.support_agent,
                  color: Theme.of(ctx).colorScheme.primary),
              title: const Text('Обратиться в поддержку'),
              subtitle: cfg.supportPhone.isNotEmpty
                  ? Text(cfg.supportPhone)
                  : null,
              onTap: () async {
                Navigator.pop(ctx);
                if (cfg.supportPhone.isNotEmpty) {
                  final uri = Uri.parse('tel:${cfg.supportPhone}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cfg = context.watch<ConfigProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final glass = cfg.glassEffect;

    return Scaffold(
      body: AnimatedGradientBackground(
        primary: cfg.primaryColor,
        animate: cfg.bgAnimation,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                enabled: glass,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: cfg.logoUrl.isNotEmpty
                          ? Image.network(cfg.logoUrl,
                              width: 76,
                              height: 76,
                              errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/icon.png',
                                  width: 76,
                                  height: 76))
                          : Image.asset('assets/icon.png',
                              width: 76, height: 76),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cfg.brandName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Личный кабинет абонента',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _contractController,
                      keyboardType: cfg.loginByEmail
                          ? TextInputType.text
                          : TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _loginLabel(cfg),
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                        filled: glass,
                        fillColor: glass
                            ? colorScheme.surface.withOpacity(0.4)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        filled: glass,
                        fillColor: glass
                            ? colorScheme.surface.withOpacity(0.4)
                            : null,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    if (cfg.recoverEmail || cfg.recoverSms)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showRecoverSheet(cfg),
                          child: const Text('Забыли пароль?'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: auth.isLoading ? null : _login,
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Войти'),
                      ),
                    ),

                    // ── Способы входа (динамически из настроек ЛК) ──
                    if (cfg.providers.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Или войти через',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: colorScheme.onSurfaceVariant)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final p in cfg.providers)
                            _SocialButton(
                              info: p,
                              busy: _oauthBusy,
                              onTap: () => _social(p),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final AuthProviderInfo info;
  final bool busy;
  final VoidCallback onTap;

  const _SocialButton({
    required this.info,
    required this.busy,
    required this.onTap,
  });

  Widget _icon() {
    switch (info.icon) {
      case 'vk':
        return Text('VK',
            style: TextStyle(
                fontWeight: FontWeight.w900, color: info.color, fontSize: 15));
      case 'telegram':
        return Icon(Icons.send, color: info.color, size: 18);
      case 'google':
        return Text('G',
            style: TextStyle(
                fontWeight: FontWeight.w900, color: info.color, fontSize: 17));
      case 'apple':
        return Icon(Icons.apple, color: info.color, size: 20);
      case 'yandex':
        return Text('Я',
            style: TextStyle(
                fontWeight: FontWeight.w900, color: info.color, fontSize: 16));
      default:
        return Icon(Icons.login, color: info.color, size: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onTap,
      icon: _icon(),
      label: Text(info.label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
