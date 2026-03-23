import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'chat_provider.dart';
import '../models/models_provider.dart';
import '../models/model_browser_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
    ref.listen(chatProvider, (previous, next) {
      final messagesChanged = previous?.messages.length != next.messages.length;
      final generatingChanged = previous?.isGenerating != next.isGenerating;
      
      bool contentChanged = false;
      if (next.isGenerating && next.messages.isNotEmpty && previous?.messages.isNotEmpty == true) {
        contentChanged = next.messages.last.text != previous!.messages.last.text;
      }

      if (messagesChanged || generatingChanged || contentChanged) {
        _scrollToBottom();
      }
    });

    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final selectedModel = ref.watch(selectedModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: (isDark ? AppTheme.background : Colors.white).withOpacity(0.8),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.borderSubtle : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AI CHAT OFFLINE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (selectedModel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  selectedModel.path.split('/').last,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.accentPrimary.withOpacity(0.8),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 22),
            onPressed: () => _showClearChatDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ModelBrowserScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.background : const Color(0xFFF8FAFC),
          gradient: isDark 
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.background, Color(0xFF161B22)],
              )
            : null,
        ),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 56),
            if (selectedModel == null)
              const _NoModelWarning(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: messages.length + (chatState.isGenerating || chatState.isModelLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length) {
                    return _ThinkingBubble(isModelLoading: chatState.isModelLoading);
                  }
                  final message = messages[index];
                  return _MessageBubble(message: message);
                },
              ),
            ),
            _ChatInput(
              controller: _controller,
              isGenerating: chatState.isGenerating,
              onStop: () => ref.read(chatProvider.notifier).stopGeneration(),
              onSend: (text) {
                ref.read(chatProvider.notifier).sendMessage(text);
                _controller.clear();
                _scrollToBottom();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Clear conversation?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18,color: Colors.white)),
        content: const Text(
          'This will delete all messages in this session. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatProvider.notifier).clearChat();
              Navigator.pop(context);
            },
            child: const Text('CLEAR ALL', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _NoModelWarning extends ConsumerWidget {
  const _NoModelWarning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(activeDownloadsProvider);
    final isDownloading = downloads.containsKey(AppConstants.recommendedModelFile);
    final downloadProgress = downloads[AppConstants.recommendedModelFile];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Start by downloading a lightweight model optimized for your device.',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isDownloading ? null : () {
                    ref.read(chatProvider.notifier).downloadRecommendedModel();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: isDownloading 
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Text(downloadProgress?.progressText ?? "Downloading...", style: const TextStyle(fontSize: 12)),
                          ],
                        )
                      : Text('Download ${AppConstants.recommendedModelName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ModelBrowserScreen()),
                ),
                child: const Text('BROWSE'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  final bool isModelLoading;
  const _ThinkingBubble({required this.isModelLoading});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surface : Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: isDark ? AppTheme.borderSubtle : Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentPrimary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isModelLoading ? 'System: Loading Engine' : 'Assistant: Thinking',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isModelLoading 
                    ? 'Preparing the neural weights...' 
                    : 'The model is generating a response. This typically takes 1-2 minutes on budget hardware.',
                style: TextStyle(color: isDark ? AppTheme.textSecondary : Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: message.isUser
                    ? const LinearGradient(
                        colors: [AppTheme.accentPrimary, Color(0xFF4F46E5)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      )
                    : null,
                color: !message.isUser ? (isDark ? AppTheme.surface : Colors.white) : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 20),
                ),
                border: !message.isUser 
                    ? Border.all(color: isDark ? AppTheme.borderSubtle : Colors.black.withOpacity(0.05))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10, offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
              child: message.isUser
                  ? Text(
                      message.text,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                    )
                  : MarkdownBody(
                      data: message.text, 
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: isDark ? AppTheme.textPrimary : Colors.black87, fontSize: 15, height: 1.6),
                        code: TextStyle(
                          backgroundColor: isDark ? Colors.black26 : Colors.grey[200],
                          fontFamily: 'monospace', fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: isDark ? Colors.black45 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? AppTheme.borderSubtle : Colors.black12),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                _formatTime(message.timestamp),
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onStop;
  final Function(String) onSend;

  const _ChatInput({
    required this.controller,
    required this.isGenerating,
    required this.onStop,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.background : Colors.white).withOpacity(0.95),
        border: Border(
          top: BorderSide(color: isDark ? AppTheme.borderSubtle : Colors.black.withOpacity(0.05), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? AppTheme.borderSubtle : Colors.black12),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Type your message...',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    fillColor: Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: isGenerating ? _ControlBtn(onPressed: onStop, icon: Icons.stop_rounded, color: Colors.redAccent)
                                 : _ControlBtn(onPressed: () {
                                     if (controller.text.trim().isNotEmpty) onSend(controller.text.trim());
                                   }, icon: Icons.arrow_upward_rounded, color: AppTheme.accentPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color color;
  const _ControlBtn({required this.onPressed, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
