import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/account_provider.dart';
import '../widgets/balance_card.dart';
import 'payment_screen.dart';
import 'messages_screen.dart';

String _fmtDate(String dateStr) {
  try {
    final dt = DateTime.parse(dateStr);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  } catch (_) {
    return dateStr;
  }
}

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

                      // Promise pay banner
                      if (status.hasPromisePay && status.promisePayEnd != null) ...[
                        Card(
                          color: Colors.lightBlue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.handshake_outlined,
                                    color: Colors.blue.shade600, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Обещанный платёж активен',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'до ${_fmtDate(status.promisePayEnd!)}${status.promisePayAmount != null ? " (лимит: ${status.promisePayAmount!.toStringAsFixed(0)} ₽)" : ""}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.blue.shade600,
                                        ),
                                      ),
                                      Text(
                                        'Пополните баланс до окончания срока',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
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

                      // Balance card with status badge
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

                      // Tariff + Balance sparkline (combined card)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tariff header
                              Row(
                                children: [
                                  Icon(Icons.speed, color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text('Тариф',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const Spacer(),
                                  if (status.speedMbit != null)
                                    Chip(
                                      label: Text('${status.speedMbit} Мбит/с'),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                status.tariffName ?? 'Не назначен',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (status.monthlyCost > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${status.monthlyCost.toStringAsFixed(0)} \u20BD/мес',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              // Balance sparkline
                              if (account.history.isNotEmpty) ...[
                                const Divider(height: 24),
                                Text('Динамика баланса',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 80,
                                  child: _BalanceSparkline(
                                    operations: account.history,
                                    currentBalance: status.balance,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info card (contract, address)
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
                              if (status.isBlocked &&
                                  status.blockReason.isNotEmpty)
                                _InfoRow(
                                  label: 'Причина блок.',
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

                      // Recent messages
                      const SizedBox(height: 16),
                      _RecentMessages(),
                    ],
                  ),
      ),
    );
  }
}

/// Recent messages section on dashboard
class _RecentMessages extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final messages = account.messages;
    final colorScheme = Theme.of(context).colorScheme;

    if (messages.isEmpty) return const SizedBox.shrink();

    final recent = messages.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_outlined, color: colorScheme.primary, size: 20),
            const SizedBox(width: 6),
            Text('Сообщения',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        ...recent.map((msg) => _MessageTile(message: msg)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MessagesScreen()),
              );
            },
            child: const Text('Все сообщения'),
          ),
        ),
      ],
    );
  }
}

/// Single message tile — truncated, tappable for full view
class _MessageTile extends StatelessWidget {
  final Map<String, dynamic> message;

  const _MessageTile({required this.message});

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = (message['text'] as String?) ?? '';
    final subject = (message['title'] as String?) ?? '';
    final date = _formatDate(message['date'] as String?);
    final isLong = text.length > 120;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: isLong
            ? () => _showFullMessage(context, subject, text, date)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mail_outline, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      subject.isNotEmpty ? subject : 'Сообщение',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(date,
                      style: TextStyle(
                          fontSize: 11, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ],
              if (isLong) ...[
                const SizedBox(height: 4),
                Text('Нажмите, чтобы прочитать полностью...',
                    style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showFullMessage(
      BuildContext context, String subject, String text, String date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(subject.isNotEmpty ? subject : 'Сообщение')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (date.isNotEmpty)
                  Text(date,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13)),
                if (date.isNotEmpty) const SizedBox(height: 12),
                Text(text, style: const TextStyle(fontSize: 15, height: 1.5)),
              ],
            ),
          ),
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
