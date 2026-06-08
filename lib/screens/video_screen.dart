import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/video_object.dart';
import 'payment_screen.dart';
import 'video_player_screen.dart';

/// Экран «Видеонаблюдение» (Фаза 6, mobile).
/// Объекты абонента, камеры, подписки, статус проекта, баланс видео-счёта.
/// Источник: GET /mobile-api/v1/video/objects
class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  bool _loading = true;
  String? _error;
  List<VideoObjectModel> _objects = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.get('/video/objects');
      final items = ((data['items'] ?? []) as List)
          .map((e) => VideoObjectModel.fromJson(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _objects = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить данные';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Видеонаблюдение')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _centered(
        icon: Icons.cloud_off,
        title: _error!,
        action: FilledButton.tonal(onPressed: _load, child: const Text('Повторить')),
      );
    }
    if (_objects.isEmpty) {
      return _centered(
        icon: Icons.videocam_off_outlined,
        title: 'Объекты видеонаблюдения не подключены',
        subtitle: 'Хотите установить видеонаблюдение «под ключ»?\nОбратитесь в поддержку.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _objects.map((o) => _ObjectCard(object: o, onPay: () => _pay(o))).toList(),
    );
  }

  Future<void> _pay(VideoObjectModel o) async {
    // Пополнение пока идёт на основной лицевой счёт (отдельное пополнение
    // видео-счёта требует доработки платёжного шлюза). Честно предупреждаем,
    // чтобы абонент не ждал, что деньги попадут именно на видео-счёт.
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пополнение счёта'),
        content: const Text(
          'Пополнение выполняется на основной лицевой счёт. '
          'Если видеонаблюдение тарифицируется с отдельного счёта, '
          'для зачисления именно на него обратитесь в поддержку.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentScreen()),
    );
  }

  Widget _centered({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      // ListView, чтобы RefreshIndicator работал и на пустом состоянии
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Icon(icon, size: 64, color: cs.outline),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 20),
          Center(child: action),
        ],
      ],
    );
  }
}

class _ObjectCard extends StatelessWidget {
  final VideoObjectModel object;
  final VoidCallback onPay;

  const _ObjectCard({required this.object, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final balance = object.accountBalance;
    final negative = balance != null && balance < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок объекта + бейдж блокировки
            Row(
              children: [
                Icon(Icons.videocam,
                    color: object.camerasBlocked ? cs.error : cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(object.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        [object.type, if (object.address.isNotEmpty) object.address]
                            .join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (object.camerasBlocked)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Заблок.',
                        style: TextStyle(
                            fontSize: 12, color: cs.onErrorContainer)),
                  ),
              ],
            ),

            // Активный проект (если есть)
            if (object.projectTitle != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.engineering_outlined, size: 18, color: cs.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${object.projectTitle} · ${object.projectStatus ?? ''}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            ],

            const Divider(height: 24),

            // Камеры
            Row(
              children: [
                Icon(Icons.camera_alt_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text('Камеры: ${object.camerasCount}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            if (object.cameras.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: object.cameras
                    .map((c) => _CameraChip(camera: c))
                    .toList(),
              ),
            ],

            // Подписки
            if (object.subscriptions.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...object.subscriptions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.sync, size: 16, color: cs.secondary),
                        const SizedBox(width: 6),
                        Expanded(child: Text(s.type)),
                        Text('${s.price.toStringAsFixed(0)} ₽/мес',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )),
            ],

            // Баланс видео-счёта + кнопка пополнить
            if (balance != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 18, color: negative ? cs.error : cs.primary),
                  const SizedBox(width: 6),
                  Text('Счёт видео: ',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text('${balance.toStringAsFixed(2)} ₽',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: negative ? cs.error : cs.primary)),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: onPay,
                    child: const Text('Пополнить'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Чип камеры. Если поток доступен (canView + streamUrl) — кликабелен,
/// открывает WebRTC-плеер go2rtc. Иначе показывает причину недоступности.
class _CameraChip extends StatelessWidget {
  final VideoCameraModel camera;

  const _CameraChip({required this.camera});

  bool get _viewable => camera.canView && camera.streamUrl.isNotEmpty;

  void _open(BuildContext context) {
    if (_viewable) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            streamUrl: camera.streamUrl,
            title: camera.label,
          ),
        ),
      );
    } else {
      final reason = !camera.active
          ? 'Камера отключена'
          : 'Просмотр недоступен (нет потока или объект заблокирован)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _viewable
        ? cs.primary
        : (camera.active ? cs.outline : cs.outline);
    return Semantics(
      button: true,
      label: '${camera.label}: '
          '${_viewable ? "смотреть" : (camera.active ? "просмотр недоступен" : "отключена")}',
      child: ActionChip(
        visualDensity: VisualDensity.compact,
        onPressed: () => _open(context),
        avatar: Icon(
          _viewable
              ? Icons.play_circle_fill
              : (camera.active ? Icons.videocam_off : Icons.block),
          size: 16,
          color: color,
        ),
        label: Text(camera.label, style: const TextStyle(fontSize: 12)),
        side: _viewable
            ? BorderSide(color: cs.primary.withValues(alpha: 0.5))
            : null,
      ),
    );
  }
}
