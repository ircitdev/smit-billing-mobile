import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/tariff.dart';
import '../widgets/error_state.dart';

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().loadTariffs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final status = account.status;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Тарифы и услуги')),
      body: RefreshIndicator(
        onRefresh: () => account.loadTariffs(),
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current tariff
          if (status != null) ...[
            Card(
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Текущий тариф',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status.tariffName ?? 'Не назначен',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                    ),
                    if (status.monthlyCost > 0)
                      Text(
                        '${status.monthlyCost.toStringAsFixed(0)} ₽/мес',
                        style: TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Доступные тарифы',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
          ],

          // Tariff list
          if (account.tariffsError != null && account.tariffs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ErrorState(
                message: 'Не удалось загрузить тарифы',
                onRetry: () => account.loadTariffs(),
              ),
            )
          else if (!account.tariffsLoaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (account.tariffs.where((t) => !t.isCurrent).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Других тарифов нет',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
            )
          else
            ...account.tariffs
                .where((t) => !t.isCurrent)
                .map((t) => _TariffCard(
                      tariff: t,
                      onSwitch: () => _switchTariff(t),
                    )),
        ],
        ),
      ),
    );
  }

  Future<void> _switchTariff(Tariff tariff) async {
    final account = context.read<AccountProvider>();
    final status = account.status;
    final currentCost = status?.monthlyCost ?? 0;
    final newCost = tariff.monthlyCost;
    final balance = status?.balance ?? 0;
    final notEnough = balance < newCost;
    final cs = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Смена тарифа'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Перейти на тариф «${tariff.name}»?'),
            const SizedBox(height: 14),
            _dlgRow('Текущий тариф', status?.tariffName ?? '—'),
            if (currentCost > 0)
              _dlgRow('Текущая плата', '${currentCost.toStringAsFixed(0)} ₽/мес'),
            const Divider(height: 18),
            _dlgRow('Новый тариф', tariff.name, bold: true),
            if (newCost > 0)
              _dlgRow('Новая плата', '${newCost.toStringAsFixed(0)} ₽/мес', bold: true),
            const SizedBox(height: 10),
            Text(
              'Изменение вступит в силу со следующего расчётного периода. '
              'Текущий баланс: ${balance.toStringAsFixed(2)} ₽.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            if (notEnough) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, size: 18, color: cs.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'На счету меньше месячной платы нового тарифа — '
                      'возможна блокировка. Рекомендуем пополнить баланс.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: cs.error,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final err = await account.changeTariff(tariff.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Тариф изменён')),
    );
    account.loadTariffs();
  }

  Widget _dlgRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _TariffCard extends StatelessWidget {
  final Tariff tariff;
  final VoidCallback onSwitch;

  const _TariffCard({required this.tariff, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(tariff.name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tariff.monthlyCost > 0)
              Text('${tariff.monthlyCost.toStringAsFixed(0)} ₽/мес'),
            if (tariff.speedMbit != null) Text('${tariff.speedMbit} Мбит/с'),
            if (tariff.description.isNotEmpty)
              Text(
                tariff.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: tariff.canSwitch
            ? FilledButton.tonal(
                onPressed: onSwitch,
                child: const Text('Перейти'),
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}
