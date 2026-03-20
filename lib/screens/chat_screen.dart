import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

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
  bool _loading = true;

  static const _keySessionId = 'aida_session_id';
  static const _keySessionTime = 'aida_session_time';
  static const _sessionTtlHours = 24;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_keySessionId);
    final savedTime = prefs.getInt(_keySessionTime) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - savedTime;
    final expired = age > _sessionTtlHours * 3600 * 1000;

    if (savedId != null && !expired) {
      _sessionId = savedId;
      // Try to load history from server
      final api = Provider.of<AuthProvider>(context, listen: false).api;
      try {
        final data = await api.get('/chat/history?session_id=$savedId');
        final messages = data['messages'] as List? ?? [];
        for (final m in messages) {
          _messages.add(_ChatMsg(
            text: m['text'] ?? '',
            isUser: m['is_user'] == true,
            time: DateTime.tryParse(m['time'] ?? '') ?? DateTime.now(),
          ));
        }
        if (data['escalated'] == true) _escalated = true;
      } catch (_) {
        // Server doesn't support history yet — start fresh
      }
    }

    // If no history loaded, show welcome message
    if (_messages.isEmpty) {
      _sessionId = null;
      prefs.remove(_keySessionId);
      _messages.add(_ChatMsg(
        text: 'Здравствуйте! Я AIDA — AI-ассистент СМИТ.\n'
            'Задайте вопрос о тарифах, балансе, услугах или опишите проблему.\n'
            'Если я не смогу помочь — передам вопрос оператору.',
        isUser: false,
        time: DateTime.now(),
      ));
    }

    setState(() => _loading = false);
    _scrollToBottom();
  }

  Future<void> _saveSession() async {
    if (_sessionId == null) return;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_keySessionId, _sessionId!);
    prefs.setInt(_keySessionTime, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

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
      _saveSession();
      final response = data['response'] ?? 'Нет ответа';
      final escalated = data['escalated'] == true;

      setState(() {
        _messages.add(_ChatMsg(
          text: response,
          isUser: false,
          time: DateTime.now(),
        ));
        if (escalated) _escalated = true;
      });
    } on ApiException catch (e) {
      setState(() {
        _messages.add(_ChatMsg(
          text: 'Ошибка: ${e.message}',
          isUser: false,
          time: DateTime.now(),
          isError: true,
        ));
      });
    } catch (_) {
      setState(() {
        _messages.add(_ChatMsg(
          text: 'Не удалось связаться с ассистентом. Попробуйте позже.',
          isUser: false,
          time: DateTime.now(),
          isError: true,
        ));
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
        const SnackBar(content: Text('Опишите проблему перед отправкой оператору')),
      );
      return;
    }

    setState(() => _sending = true);
    final api = Provider.of<AuthProvider>(context, listen: false).api;
    try {
      await api.post('/chat/escalate', {
        'message': text,
        'session_id': _sessionId ?? '',
      });
      _controller.clear();
      setState(() {
        _escalated = true;
        _messages.add(_ChatMsg(
          text: 'Ваш вопрос передан оператору. Ответ придёт в раздел «Поддержка».',
          isUser: false,
          time: DateTime.now(),
        ));
      });
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-ассистент'),
        actions: [
          if (!_escalated)
            IconButton(
              icon: const Icon(Icons.support_agent),
              tooltip: 'Передать оператору',
              onPressed: _escalateManually,
            ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length) {
                  // Typing indicator
                  return _buildTypingIndicator(isDark);
                }
                return _buildBubble(_messages[i], primary, isDark);
              },
            ),
          ),
          // Escalated banner
          if (_escalated)
            Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Вопрос передан оператору',
                      style: TextStyle(color: Colors.green.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          // Input
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
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
                        hintText: 'Задайте вопрос...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _sending ? null : _send,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
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

  Widget _buildBubble(_ChatMsg msg, Color primary, bool isDark) {
    final isUser = msg.isUser;
    final bgColor = msg.isError
        ? Colors.red.shade50
        : isUser
            ? primary.withOpacity(0.85)
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100);
    final textColor = msg.isError
        ? Colors.red.shade900
        : isUser
            ? Colors.white
            : (isDark ? Colors.white : Colors.black87);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: primary.withOpacity(0.15),
                child: Icon(Icons.smart_toy, size: 18, color: primary),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.text, style: TextStyle(color: textColor, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(
                      '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: textColor.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              child: Icon(Icons.smart_toy, size: 18,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: const _TypingDots(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMsg {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isError;

  _ChatMsg({
    required this.text,
    required this.isUser,
    required this.time,
    this.isError = false,
  });
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade500,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}
