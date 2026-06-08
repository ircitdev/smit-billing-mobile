import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/account_provider.dart';
import '../theme/app_status_colors.dart';
import 'change_password_screen.dart';
import 'game_hub.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final auth = context.watch<AuthProvider>();
    final status = account.status;
    final colorScheme = Theme.of(context).colorScheme;
    final st = AppStatusColors.of(context);

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
                  _AvatarEasterEgg(
                    letter: status != null && status.name.isNotEmpty
                        ? status.name[0].toUpperCase()
                        : '?',
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
                    color: status?.isBlocked == true ? st.warning : null),
                title: const Text('Добровольная блокировка'),
                subtitle: Text(status?.isBlocked == true
                    ? 'Услуги приостановлены'
                    : 'Приостановить услуги на время отпуска'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showVoluntaryBlockDialog(context),
              ),
            ),

            const Divider(height: 32),

            // Logout
            ListTile(
              leading: Icon(Icons.logout, color: st.danger),
              title:
                  Text('Выйти', style: TextStyle(color: st.danger)),
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

/// Аватар с пасхалкой: 6 быстрых тапов подряд открывают мини-игры.
class _AvatarEasterEgg extends StatefulWidget {
  final String letter;

  const _AvatarEasterEgg({required this.letter});

  @override
  State<_AvatarEasterEgg> createState() => _AvatarEasterEggState();
}

class _AvatarEasterEggState extends State<_AvatarEasterEgg> {
  int _taps = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  void _onTap() {
    final now = DateTime.now();
    // Сбрасываем счётчик, если между тапами прошло больше 1.2 сек
    if (now.difference(_lastTap) > const Duration(milliseconds: 1200)) {
      _taps = 0;
    }
    _lastTap = now;
    _taps++;
    if (_taps >= 6) {
      _taps = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GameHub()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: CircleAvatar(
        radius: 40,
        child: Text(
          widget.letter,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}
