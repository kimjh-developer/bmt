import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileUtils {
  static late String documentsDirPath;

  static Future<void> init() async {
    final docDir = await getApplicationDocumentsDirectory();
    documentsDirPath = docDir.path;
  }

  static Future<String> saveImageToDocuments(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) return sourcePath; // Fallback if file not found

    final fileName = p.basename(sourcePath);
    // Add timestamp to filename to ensure uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueFileName = '${timestamp}_$fileName';
    
    final savedImage = await file.copy('$documentsDirPath/$uniqueFileName');
    return uniqueFileName;
  }

  static String getFullImagePath(String savedPath) {
    // If it looks like an absolute path (saving mechanism before update)
    if (savedPath.startsWith('/')) {
      final fileName = p.basename(savedPath);
      final newPath = '$documentsDirPath/$fileName';
      if (File(newPath).existsSync()) {
        return newPath;
      }
      return savedPath; // Fallback to original saved path
    } else {
      // New format: just the filename
      return '$documentsDirPath/$savedPath';
    }
  }
}
