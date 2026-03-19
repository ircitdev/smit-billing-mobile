import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/account_provider.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _amountController = TextEditingController(text: '500');
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите сумму от 1 \u20BD')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final account = context.read<AccountProvider>();
    final result = await account.createPayment(amount);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Платёжная система временно недоступна')),
      );
      return;
    }

    String? url;
    if (result['redirect_url'] != null) {
      // REST API v3 — direct redirect
      url = result['redirect_url'];
    } else if (result['form_post'] == true) {
      // HTTP protocol — build GET URL with params for url_launcher
      final action = result['action'] as String? ?? '';
      final fields = result['fields'] as Map<String, dynamic>? ?? {};
      final params = fields.entries
          .where((e) => e.value != null && e.value.toString().isNotEmpty)
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      url = '$action?$params';
    }

    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Refresh balance when user comes back
        if (mounted) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) account.loadStatus();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = context.read<AccountProvider>().status;
    final colorScheme = Theme.of(context).colorScheme;

    // Suggest amount to cover debt
    final debt = (status != null && status.balance < 0)
        ? (-status.balance).ceil()
        : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Пополнение')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current balance
            if (status != null) ...[
              Card(
                color: status.balance < 0
                    ? colorScheme.errorContainer
                    : colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        status.balance < 0
                            ? Icons.warning_amber
                            : Icons.account_balance_wallet,
                        color: status.balance < 0
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Текущий баланс',
                              style: Theme.of(context).textTheme.labelMedium),
                          Text(
                            '${status.balance.toStringAsFixed(2)} \u20BD',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: status.balance < 0
                                      ? Colors.red
                                      : Colors.green,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (debt > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Для погашения задолженности необходимо минимум $debt \u20BD',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 24),
            ],

            // Amount input
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Сумма (\u20BD)',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Quick amounts
            Wrap(
              spacing: 8,
              children: ([
                if (debt > 0) debt,
                100,
                300,
                500,
                1000,
              ].toSet().toList()..sort()).map((amount) {
                return ActionChip(
                  label: Text('$amount \u20BD'),
                  onPressed: () {
                    _amountController.text = amount.toString();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Pay button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _pay,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.payment),
                label: const Text('Оплатить через ЮKassa'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Безопасная оплата через ЮKassa',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
