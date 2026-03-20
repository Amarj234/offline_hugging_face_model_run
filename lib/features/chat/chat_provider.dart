import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'llama_service.dart';
import '../models/models_provider.dart';
import '../settings/settings_provider.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

final llamaServiceProvider = Provider((ref) => LlamaService());

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  final llamaService = ref.watch(llamaServiceProvider);
  return ChatNotifier(llamaService, ref);
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final LlamaService _llamaService;
  final Ref _ref;
  StreamSubscription<String>? _responseSubscription;

  ChatNotifier(this._llamaService, this._ref) : super([]);

  Future<void> sendMessage(String text) async {
    // Cancel any previous response listener
    await _responseSubscription?.cancel();

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = [...state, userMessage];

    final assistantMessage = ChatMessage(
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
    );
    state = [...state, assistantMessage];

    final selectedModel = _ref.read(selectedModelProvider);
    if (selectedModel == null) {
      state = [
        ...state.sublist(0, state.length - 1),
        ChatMessage(text: 'Error: No model selected. Please download and select a model first.', isUser: false, timestamp: DateTime.now()),
      ];
      return;
    }

    final settings = _ref.read(settingsProvider);

    try {
      final loaded = await _llamaService.loadModel(selectedModel.path);
      if (!loaded) {
        state = [
          ...state.sublist(0, state.length - 1),
          ChatMessage(text: 'Error: Failed to load model. The file may be corrupted.', isUser: false, timestamp: DateTime.now()),
        ];
        return;
      }

      // Listen for streamed responses (accumulated text)
      _responseSubscription = _llamaService.responseStream.listen((response) {
        if (!mounted) return;
        state = [
          ...state.sublist(0, state.length - 1),
          ChatMessage(text: response, isUser: false, timestamp: assistantMessage.timestamp),
        ];
      });

      await _llamaService.generateResponse(
        text,
        temperature: settings.temperature,
        maxTokens: settings.maxTokens,
        topP: settings.topP,
      );
    } catch (e) {
      if (!mounted) return;
      state = [
        ...state.sublist(0, state.length - 1),
        ChatMessage(text: 'Error: ${e.toString()}', isUser: false, timestamp: DateTime.now()),
      ];
    } finally {
      await _responseSubscription?.cancel();
      _responseSubscription = null;
    }
  }

  void clearChat() {
    state = [];
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    super.dispose();
  }
}
