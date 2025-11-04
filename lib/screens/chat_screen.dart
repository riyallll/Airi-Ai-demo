import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _loading = false;
  late FlutterTts _flutterTts;
  late AnimationController _typingController;
  late AnimationController _micPulseController;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadHistory();

    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    // 🔴 Mic pulse animation
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.9,
      upperBound: 1.2,
    );
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("en-IN");
    await _flutterTts.setSpeechRate(0.45);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('chat_history') ?? '[]';
    final list = jsonDecode(str) as List;
    setState(() {
      _messages
        ..clear()
        ..addAll(list.map((e) => Message.fromJson(e)).toList());
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'chat_history',
      jsonEncode(_messages.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> _startOrStopListening() async {
    if (!_isListening) {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _micPulseController.repeat(reverse: true);

        _speech.listen(
          onResult: (result) async {
            setState(() {
              _controller.text = result.recognizedWords;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            });

            // ✅ When the user finishes speaking, stop mic and send message
            if (result.finalResult) {
              setState(() => _isListening = false);
              _micPulseController.stop();
              await _speech.stop();

              // Optional: Automatically send message
              if (_controller.text.trim().isNotEmpty) {
                await _sendMessage();
              }
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _micPulseController.stop();
      _speech.stop();
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final userMessage = Message(text: text, sender: Sender.user);
    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _loading = true;
    });
    await _saveHistory();

    try {
      final reply = await _api.sendMessage(text);
      final aiMessage = Message(text: reply, sender: Sender.assistant);
      setState(() => _messages.add(aiMessage));
    } catch (e) {
      setState(() => _messages.add(
          Message(text: "❌ Error: ${e.toString()}", sender: Sender.assistant)));
    } finally {
      setState(() => _loading = false);
      await _saveHistory();
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Widget _buildMessageTile(Message m) {
    final isUser = m.sender == Sender.user;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser
        ? const LinearGradient(colors: [Colors.indigo, Colors.indigoAccent])
        : const LinearGradient(colors: [Colors.grey, Colors.blueGrey]);

    return Align(
      alignment: alignment,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          gradient: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
            isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
            isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              offset: const Offset(2, 3),
              blurRadius: 5,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              m.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(m.time),
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
                if (!isUser)
                  IconButton(
                    icon: const Icon(Icons.volume_up,
                        size: 18, color: Colors.white70),
                    tooltip: "Play reply",
                    onPressed: () => _speak(m.text),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    _controller.dispose();
    _typingController.dispose();
    _micPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Airi - Your Voice Chat'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear chat history',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear chat history?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Yes')),
                  ],
                ),
              ) ??
                  false;
              if (ok) {
                setState(() => _messages.clear());
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('chat_history');
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
              child: Text(
                'Say hi 👋 Use mic or type below.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: _buildMessageTile(_messages[i]),
              ),
            ),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Airi is thinking...',
                    style: TextStyle(color: Colors.grey),
                  ),
                  AnimatedBuilder(
                    animation: _typingController,
                    builder: (_, __) {
                      int dotCount = (3 * _typingController.value).floor() + 1;
                      return Text(
                        '.' * dotCount,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12, offset: Offset(0, -1), blurRadius: 4)
                ],
              ),
              child: Row(
                children: [
                  // 🎙️ Animated mic button
                  ScaleTransition(
                    scale: _micPulseController,
                    child: GestureDetector(
                      onTap: _startOrStopListening,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor:
                        _isListening ? Colors.redAccent : Colors.indigo,
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.indigo),
                    onPressed: _loading ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
