import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/account_provider.dart';
import '../providers/theme_provider.dart';
import 'messages_screen.dart';
import 'change_password_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

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
                  CircleAvatar(
                    radius: 40,
                    child: Text(
                      status != null && status.name.isNotEmpty
                          ? status.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 32),
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
              _ContactField(
                label: 'Email',
                value: status.email.isNotEmpty ? status.email : 'Не указан',
                icon: Icons.email_outlined,
              ),
              _ContactField(
                label: 'Телефон для SMS',
                value: status.sms.isNotEmpty ? status.sms : 'Не указан',
                icon: Icons.sms_outlined,
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

            // Biometric toggle
            if (auth.biometricAvailable)
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

            const Divider(height: 32),

            // Social login
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
            Card(
              child: ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0077FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('VK',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                  ),
                ),
                title: const Text('ВКонтакте'),
                subtitle: const Text('Не привязан'),
                trailing: OutlinedButton(
                  onPressed: () async {
                    final uri = Uri.parse(
                        'https://demo.billing.smit34.ru/lk/oauth/vk/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('Привязать'),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0088CC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.send, color: Colors.white, size: 18),
                ),
                title: const Text('Telegram'),
                subtitle: const Text('Не привязан'),
                trailing: OutlinedButton(
                  onPressed: () async {
                    final uri =
                        Uri.parse('https://t.me/SMITSupport_bot?start=login');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('Привязать'),
                ),
              ),
            ),

            const Divider(height: 32),

            // Theme selector
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
            Center(
              child: Text(
                'v1.1.0',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
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

class _ContactField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ContactField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
