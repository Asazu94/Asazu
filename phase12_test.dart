import 'dart:io';

import 'package:test/test.dart';
import '../lib/studio_runtime.dart';

void main() {
  test('StudioConfig initializes workspace folders', () async {
    final root = await Directory.systemTemp.createTemp('asazu-phase12-');
    final config = StudioConfig(workspace: root);
    await config.initialize();
    expect(await config.projects.exists(), isTrue);
    expect(await config.media.exists(), isTrue);
    expect(await config.exports.exists(), isTrue);
    expect(await config.cache.exists(), isTrue);
    expect(await config.backups.exists(), isTrue);
    await root.delete(recursive: true);
  });

  test('StudioGenerationState starts idle', () {
    expect(StudioGenerationState.idle.status, StudioStatus.idle);
    expect(StudioGenerationState.idle.progress, 0);
  });

  test('Session manifest is valid JSON', () {
    final manifest = StudioSessionManifest(projectId: 'demo', createdAt: DateTime.utc(2026, 1, 1), appVersion: '0.12.0');
    expect(manifest.encode(), contains('"projectId": "demo"'));
  });
}
