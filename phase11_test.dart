import 'dart:io';

import 'package:test/test.dart';
import '../lib/final_hardening.dart';
import '../lib/scene_builder.dart';

void main() {
  test('validator rejects empty projects', () {
    const project = SceneProject(id: 'x', title: 'x', width: 1080, height: 1920, fps: 30, scenes: []);
    expect(const ProjectValidator().validate(project).isValid, isFalse);
  });

  test('backup writes project atomically', () async {
    final dir = await Directory.systemTemp.createTemp('asazu-backup-');
    const project = SceneProject(id: 'demo', title: 'Demo', width: 1080, height: 1920, fps: 30, scenes: []);
    final file = await const ProjectBackupManager().backup(project, dir);
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), contains('"demo"'));
    await dir.delete(recursive: true);
  });

  test('storage guard handles accessible directory', () async {
    final dir = await Directory.systemTemp.createTemp('asazu-storage-');
    expect(await const StorageGuard().hasEnoughSpace(dir, 100), isTrue);
    await dir.delete(recursive: true);
  });
}
