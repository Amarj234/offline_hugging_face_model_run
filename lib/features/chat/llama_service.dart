import 'dart:async';
import 'package:flutter_llama/flutter_llama.dart';
import '../../core/constants.dart';

class LlamaService {
  final FlutterLlama _llama = FlutterLlama.instance;
  final StreamController<String> _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  Future<void> loadModel(String path, {int? threads}) async {
    await _llama.loadModel(
      LlamaConfig(
        modelPath: path,
        nThreads: threads ?? 4,
        contextSize: 2048,
        useGpu: true,
      ),
    );
  }

  Future<void> stop() async {
    // Current flutter_llama might not have a direct cancel,
    // but we can handle it via GenerationParams if supported.
  }

  Future<void> generateResponse(
    String prompt, {
    double? temperature,
    int? maxTokens,
    double? topP,
  }) async {
    await for (final token in _llama.generateStream(
      GenerationParams(
        prompt: prompt,
        temperature: temperature ?? AppConstants.defaultTemperature,
        maxTokens: maxTokens ?? AppConstants.defaultMaxTokens,
        topP: topP ?? AppConstants.defaultTopP,
      ),
    )) {
      _responseController.add(token);
    }
  }

  Future<void> dispose() async {
    await _responseController.close();
  }
}
