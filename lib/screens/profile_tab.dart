import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/account_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/config_provider.dart';
import '../services/oauth_service.dart';
import '../services/review_service.dart';
import 'messages_screen.dart';
import 'change_password_screen.dart';
import 'game_hub.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int _avatarTapCount = 0;
  DateTime? _lastTap;

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  void _onAvatarTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds > 800) {
      _avatarTapCount = 0; // reset if too slow
    }
    _lastTap = now;
    _avatarTapCount++;
    if (_avatarTapCount >= 6) {
      _avatarTapCount = 0;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const GameHub()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final auth = context.watch<AuthProvider>();
    final status = account.status;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: RefreshIndicator(
        onRefresh: () => account.loadStatus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar & name
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _onAvatarTap,
                    child: CircleAvatar(
                      radius: 40,
                      child: Text(
                        _getInitials(status?.name ?? ''),
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status?.name ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Договор: ${status?.contractNumber ?? ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info
            if (status != null) ...[
              _ProfileTile(
                icon: Icons.home_outlined,
                title: 'Адрес',
                subtitle:
                    status.address.isNotEmpty ? status.address : 'Не указан',
              ),
              _ProfileTile(
                icon: Icons.speed,
                title: 'Тариф',
                subtitle: status.tariffName ?? 'Не назначен',
              ),
              _ProfileTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Баланс',
                subtitle: '${status.balance.toStringAsFixed(2)} \u20BD',
              ),
            ],

            const Divider(height: 32),

            // Services section
            _ServicesSection(),

            const Divider(height: 32),

            // Messages
            Card(
              child: ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Сообщения от оператора'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()));
                },
              ),
            ),

            const Divider(height: 32),

            // Contact data
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.mail_outline, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Контактные данные',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            if (status != null) ...[
              _EditableContactField(
                label: 'Email',
                value: status.email,
                icon: Icons.email_outlined,
                fieldKey: 'email',
                keyboardType: TextInputType.emailAddress,
                hintText: 'example@mail.ru',
              ),
              _EditableContactField(
                label: 'Телефон для SMS',
                value: status.sms,
                icon: Icons.sms_outlined,
                fieldKey: 'sms',
                keyboardType: TextInputType.phone,
                hintText: '+79001234567',
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Для изменения обратитесь в поддержку',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],

            const Divider(height: 32),

            // Security section
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.security, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Безопасность',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),

            // Change password
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Сменить пароль'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),
            ),

            // Biometric toggle (если устройство поддерживает И оператор разрешил)
            if (auth.biometricAvailable &&
                context.watch<ConfigProvider>().biometryAllowed)
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Вход по биометрии'),
                  subtitle: const Text('Отпечаток пальца или Face ID'),
                  value: auth.biometricEnabled,
                  onChanged: (v) => auth.setBiometricEnabled(v),
                ),
              ),

            // Voluntary block
            Card(
              child: ListTile(
                leading: Icon(Icons.pause_circle_outline,
                    color: status?.isBlocked == true ? Colors.orange : null),
                title: const Text('Добровольная блокировка'),
                subtitle: Text(status?.isBlocked == true
                    ? 'Услуги приостановлены'
                    : 'Приостановить услуги на время отпуска'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showVoluntaryBlockDialog(context),
              ),
            ),

            // Social login (динамически из настроек ЛК)
            if (context.watch<ConfigProvider>().providers.isNotEmpty) ...[
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 20, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Вход через соцсети',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Привяжите аккаунт для быстрого входа',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              for (final p in context.watch<ConfigProvider>().providers)
                _SocialLinkTile(info: p),
            ],

            // Theme selector — только если оператор разрешил смену темы.
            if (context.watch<ConfigProvider>().themeSwitch) ...[
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.palette, size: 20, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Тема оформления',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProv, _) {
                  return Card(
                    child: Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          title: const Text('Системная'),
                          subtitle: const Text('Как в настройках устройства'),
                          value: ThemeMode.system,
                          groupValue: themeProv.themeMode,
                          onChanged: (v) => themeProv.setThemeMode(v!),
                          dense: true,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Светлая'),
                          value: ThemeMode.light,
                          groupValue: themeProv.themeMode,
                          onChanged: (v) => themeProv.setThemeMode(v!),
                          dense: true,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Тёмная'),
                          value: ThemeMode.dark,
                          groupValue: themeProv.themeMode,
                          onChanged: (v) => themeProv.setThemeMode(v!),
                          dense: true,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            const Divider(height: 32),

            // Rate app
            Card(
              child: ListTile(
                leading: const Icon(Icons.star_outline, color: Colors.amber),
                title: const Text('Оценить приложение'),
                subtitle: const Text('Поставьте оценку в Google Play'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ReviewService.openStoreListing(),
              ),
            ),

            const Divider(height: 32),

            // Legal
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Политика конфиденциальности'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final uri = Uri.parse('https://billing.smit34.ru/privacy.html');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Пользовательское соглашение'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final uri = Uri.parse('https://billing.smit34.ru/copyright.html');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),

            const Divider(height: 32),

            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title:
                  const Text('Выйти', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Выход'),
                    content: const Text('Выйти из аккаунта?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Выйти'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            const Center(child: _VersionLabel()),
          ],
        ),
      ),
    );
  }

  void _showVoluntaryBlockDialog(BuildContext context) async {
    final account = context.read<AccountProvider>();
    final data = await account.getVoluntaryBlock();
    if (!context.mounted) return;

    final canBlock = data['can_block'] == true;
    final isBlocked = data['is_blocked'] == true;
    final maxDays = data['max_days'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBlocked ? 'Разблокировать услуги?' : 'Приостановить услуги?'),
        content: Text(isBlocked
            ? 'Услуги будут возобновлены немедленно.'
            : canBlock
                ? 'Услуги будут приостановлены${maxDays > 0 ? ' (макс. $maxDays дн.)' : ''}. '
                    'Абонентская плата не списывается.'
                : 'Добровольная блокировка недоступна на вашем тарифе.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          if (canBlock || isBlocked)
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final msg = await account.toggleVoluntaryBlock(
                    isBlocked ? 'unblock' : 'block');
                if (context.mounted && msg != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                }
              },
              child: Text(isBlocked ? 'Разблокировать' : 'Приостановить'),
            ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _ServicesSection extends StatefulWidget {
  const _ServicesSection();

  @override
  State<_ServicesSection> createState() => _ServicesSectionState();
}

class _ServicesSectionState extends State<_ServicesSection> {
  List<Map<String, dynamic>>? _services;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.get('/services/list');
      if (mounted) {
        setState(() {
          _services = ((data['items'] as List?) ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.widgets_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('Подключённые услуги',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        if (_loading)
          const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else if (_services == null || _services!.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant, size: 20),
                  const SizedBox(width: 12),
                  Text('Нет подключённых услуг',
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: _services!.asMap().entries.map((entry) {
                final i = entry.key;
                final svc = entry.value;
                final enabled = svc['enabled'] == true;
                final name = svc['name'] ?? 'Услуга';
                final price = svc['price'];
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        enabled ? Icons.check_circle : Icons.cancel_outlined,
                        color: enabled ? Colors.green : Colors.grey,
                        size: 22,
                      ),
                      title: Text(name, style: const TextStyle(fontSize: 14)),
                      subtitle: price != null
                          ? Text('${double.tryParse(price.toString())?.toStringAsFixed(2) ?? price} \u20BD/мес',
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant))
                          : null,
                      trailing: Text(
                        enabled ? 'Активна' : 'Отключена',
                        style: TextStyle(
                          fontSize: 12,
                          color: enabled ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      dense: true,
                    ),
                    if (i < _services!.length - 1) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _EditableContactField extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final String fieldKey; // 'email' or 'sms'
  final TextInputType keyboardType;
  final String hintText;

  const _EditableContactField({
    required this.label,
    required this.value,
    required this.icon,
    required this.fieldKey,
    required this.keyboardType,
    required this.hintText,
  });

  @override
  State<_EditableContactField> createState() => _EditableContactFieldState();
}

class _EditableContactFieldState extends State<_EditableContactField> {
  final _controller = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _saving = true);
    final account = context.read<AccountProvider>();
    try {
      await account.apiPost('/account/update_contacts', {widget.fieldKey: text});
      if (mounted) {
        setState(() { _editing = false; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сохранено')),
        );
        account.loadStatus(); // refresh
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEmpty = widget.value.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          if (_editing)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: widget.keyboardType,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      prefixIcon: Icon(widget.icon, size: 18),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 20),
                ),
                IconButton(
                  onPressed: () => setState(() => _editing = false),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEmpty ? 'Не указан' : widget.value,
                      style: TextStyle(
                        color: isEmpty ? colorScheme.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                  if (isEmpty)
                    TextButton(
                      onPressed: () => setState(() => _editing = true),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Указать'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Версия приложения из pubspec (package_info_plus).
class _VersionLabel extends StatefulWidget {
  const _VersionLabel();

  @override
  State<_VersionLabel> createState() => _VersionLabelState();
}

class _VersionLabelState extends State<_VersionLabel> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = 'v${info.version} (${info.buildNumber})');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _version,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

/// Карточка привязки одной соцсети в профиле. Запускает тот же OAuth-flow,
/// что и экран входа; при needs_linking привязывает к текущему договору.
class _SocialLinkTile extends StatefulWidget {
  final AuthProviderInfo info;
  const _SocialLinkTile({required this.info});

  @override
  State<_SocialLinkTile> createState() => _SocialLinkTileState();
}

class _SocialLinkTileState extends State<_SocialLinkTile> {
  bool _busy = false;

  Widget _badge() {
    final p = widget.info;
    Widget inner;
    switch (p.icon) {
      case 'vk':
        inner = const Text('VK',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13));
        break;
      case 'telegram':
        inner = const Icon(Icons.send, color: Colors.white, size: 18);
        break;
      case 'google':
        inner = const Text('G',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15));
        break;
      case 'apple':
        inner = const Icon(Icons.apple, color: Colors.white, size: 20);
        break;
      case 'yandex':
        inner = const Text('Я',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14));
        break;
      default:
        inner = const Icon(Icons.link, color: Colors.white, size: 18);
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: p.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: inner),
    );
  }

  Future<void> _link() async {
    final p = widget.info;
    final cfg = context.read<ConfigProvider>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    // Telegram привязывается через deep-link существующего endpoint.
    if (p.code == 'telegram') {
      try {
        final response = await auth.api.get('/account/telegram_link');
        final dl = response['deep_link'];
        if (dl != null) {
          final uri = Uri.parse(dl.toString());
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } catch (_) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Не удалось получить ссылку')));
      }
      return;
    }

    // VK (без нативного mobile-endpoint) — через браузер.
    if (!p.native) {
      messenger.showSnackBar(SnackBar(
          content: Text('Привязка ${p.label} выполняется на сайте ЛК')));
      return;
    }

    setState(() => _busy = true);
    final svc = OAuthService(auth.api, cfg);
    final res = await svc.signIn(p.code);
    if (!mounted) return;
    setState(() => _busy = false);

    if (res.success) {
      messenger.showSnackBar(SnackBar(content: Text('${p.label} привязан')));
    } else if (res.needsLinking) {
      // привязка происходит автоматически (уже вошли по договору в этой сессии).
      messenger.showSnackBar(SnackBar(
          content: Text('Войдите через ${p.label} ещё раз для завершения')));
    } else if (res.message != null) {
      messenger.showSnackBar(SnackBar(content: Text(res.message!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _badge(),
        title: Text(widget.info.label),
        subtitle: const Text('Не привязан'),
        trailing: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : OutlinedButton(
                onPressed: _link,
                child: const Text('Привязать'),
              ),
      ),
    );
  }
}
