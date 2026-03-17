import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/account_provider.dart';
import '../widgets/balance_card.dart';
import 'payment_screen.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final status = account.status;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('СмИТ Биллинг'),
      ),
      body: RefreshIndicator(
        onRefresh: () => account.loadStatus(),
        child: account.isLoading && status == null
            ? const Center(child: CircularProgressIndicator())
            : status == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Не удалось загрузить данные'),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => account.loadStatus(),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Notification banner
                      if (status.notification.isNotEmpty) ...[
                        Card(
                          color: Colors.amber.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber,
                                    color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    status.notification,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.brown),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Welcome
                      Text(
                        'Добро пожаловать, ${status.name}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 12),

                      // Balance card with last payment
                      BalanceCard(
                        balance: status.balance,
                        isBlocked: status.isBlocked,
                        lastPayment: status.lastPayment,
                        onPayPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaymentScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Balance sparkline
                      if (account.history.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Динамика баланса',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 80,
                                  child: _BalanceSparkline(
                                    operations: account.history,
                                    currentBalance: status.balance,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Tariff info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.speed,
                                      color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text('Тариф',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                status.tariffName ?? 'Не назначен',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (status.speedMbit != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                    'Скорость: ${status.speedMbit} Мбит/с'),
                              ],
                              if (status.monthlyCost > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                    'Стоимость: ${status.monthlyCost.toStringAsFixed(0)} \u20BD/мес'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status & info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text('Информация',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _InfoRow(
                                  label: 'Договор',
                                  value: status.contractNumber),
                              _InfoRow(
                                  label: 'Абонент', value: status.name),
                              if (status.address.isNotEmpty)
                                _InfoRow(
                                    label: 'Адрес', value: status.address),
                              _InfoRow(
                                label: 'Статус',
                                value: status.isBlocked
                                    ? 'Заблокирован'
                                    : 'Активен',
                                valueColor: status.isBlocked
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              if (status.isBlocked &&
                                  status.blockReason.isNotEmpty)
                                _InfoRow(
                                  label: 'Причина',
                                  value: status.blockReason,
                                  valueColor: Colors.red,
                                ),
                              if (status.hasPromisePay)
                                _InfoRow(
                                  label: 'Обещ. платёж',
                                  value: 'Активен',
                                  valueColor: Colors.orange,
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Block alert
                      if (status.isBlocked) ...[
                        const SizedBox(height: 16),
                        Card(
                          color: colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.block,
                                    color: colorScheme.onErrorContainer),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Услуги приостановлены. Пополните баланс для возобновления.',
                                    style: TextStyle(
                                        color:
                                            colorScheme.onErrorContainer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _BalanceSparkline extends StatelessWidget {
  final List operations;
  final double currentBalance;
  final Color color;

  const _BalanceSparkline({
    required this.operations,
    required this.currentBalance,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Build balance points from operations (reverse chronological)
    final points = <FlSpot>[];
    double balance = currentBalance;
    points.add(FlSpot(operations.length.toDouble(), balance));

    for (int i = 0; i < operations.length && i < 30; i++) {
      balance -= operations[i].amount;
      points.add(FlSpot((operations.length - i - 1).toDouble(), balance));
    }
    points.sort((a, b) => a.x.compareTo(b.x));

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w500, color: valueColor)),
          ),
        ],
      ),
    );
  }
}
