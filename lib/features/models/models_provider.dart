import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/file_manager.dart';

final localModelsProvider = StateNotifierProvider<LocalModelsNotifier, List<File>>((ref) {
  return LocalModelsNotifier();
});

class LocalModelsNotifier extends StateNotifier<List<File>> {
  LocalModelsNotifier() : super([]) {
    refreshModels();
  }

  Future<void> refreshModels() async {
    final models = await FileManager.getLocalModels();
    state = models;
  }

  Future<void> deleteModel(String filePath) async {
    await FileManager.deleteModel(filePath);
    await refreshModels();
  }
}

final selectedModelProvider = StateProvider<File?>((ref) => null);
