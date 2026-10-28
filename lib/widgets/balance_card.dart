import 'package:flutter/material.dart';
import '../theme/app_status_colors.dart';

class BalanceCard extends StatelessWidget {
  final double balance;
  final bool isBlocked;
  final VoidCallback onPayPressed;
  final Map<String, dynamic>? lastPayment;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.isBlocked,
    required this.onPayPressed,
    this.lastPayment,
  });

  // Фоны плашки (сеть/глобус) — вшиты в приложение: раньше грузились из облака
  // и пропали, когда облако было заморожено. Меняются по дням.
  static const _bgAssets = [
    'assets/balance/bg1.jpg',
    'assets/balance/bg2.jpg',
    'assets/balance/bg3.jpg',
    'assets/balance/bg4.jpg',
  ];

  // Цвет суммы поверх тёмного фона: положительный — белый, долг/низкий —
  // светлые красный/янтарный (тёмные оттенки темы на фото не читаются).
  Color _balanceColor(AppStatusColors st, Color onBg) {
    if (balance < 0) return const Color(0xFFFF8A80);
    if (balance < 100) return const Color(0xFFFFD180);
    return onBg;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final st = AppStatusColors.of(context);

    // Фон — тёмная картинка с затемнением слева (там текст), текст белый.
    const onBg = Colors.white;
    final now = DateTime.now();
    final bg = _bgAssets[(now.year * 400 + now.month * 31 + now.day) % _bgAssets.length];
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              bg,
              fit: BoxFit.cover,
              // если картинка не прочиталась — бренд-градиент, как раньше
              errorBuilder: (_, __, ___) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    colorScheme.primary,
                    Color.alphaBlend(
                        Colors.black.withValues(alpha: 0.35), colorScheme.primary),
                  ]),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0x99000000), Color(0x33000000)],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: "Баланс" + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Баланс',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: onBg,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? st.dangerContainer
                        : st.successContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isBlocked ? st.danger : st.success,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBlocked ? Icons.block : Icons.check_circle,
                        size: 14,
                        color: isBlocked ? st.onDangerContainer : st.onSuccessContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBlocked ? 'Заблокирован' : 'Активен',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isBlocked ? st.onDangerContainer : st.onSuccessContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // build 1039: \u043D\u0435-\u0446\u0432\u0435\u0442\u043E\u0432\u043E\u0439 \u0441\u0438\u0433\u043D\u0430\u043B \u0441\u0442\u0430\u0442\u0443\u0441\u0430 \u0431\u0430\u043B\u0430\u043D\u0441\u0430 (\u0434\u043B\u044F \u0434\u0430\u043B\u044C\u0442\u043E\u043D\u0438\u043A\u043E\u0432)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    '${balance.toStringAsFixed(2)} \u20BD',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _balanceColor(st, onBg),
                        ),
                  ),
                ),
                if (balance < 0) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_downward,
                      size: 22, color: _balanceColor(st, onBg)),
                  const SizedBox(width: 2),
                  Text('\u0434\u043E\u043B\u0433',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _balanceColor(st, onBg))),
                ] else if (balance < 100) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.warning_amber_rounded,
                      size: 20, color: _balanceColor(st, onBg)),
                  const SizedBox(width: 2),
                  Text('\u043D\u0438\u0437\u043A\u0438\u0439 \u0431\u0430\u043B\u0430\u043D\u0441',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _balanceColor(st, onBg))),
                ],
              ],
            ),
            // Last payment
            if (lastPayment != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.history, size: 14,
                      color: onBg.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  Text(
                    'Последний платёж ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: onBg.withValues(alpha: 0.8),
                        ),
                  ),
                  Text(
                    '+${lastPayment!['amount']} \u20BD',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: onBg,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    '  ${lastPayment!['date'] ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: onBg.withValues(alpha: 0.8),
                        ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPayPressed,
                icon: const Icon(Icons.add_card),
                label: const Text('Пополнить'),
              ),
            ),
              ],
            ),
          ), // build 1039: закрытие inner Container
        ], // build 1039: закрытие Stack children
      ), // build 1039: закрытие Stack
    );
  }
}
