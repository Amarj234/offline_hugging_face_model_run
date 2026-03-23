import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_llama/flutter_llama.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('flutter_llama');
  final FlutterLlama llama = FlutterLlama.instance;

  group('FlutterLlama Streaming Fix Verification', () {
    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'loadModel') return true;
        if (methodCall.method == 'generateStreamV2') return null;
        return null;
      });
      
      await llama.loadModel(const LlamaConfig(modelPath: '/test.gguf'));
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('generateStream should correctly yield tokens from EventChannel', () async {
      final List<String> tokens = ['Hello', ' ', 'World'];
      final List<String> received = [];
      final Completer<void> triggerCompleter = Completer<void>();
      
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'loadModel') return true;
        if (methodCall.method == 'generateStreamV2') {
          triggerCompleter.complete();
          return null;
        }
        return null;
      });

      const String streamName = 'flutter_llama/stream';
      
      // Start the stream
      final stream = llama.generateStream(const GenerationParams(prompt: 'Test'));
      
      // Listen to the stream
      final subscription = stream.listen((token) {
        received.add(token);
      });

      // WAIT for the trigger to ensure the listener is attached
      await triggerCompleter.future;

      // Simulate native side sending tokens
      for (final token in tokens) {
        final ByteData? message = const StandardMethodCodec().encodeSuccessEnvelope(token);
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(streamName, message, (_) {});
      }

      // Signal end of stream
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(streamName, null, (_) {});

      // Give some time for the stream to process
      await Future.delayed(Duration.zero);
      
      expect(received, tokens);
      await subscription.cancel();
    });
  });
}
