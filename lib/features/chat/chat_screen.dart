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
      
      // Also scroll if the last message content changed during generation
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
        backgroundColor: (isDark ? AppTheme.background : Colors.white).withOpacity(0.8),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('LLAMA CHAT'),
            if (selectedModel != null)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.2), width: 0.5),
                ),
                child: Text(
                  selectedModel.path.split('/').last,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear Chat',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Chat?'),
                  content: const Text('This will delete all messages in this conversation.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(chatProvider.notifier).clearChat();
                        Navigator.pop(context);
                      },
                      child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Models',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ModelBrowserScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark 
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.background, Color(0xFF161B33)],
              )
            : null,
        ),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 56),
            if (selectedModel == null)
              _NoModelWarning(),
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
}

class _NoModelWarning extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(activeDownloadsProvider);
    final isDownloading = downloads.containsKey(AppConstants.recommendedModelFile);
    final downloadProgress = downloads[AppConstants.recommendedModelFile];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No model loaded. Download a small model to get started!',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: isDownloading 
                      ? SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: downloadProgress?.progress,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    isDownloading 
                        ? '${AppConstants.recommendedModelName} ${downloadProgress?.progressText ?? ""}'
                        : 'Download ${AppConstants.recommendedModelName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: isDownloading ? null : () {
                    ref.read(chatProvider.notifier).downloadRecommendedModel();
                  },
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ModelBrowserScreen()),
                ),
                child: const Text('BROWSE', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surface : Colors.grey[200],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppTheme.accentPrimary : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isModelLoading 
                    ? 'Loading model...' 
                    : 'Generating response...\n(This may take 1-2 minutes on some devices)',
                style: TextStyle(
                  color: isDark ? AppTheme.textSecondary : Colors.black54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            gradient: message.isUser
                ? const LinearGradient(
                    colors: [AppTheme.accentPrimary, AppTheme.accentSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: !message.isUser
                ? (isDark ? AppTheme.surface : Colors.grey[200])
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(24),
              topRight: const Radius.circular(24),
              bottomLeft: Radius.circular(message.isUser ? 24 : 4),
              bottomRight: Radius.circular(message.isUser ? 4 : 24),
            ),
            boxShadow: [
              BoxShadow(
                color: (message.isUser ? AppTheme.accentPrimary : Colors.black).withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: !message.isUser && isDark
                ? Border.all(color: Colors.white.withOpacity(0.05))
                : null,
          ),
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: message.isUser
              ? Text(
                  message.text,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                )
              : MarkdownBody(
                  data: message.text, 
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: isDark ? AppTheme.textPrimary : Colors.black87,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    code: TextStyle(
                      backgroundColor: isDark ? Colors.black26 : Colors.grey[300],
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false, // ✅ remove extra top space
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3, // ✅ prevents extra height
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    isDense: true, // ✅ reduces height
                    hintText: 'Ask Llama anything...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10, // ✅ reduced vertical padding
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (value) {
                    if (value.isNotEmpty) onSend(value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),

            /// Button
            isGenerating
                ? Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.stop_rounded,
                          color: Colors.white),
                      onPressed: onStop,
                      padding: const EdgeInsets.all(10), // ✅ smaller button
                      constraints: const BoxConstraints(),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentPrimary,
                          AppTheme.accentSecondary
                        ],
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white),
                      onPressed: () {
                        if (controller.text.isNotEmpty) {
                          onSend(controller.text);
                        }
                      },
                      padding: const EdgeInsets.all(10), // ✅ smaller button
                      constraints: const BoxConstraints(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
