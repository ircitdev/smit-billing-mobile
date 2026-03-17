import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/tariff.dart';

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
      body: ListView(
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
          if (account.tariffs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
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
    );
  }

  Future<void> _switchTariff(Tariff tariff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Смена тарифа'),
        content: Text('Перейти на тариф «${tariff.name}»?'),
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

    final err = await context.read<AccountProvider>().changeTariff(tariff.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Тариф изменён')),
    );
    context.read<AccountProvider>().loadTariffs();
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
