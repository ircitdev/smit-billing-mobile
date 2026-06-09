import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/video_object.dart';
import '../services/api_client.dart';
import 'payment_screen.dart';
import 'video_player_screen.dart';

/// Экран «Видеонаблюдение» (mobile).
/// Превью камер с Play, условная кнопка «Пополнить», архив через WebView-мост.
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
      children: _objects
          .map((o) => _ObjectCard(
                object: o,
                onPay: () => _pay(o),
                onArchiveSession: _openArchiveSession,
              ))
          .toList(),
    );
  }

  Future<void> _pay(VideoObjectModel o) async {
    // При клике честно предупреждаем: видео может тарифицироваться с отдельного
    // счёта, но процедура оплаты не отличается (как в ЛК).
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пополнение счёта'),
        content: const Text(
          'Пополнение выполняется на основной лицевой счёт. '
          'Если видеонаблюдение тарифицируется с отдельного счёта, '
          'для зачисления именно на него обратитесь в поддержку. '
          'В остальном процедура оплаты не отличается.',
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

  /// Открыть архив в WebView через мост JWT→сессия.
  /// [cameraId] — таймлайн одной камеры; [objectId]+wall — мультикамера.
  Future<void> _openArchiveSession({int? cameraId, int? objectId, bool wall = false, String title = 'Архив'}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = context.read<AuthProvider>().api;
      final body = wall
          ? {'object_id': objectId, 'wall': true}
          : {'camera_id': cameraId};
      final res = await api.post('/video/archive/session', body);
      if (res['ok'] != true || (res['url'] ?? '').toString().isEmpty) {
        messenger.showSnackBar(SnackBar(
            content: Text(res['error']?.toString() ?? 'Архив недоступен')));
        return;
      }
      // baseUrl = https://rbill.smit34.ru/mobile-api/v1 → host для ЛК-страницы
      final host = ApiClient.baseUrl.replaceFirst('/mobile-api/v1', '');
      final url = '$host${res['url']}';
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(streamUrl: url, title: title),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка архива: $e')));
    }
  }

  Widget _centered({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
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
  final Future<void> Function({int? cameraId, int? objectId, bool wall, String title})
      onArchiveSession;

  const _ObjectCard({
    required this.object,
    required this.onPay,
    required this.onArchiveSession,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final balance = object.accountBalance;
    final negative = balance != null && balance < 0;
    final cams = object.cameras;
    final twoCols = cams.length > 2;

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

            // Камеры — превью-сетка с Play (по 2 в ряд если >2 камер)
            Row(
              children: [
                Icon(Icons.camera_alt_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text('Камеры: ${object.camerasCount}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            if (cams.isNotEmpty) ...[
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: twoCols ? 2 : 1,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: twoCols ? 1.35 : 1.9,
                children: cams
                    .map((c) => _CameraTile(
                          camera: c,
                          onArchive: c.hasArchive
                              ? () => onArchiveSession(
                                  cameraId: c.id, title: 'Архив: ${c.label}')
                              : null,
                        ))
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

            // Архив: подписка есть → кнопка «Смотреть все камеры»; нет → баннер
            const SizedBox(height: 12),
            if (object.hasSubscription && !object.camerasBlocked) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onArchiveSession(
                      objectId: object.id, wall: true, title: 'Архив — все камеры'),
                  icon: const Icon(Icons.grid_view, size: 18),
                  label: const Text('Смотреть архив всех камер'),
                ),
              ),
            ] else if (!object.hasSubscription) ...[
              _ArchivePromo(),
            ],

            // Баланс видео-счёта + условная кнопка «Пополнить»
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
                  // Кнопка только если денег меньше месячного списания
                  if (object.needTopup)
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

/// Плитка камеры с превью (snapshot из ЛК-прокси) и наложенной Play.
class _CameraTile extends StatelessWidget {
  final VideoCameraModel camera;
  final VoidCallback? onArchive;

  const _CameraTile({required this.camera, this.onArchive});

  bool get _viewable => camera.canView && camera.streamUrl.isNotEmpty;

  void _play(BuildContext context) {
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
          ? 'Камера сейчас отключена'
          : 'Просмотр сейчас недоступен. Если объект заблокирован за неоплату — '
              'пополните счёт, либо обратитесь в поддержку.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), duration: const Duration(seconds: 3)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // превью-кадр через ЛК-прокси (go2rtc snapshot). Доступно при canView.
    final previewUrl = _viewable
        ? '${ApiClient.baseUrl.replaceFirst('/mobile-api/v1', '')}/lk/video/preview/${camera.id}/'
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black),
                  if (previewUrl != null)
                    Image.network(
                      previewUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.videocam, color: cs.outline, size: 28),
                      loadingBuilder: (ctx, child, prog) =>
                          prog == null ? child : const Center(
                              child: SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  else
                    Center(
                        child: Icon(
                            camera.active ? Icons.videocam_off : Icons.block,
                            color: cs.outline, size: 28)),
                  // Play overlay
                  if (_viewable)
                    Center(
                      child: Material(
                        color: cs.primary.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _play(context),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.play_arrow, color: Colors.white, size: 26),
                          ),
                        ),
                      ),
                    ),
                  if (!camera.active)
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Выкл.',
                            style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ],
              ),
            ),
            // подпись + кнопка архива
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      camera.resolution.isNotEmpty
                          ? '${camera.label} · ${camera.resolution}'
                          : camera.label,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onArchive != null)
                    InkWell(
                      onTap: onArchive,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.history, size: 18, color: cs.primary),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Баннер преимуществ архива (когда нет подписки) + переход к заказу.
class _ArchivePromo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget item(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: cs.primary, size: 20),
              const SizedBox(width: 6),
              const Text('Архив видеозаписей',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          item('Записи хранятся до 30 дней — пересмотрите любой момент'),
          item('Таймлайн по дням, перемотка по времени'),
          item('Выгрузка фрагмента в один клик'),
          item('Доступ из приложения и личного кабинета'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(
                    'Заявка на подключение архива — напишите в поддержку.')),
              ),
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('Подключить архив'),
            ),
          ),
        ],
      ),
    );
  }
}
