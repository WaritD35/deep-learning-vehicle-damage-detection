import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  final String assessmentId;

  const ChatScreen({super.key, required this.assessmentId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: "Hello! I'm your AI assistant. I have reviewed your damage assessment and cost estimates. What would you like to know?",
      isUser: false,
    ));
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();

    try {
      final response = await _apiService.chatWithBot(
        assessmentId: widget.assessmentId,
        message: text,
      );
      setState(() {
        _messages.add(ChatMessage(text: response.response, isUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Connection issue: Make sure your Qwen model server is running! Error details: ${e.toString()}",
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const purple = Color(0xFF5061C8);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 124,
              color: purple,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'AI Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _HeaderIconAction(
                    icon: Icons.support_agent_outlined,
                    tooltip: 'Assistant',
                    onTap: () {},
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -22),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131D33) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Align(
                                alignment:
                                    msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: msg.isUser
                                        ? purple
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.10)
                                            : const Color(0xFFF4F3FB)),
                                    borderRadius: BorderRadius.circular(18).copyWith(
                                      bottomRight: msg.isUser ? const Radius.circular(4) : null,
                                      bottomLeft: !msg.isUser ? const Radius.circular(4) : null,
                                    ),
                                    border: Border.all(
                                      color: msg.isUser
                                          ? purple
                                          : (isDark ? Colors.white12 : Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Text(
                                    msg.text,
                                    style: TextStyle(
                                      color: msg.isUser
                                          ? Colors.white
                                          : (isDark ? Colors.white : Colors.black87),
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: CircularProgressIndicator(),
                        ),
                      Container(
                        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2A3D) : const Color(0xFFF4F3FB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: 'Type your message...',
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF131D33)
                                      : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: const BoxDecoration(
                                color: purple,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.send),
                                color: Colors.white,
                                onPressed: _isLoading ? null : _sendMessage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
