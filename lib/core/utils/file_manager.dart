import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileManager {
  static const String modelsDirName = 'models';

  static Future<Directory> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(appDir.path, modelsDirName));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  static Future<List<File>> getLocalModels() async {
    final modelsDir = await getModelsDirectory();
    final List<FileSystemEntity> entities = await modelsDir.list().toList();
    return entities
        .whereType<File>()
        .where((file) => file.path.endsWith('.gguf'))
        .toList();
  }

  static Future<void> deleteModel(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String getModelName(String filePath) {
    return p.basename(filePath);
  }

  static Future<String> getModelPath(String fileName) async {
    final modelsDir = await getModelsDirectory();
    return p.join(modelsDir.path, fileName);
  }
}
