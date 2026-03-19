import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.get('/account/messages');
      setState(() {
        _messages = ((data['items'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _channelChip(String channel) {
    IconData icon;
    Color color;
    String label;
    switch (channel) {
      case 'sms':
        icon = Icons.sms;
        color = Colors.green;
        label = 'SMS';
        break;
      case 'email':
        icon = Icons.email;
        color = Colors.blue;
        label = 'Email';
        break;
      case 'telegram':
        icon = Icons.send;
        color = const Color(0xFF0088CC);
        label = 'TG';
        break;
      case 'push':
        icon = Icons.notifications;
        color = Colors.orange;
        label = 'Push';
        break;
      case 'vk':
        icon = Icons.people;
        color = const Color(0xFF0077FF);
        label = 'VK';
        break;
      default:
        icon = Icons.inbox;
        color = Colors.grey;
        label = 'ЛК';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сообщения')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      Text('Сообщений нет', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final channels = (msg['channels'] as List?)?.cast<String>() ?? ['lk'];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(Icons.mail_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                        ),
                        title: Text(
                          (msg['title'] as String?)?.isNotEmpty == true ? msg['title'] : (msg['text'] ?? ''),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((msg['title'] as String?)?.isNotEmpty == true)
                              Text(msg['text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children: channels.map((c) => _channelChip(c)).toList(),
                            ),
                          ],
                        ),
                        trailing: Text(
                          _formatDate(msg['date']),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
                ),
    );
  }
}
