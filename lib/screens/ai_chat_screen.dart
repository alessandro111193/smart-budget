import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../services/firestore_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _aiService = AiService();
  final _firestoreService = FirestoreService();
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': question});
      _loading = true;
      _controller.clear();
    });

    try {
      // Recupera le spese in modo sicuro
      final expenses = await _firestoreService.streamExpenses().first;
      final now = DateTime.now();
      final thisMonth = expenses.where(
        (e) => e.date.year == now.year && e.date.month == now.month,
      );

      final byCategory = <String, double>{};
      for (final e in thisMonth) {
        byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
      }

      final summary = byCategory.entries
          .map((e) => '${e.key}: €${e.value.toStringAsFixed(0)}')
          .join(', ');

      final answer = await _aiService.askAssistant(question, summary);

      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'ai', 'text': answer});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Errore: ${e.toString()}'});
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _messages.map((m) {
                final isUser = m['role'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Chiedi qualcosa sulle tue spese...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _loading ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
