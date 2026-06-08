import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../theme/app_status_colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMsg> _messages = [];
  String? _sessionId;
  bool _sending = false;
  bool _escalated = false;
  bool _feedbackEnabled = true; // обновляется из /chat/status

  static const _sessionKey = 'chat_session_id';
  static const _sessionExpiresKey = 'chat_session_expires';
  static const _historyKey = 'chat_history';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final api = Provider.of<AuthProvider>(context, listen: false).api;
    try {
      final data = await api.get('/chat/status');
      if (mounted) {
        setState(() {
          _feedbackEnabled = data['feedback_enabled'] != false;
        });
      }
    } catch (_) {
      // если /chat/status недоступен — оставим feedback включённым по умолчанию
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final expires = prefs.getInt(_sessionExpiresKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < expires) {
      _sessionId = prefs.getString(_sessionKey);
      // Restore message history
      final historyJson = prefs.getString(_historyKey);
      if (historyJson != null) {
        try {
          final list = (json.decode(historyJson) as List);
          for (final m in list) {
            final aiIdxRaw = m['aiIdx'];
            final int? aiIdx = (aiIdxRaw is int)
                ? aiIdxRaw
                : (aiIdxRaw is num ? aiIdxRaw.toInt() : null);
            _messages.add(_ChatMsg(
              text: m['text'] ?? '',
              isUser: m['isUser'] == true,
              time: DateTime.tryParse(m['time'] ?? '') ?? DateTime.now(),
              assistantIndex: aiIdx,
              feedback: m['fb'],
            ));
          }
        } catch (_) {}
      }
    } else {
      await prefs.remove(_sessionKey);
      await prefs.remove(_sessionExpiresKey);
      await prefs.remove(_historyKey);
    }
    if (_messages.isEmpty) {
      _messages.add(_ChatMsg(
        text: 'Здравствуйте! Я AI-ассистент SmIT. 😊\nЧем могу помочь?',
        isUser: false,
        time: DateTime.now(),
      ));
    }
    if (mounted) setState(() => _ready = true);
    _scrollToBottom();
  }

  Future<void> _saveSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, id);
    await prefs.setInt(_sessionExpiresKey,
        DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _messages.map((m) => {
      'text': m.text,
      'isUser': m.isUser,
      'time': m.time.toIso8601String(),
      if (m.assistantIndex != null) 'aiIdx': m.assistantIndex,
      if (m.feedback != null) 'fb': m.feedback,
    }).toList();
    await prefs.setString(_historyKey, json.encode(list));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || !_ready) return;

    setState(() {
      _messages.add(_ChatMsg(text: text, isUser: true, time: DateTime.now()));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    final api = Provider.of<AuthProvider>(context, listen: false).api;
    try {
      final data = await api.post('/chat/message', {
        'message': text,
        'session_id': _sessionId ?? '',
        'is_first': _sessionId == null,
      });

      _sessionId = data['session_id'] ?? _sessionId;
      if (_sessionId != null) _saveSession(_sessionId!);
      final response = data['response'] ?? 'Нет ответа';
      final escalated = data['escalated'] == true;
      final aiIdxRaw = data['assistant_index'];
      final int? aiIdx = (aiIdxRaw is int)
          ? aiIdxRaw
          : (aiIdxRaw is num ? aiIdxRaw.toInt() : null);
      if (data['feedback_enabled'] != null) {
        _feedbackEnabled = data['feedback_enabled'] != false;
      }

      setState(() {
        _messages.add(_ChatMsg(
          text: response,
          isUser: false,
          time: DateTime.now(),
          assistantIndex: aiIdx,
        ));
        if (escalated) _escalated = true;
      });
      _saveHistory();
    } on ApiException catch (e) {
      setState(() {
        _messages.add(_ChatMsg(text: 'Ошибка: ${e.message}', isUser: false, time: DateTime.now(), isError: true));
      });
    } catch (_) {
      setState(() {
        _messages.add(_ChatMsg(text: 'Не удалось связаться с ассистентом.', isUser: false, time: DateTime.now(), isError: true));
      });
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _escalateManually() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Опишите проблему')),
      );
      return;
    }
    setState(() => _sending = true);
    final api = Provider.of<AuthProvider>(context, listen: false).api;
    try {
      await api.post('/chat/escalate', {'message': text, 'session_id': _sessionId ?? ''});
      _controller.clear();
      setState(() {
        _escalated = true;
        _messages.add(_ChatMsg(text: 'Вопрос передан оператору. Ответ придёт в «Поддержку».', isUser: false, time: DateTime.now()));
      });
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _sendFeedback(_ChatMsg msg, String rating) async {
    if (_sessionId == null || msg.assistantIndex == null) return;
    final previous = msg.feedback;
    final next = (previous == rating) ? '' : rating; // повторное нажатие = снять
    setState(() {
      msg.feedback = next.isEmpty ? null : next;
    });
    _saveHistory();
    final api = Provider.of<AuthProvider>(context, listen: false).api;
    try {
      await api.post('/chat/feedback', {
        'session_id': _sessionId,
        'message_index': msg.assistantIndex,
        'rating': next,
        'text': '',
      });
    } catch (_) {
      // откат на ошибке
      if (mounted) {
        setState(() { msg.feedback = previous; });
        _saveHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить оценку')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Simple markdown formatting
  List<InlineSpan> _parseMd(String text, Color color) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: TextStyle(color: color, fontSize: 14.5)));
      }
      spans.add(TextSpan(text: m.group(1), style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w700)));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: TextStyle(color: color, fontSize: 14.5)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final st = AppStatusColors.of(context);
    const green = Color(0xFF5BA89D);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: green.withOpacity(0.15),
              child: const Icon(Icons.smart_toy, size: 20, color: green),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI-ассистент', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('онлайн', style: TextStyle(fontSize: 12, color: st.success)),
              ],
            ),
          ],
        ),
        actions: [
          if (!_escalated)
            IconButton(
              icon: const Icon(Icons.support_agent),
              tooltip: 'Оператор',
              onPressed: _escalateManually,
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEFF6F0),
                image: isDark ? null : const DecorationImage(
                  image: NetworkImage('https://storage.googleapis.com/uspeshnyy-projects/smit/billing/app/pattern.jpg'),
                  repeat: ImageRepeat.repeat,
                ),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == _messages.length) return _buildTyping(isDark);
                  return _buildBubble(_messages[i], isDark);
                },
              ),
            ),
          ),
          // Escalated
          if (_escalated)
            Container(
              color: st.successContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: st.onSuccessContainer, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Вопрос передан оператору', style: TextStyle(color: st.onSuccessContainer, fontSize: 13))),
                ],
              ),
            ),
          // Input
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF22262E) : Colors.white,
              border: Border(top: BorderSide(color: isDark ? const Color(0xFF353940) : Colors.grey.shade200)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Сообщение',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2E37) : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: green,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _sending ? null : _send,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.arrow_upward, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMsg msg, bool isDark) {
    final isUser = msg.isUser;
    final st = AppStatusColors.of(context);
    final bgColor = msg.isError
        ? st.dangerContainer
        : isUser
            ? const Color(0xFF5BA89D)
            : (isDark ? const Color(0xFF2A2E37) : const Color(0xFFE8E8ED));
    final textColor = msg.isError
        ? st.onDangerContainer
        : isUser
            ? Colors.white
            : (isDark ? const Color(0xFFD0D3D8) : const Color(0xFF1A1A1A));
    final timeStr = '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: EdgeInsets.only(
          top: 2, bottom: 2,
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(text: TextSpan(children: _parseMd(msg.text, textColor))),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Кнопки 👍 / 👎 показываем только для AI-сообщений с индексом и при разрешении сервера
                if (!isUser && !msg.isError && msg.assistantIndex != null && _feedbackEnabled) ...[
                  _FeedbackButton(
                    icon: Icons.thumb_up_alt_outlined,
                    activeIcon: Icons.thumb_up,
                    active: msg.feedback == 'up',
                    color: textColor,
                    tooltip: 'Полезно',
                    onTap: () => _sendFeedback(msg, 'up'),
                  ),
                  const SizedBox(width: 4),
                  _FeedbackButton(
                    icon: Icons.thumb_down_alt_outlined,
                    activeIcon: Icons.thumb_down,
                    active: msg.feedback == 'down',
                    color: textColor,
                    tooltip: 'Не помогло',
                    onTap: () => _sendFeedback(msg, 'down'),
                  ),
                ],
                const Spacer(),
                Text(timeStr, style: TextStyle(color: textColor.withOpacity(0.45), fontSize: 10.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTyping(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2E37) : const Color(0xFFE8E8ED),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: const _TypingDots(),
      ),
    );
  }
}

class _ChatMsg {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isError;
  // assistantIndex — 0-based индекс среди assistant-сообщений сессии
  // (для отправки POST /chat/feedback с message_index=N). null для user-сообщений.
  final int? assistantIndex;
  // feedback — 'up' | 'down' | null. Локально обновляется при тапе на кнопку.
  String? feedback;
  _ChatMsg({
    required this.text,
    required this.isUser,
    required this.time,
    this.isError = false,
    this.assistantIndex,
    this.feedback,
  });
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _FeedbackButton({
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    // Touch-зона ≥48×48 (a11y) через IconButton с constraints.
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      iconSize: 18,
      icon: Icon(
        active ? activeIcon : icon,
        color: active
            ? Theme.of(context).colorScheme.primary
            : color.withValues(alpha: 0.5),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_ctrl.value + i * 0.2) % 1.0;
          final y = sin(t * pi * 2) * 3;
          return Transform.translate(
            offset: Offset(0, -y.abs()),
            child: Container(
              width: 7, height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color: Colors.grey.shade500, shape: BoxShape.circle),
            ),
          );
        }),
      ),
    );
  }
}
