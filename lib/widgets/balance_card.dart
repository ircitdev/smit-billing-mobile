import 'package:flutter/material.dart';

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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer,
              colorScheme.primary.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Баланс',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
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
