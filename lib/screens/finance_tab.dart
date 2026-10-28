import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/config_provider.dart';
import '../models/finance_operation.dart';
import '../theme/app_status_colors.dart';
import '../widgets/error_state.dart';
import 'payment_screen.dart';

/// «2026-10-17T11:29:01.63» → «17.10.2026 11:29»
String _fmtDateTime(dynamic v) {
  final dt = DateTime.tryParse('${v ?? ''}');
  if (dt == null) return '${v ?? ''}';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  String _period = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().loadHistory(period: _period);
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final st = AppStatusColors.of(context);

    // Calculate summary
    double income = 0, expense = 0;
    for (final op in account.history) {
      if (op.amount > 0) {
        income += op.amount;
      } else {
        expense += op.amount;
      }
    }

    // флаги настроек ЛК: выключенное оператором не показываем
    final config = context.watch<ConfigProvider>();
    final historyOn = config.feature('payment_history');
    final promiseOn = config.feature('promise_pay');

    return Scaffold(
      appBar: AppBar(
        title: Text(historyOn ? 'История платежей' : 'Финансы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            tooltip: 'Оплатить',
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PaymentScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // На сколько дней хватит баланса
          if (account.status != null) _BalanceDaysCard(
            balance: account.status!.balance,
            monthlyCost: account.status!.monthlyCost,
            untilDate: account.status!.balanceUntilDate,
          ),

          // Promise pay banner (hide if positive balance)
          if (promiseOn)
          FutureBuilder<Map<String, dynamic>>(
            future: account.getPromisePay(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final pp = snapshot.data!;
              final hasActive = pp['has_active'] == true;
              // Hide if balance > 0 and no active promise pay
              final balance = account.status?.balance ?? 0;
              if (balance > 0 && !hasActive) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  color: hasActive
                      ? st.warningContainer
                      : colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    leading: Icon(
                      Icons.handshake_outlined,
                      color: hasActive ? st.onWarningContainer : colorScheme.primary,
                    ),
                    title: Text(hasActive
                        ? 'Обещанный платёж активен'
                        : 'Обещанный платёж'),
                    subtitle: Text(hasActive
                        ? 'До ${_fmtDateTime(pp['end_date'])}'
                        : '5 дней, 30 \u20BD/день'),
                    trailing: hasActive
                        ? TextButton(
                            onPressed: () async {
                              // build 1039: отмена ОП только после подтверждения
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Отмена обещанного платежа'),
                                  content: const Text(
                                    'Лимит будет снят. Если баланс уйдёт в минус, '
                                    'услуги могут быть заблокированы. Отменить?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Нет'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Отменить ОП'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true || !mounted) return;
                              final err = await account.cancelPromisePay();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          err ?? 'Обещанный платёж отменён')),
                                );
                                setState(() {});
                              }
                            },
                            child: const Text('Отменить'),
                          )
                        : FilledButton.tonal(
                            onPressed: () async {
                              final err = await account.activatePromisePay();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(err ??
                                          'Обещанный платёж активирован')),
                                );
                                setState(() {});
                              }
                            },
                            child: const Text('Активировать'),
                          ),
                  ),
                ),
              );
            },
          ),

          // Period filter
          if (historyOn)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'month', label: Text('Месяц')),
                  ButtonSegment(value: '3month', label: Text('3 мес')),
                  ButtonSegment(value: 'year', label: Text('Год')),
                  ButtonSegment(value: '', label: Text('Все')),
                ],
                selected: {_period},
                onSelectionChanged: (s) {
                  setState(() => _period = s.first);
                  account.loadHistory(period: _period);
                },
              ),
            ),
          ),

          // Summary
          if (historyOn && account.history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _SummaryChip(
                    label: 'Приход',
                    value: '+${income.toStringAsFixed(2)} \u20BD',
                    color: st.success,
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: 'Расход',
                    value: '${expense.toStringAsFixed(2)} \u20BD',
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: 'Операций',
                    value: '${account.historyTotal}',
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // List
          if (!historyOn)
            Expanded(
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PaymentScreen())),
                  icon: const Icon(Icons.add_card),
                  label: const Text('Пополнить'),
                ),
              ),
            )
          else
          Expanded(
            child: account.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (account.historyError != null && account.history.isEmpty)
                    ? ErrorState(
                        message: 'Не удалось загрузить операции',
                        onRetry: () => account.loadHistory(period: _period),
                      )
                    : account.history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 56, color: colorScheme.outline),
                            const SizedBox(height: 12),
                            Text('Операций пока нет',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text('Пополните баланс, чтобы начать',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PaymentScreen()),
                              ),
                              icon: const Icon(Icons.add_card),
                              label: const Text('Пополнить'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            account.loadHistory(period: _period),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: account.history.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 72),
                          itemBuilder: (context, i) {
                            final op = account.history[i];
                            return _OperationTile(op: op);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

String _daysWord(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'день';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'дня';
  return 'дней';
}

/// «Баланса хватит на 23 дня (до 30.11.2026)». Дата — с сервера, тот же расчёт,
/// что в ЛК и карточке клиента (конец последнего оплаченного месяца).
class _BalanceDaysCard extends StatelessWidget {
  final double balance;
  final double monthlyCost;
  final String? untilDate;
  const _BalanceDaysCard(
      {required this.balance, required this.monthlyCost, this.untilDate});

  @override
  Widget build(BuildContext context) {
    if (monthlyCost <= 0) return const SizedBox();
    final cs = Theme.of(context).colorScheme;
    final st = AppStatusColors.of(context);
    final until = DateTime.tryParse(untilDate ?? '');

    String title;
    String subtitle;
    Color color;
    IconData icon;
    if (until != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final days = DateTime(until.year, until.month, until.day)
              .difference(today)
              .inDays +
          1;
      String two(int n) => n.toString().padLeft(2, '0');
      title = 'Баланса хватит на $days ${_daysWord(days)}';
      subtitle = 'До ${two(until.day)}.${two(until.month)}.${until.year}';
      color = days <= 3 ? st.warning : st.success;
      icon = Icons.event_available_outlined;
    } else if (balance < monthlyCost) {
      final need = (monthlyCost - balance).ceil();
      title = 'Не хватает на следующее списание';
      subtitle = 'Пополните баланс на $need ₽';
      color = cs.error;
      icon = Icons.event_busy_outlined;
    } else {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title,
              style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          subtitle: Text(
              '$subtitle · ${monthlyCost.toStringAsFixed(0)} ₽/мес'),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(
                  value,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: color, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  final FinanceOperation op;
  const _OperationTile({required this.op});

  @override
  Widget build(BuildContext context) {
    final isIncome = op.isIncome;
    final st = AppStatusColors.of(context);
    final color = isIncome ? st.success : Theme.of(context).colorScheme.error;
    final sign = isIncome ? '+' : '';

    // Parse date
    String dateStr = '';
    String timeStr = '';
    if (op.date.length >= 16) {
      try {
        final dt = DateTime.parse(op.date);
        dateStr =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
        timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        dateStr = op.date.substring(0, 10);
      }
    }

    final title = op.typeName.isNotEmpty ? op.typeName : 'Операция';
    final subtitle = op.description.isNotEmpty ? op.description : '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '$dateStr  $timeStr${subtitle.isNotEmpty ? '\n$subtitle' : ''}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Text(
        '$sign${op.amount.toStringAsFixed(2)} \u20BD',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color,
          fontSize: 14,
        ),
      ),
      isThreeLine: subtitle.isNotEmpty,
    );
  }
}
