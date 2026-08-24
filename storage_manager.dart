import 'dart:async';
import 'dart:io';

class StorageLayout {
  final Directory root;
  final Directory projects;
  final Directory media;
  final Directory cache;
  final Directory exports;

  StorageLayout._(this.root, this.projects, this.media, this.cache, this.exports);

  static Future<StorageLayout> create(String rootPath) async {
    final root = Directory(rootPath);
    final projects = Directory('${root.path}${Platform.pathSeparator}projects');
    final media = Directory('${root.path}${Platform.pathSeparator}media');
    final cache = Directory('${root.path}${Platform.pathSeparator}cache');
    final exports = Directory('${root.path}${Platform.pathSeparator}exports');
    for (final d in [root, projects, media, cache, exports]) {
      await d.create(recursive: true);
    }
    return StorageLayout._(root, projects, media, cache, exports);
  }
}

class StorageManager {
  final StorageLayout layout;
  const StorageManager(this.layout);

  Future<File> saveProject(String projectId, String json) async {
    final file = File('${layout.projects.path}${Platform.pathSeparator}$projectId.json');
    await file.writeAsString(json, flush: true);
    return file;
  }

  Future<String> readProject(String projectId) async {
    final file = File('${layout.projects.path}${Platform.pathSeparator}$projectId.json');
    if (!await file.exists()) throw FileSystemException('Project not found', file.path);
    return file.readAsString();
  }

  Future<int> cacheSizeBytes() async => _directorySize(layout.cache);

  Future<int> mediaSizeBytes() async => _directorySize(layout.media);

  Future<int> exportsSizeBytes() async => _directorySize(layout.exports);

  Future<int> clearCache({int keepNewest = 0}) async {
    final entries = await layout.cache.list().where((e) => e is File).toList();
    entries.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    var deleted = 0;
    for (final entity in entries.skip(keepNewest)) {
      deleted += await entity.stat().then((s) => s.size);
      await entity.delete();
    }
    return deleted;
  }

  Future<int> freeSpaceBytes() async {
    // dart:io does not expose filesystem free-space portably; -1 means unknown.
    return -1;
  }

  Future<int> _directorySize(Directory directory) async {
    var total = 0;
    if (!await directory.exists()) return 0;
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}
