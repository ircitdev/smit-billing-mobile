import 'dart:math';
import 'package:flutter/material.dart';

const _bgUrls = [
  'https://storage.googleapis.com/uspeshnyy-projects/smit/billing/app/bg.png',
  'https://storage.googleapis.com/uspeshnyy-projects/smit/billing/app/bg2.png',
  'https://storage.googleapis.com/uspeshnyy-projects/smit/billing/app/bg3.png',
  'https://storage.googleapis.com/uspeshnyy-projects/smit/billing/app/bg4.png',
];

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

  Color _balanceColor() {
    if (balance < 0) return Colors.red;
    if (balance < 100) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(_bgUrls[balance.hashCode.abs() % _bgUrls.length]),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
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
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? Colors.red.withOpacity(0.15)
                        : Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isBlocked ? Colors.red.shade300 : Colors.green.shade300,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBlocked ? Icons.block : Icons.check_circle,
                        size: 14,
                        color: isBlocked ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBlocked ? 'Заблокирован' : 'Активен',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isBlocked ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${balance.toStringAsFixed(2)} \u20BD',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _balanceColor(),
                  ),
            ),
            // Last payment
            if (lastPayment != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.history, size: 14,
                      color: colorScheme.onPrimaryContainer.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text(
                    'Последний платёж ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                        ),
                  ),
                  Text(
                    '+${lastPayment!['amount']} \u20BD',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '  ${lastPayment!['date'] ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withOpacity(0.7),
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
      ),
    );
  }
}
