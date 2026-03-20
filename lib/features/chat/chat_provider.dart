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

  ChatNotifier(this._llamaService, this._ref) : super([]);

  Future<void> sendMessage(String text) async {
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
      state = state.sublist(0, state.length - 1); // remove empty assistant message
      state = [...state, ChatMessage(text: 'Error: No model selected', isUser: false, timestamp: DateTime.now())];
      return;
    }

    final settings = _ref.read(settingsProvider);
    
    try {
      await _llamaService.loadModel(selectedModel.path);
      
      _llamaService.responseStream.listen((response) {
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
      state = [
        ...state.sublist(0, state.length - 1),
        ChatMessage(text: 'Error: ${e.toString()}', isUser: false, timestamp: DateTime.now()),
      ];
    }
  }

  void clearChat() {
    state = [];
  }
}
