import 'dart:io';

import 'package:test/test.dart';
import '../lib/platform_optimization.dart';
import '../lib/storage_manager.dart';
import '../lib/import_export.dart';

void main() {
  test('Android uses conservative render defaults', () {
    expect(PlatformOptimizationProfile.android.maxConcurrentRenders, 1);
    expect(PlatformOptimizationProfile.android.memoryBudgetMb, lessThan(1024));
  });

  test('Windows allows higher desktop concurrency', () {
    expect(PlatformOptimizationProfile.windows.maxConcurrentRenders, 2);
    expect(PlatformOptimizationProfile.windows.memoryBudgetMb, greaterThan(1024));
  });

  test('storage layout creates project/media/cache/export folders', () async {
    final dir = await Directory.systemTemp.createTemp('asazu_phase9_test_');
    final layout = await StorageLayout.create(dir.path);
    expect(await layout.projects.exists(), isTrue);
    expect(await layout.media.exists(), isTrue);
    expect(await layout.cache.exists(), isTrue);
    expect(await layout.exports.exists(), isTrue);
    await dir.delete(recursive: true);
  });

  test('media importer accepts common ad formats', () async {
    final dir = await Directory.systemTemp.createTemp('asazu_media_test_');
    final source = File('${dir.path}/product image.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final result = await MediaImporter().copyIntoMedia(source, Directory('${dir.path}/media'));
    expect(result.extension, 'jpg');
    expect(await File(result.path).exists(), isTrue);
    await dir.delete(recursive: true);
  });
}
