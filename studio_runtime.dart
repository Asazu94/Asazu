import 'dart:convert';
import 'dart:io';
import 'import_export.dart';

import 'final_hardening.dart';
import 'one_click_ai_ad.dart';
import 'scene_builder.dart';

/// Phase 12: production runtime integration layer.
/// Keeps UI/platform code separate from the existing AI/render pipeline.
enum StudioStatus { idle, preparing, generating, rendering, completed, failed }

class StudioConfig {
  final Directory workspace;
  final Directory projects;
  final Directory media;
  final Directory exports;
  final Directory cache;
  final Directory backups;
  final String ffmpegPath;

  StudioConfig({required this.workspace, String? ffmpegPath})
      : projects = Directory('${workspace.path}${Platform.pathSeparator}projects'),
        media = Directory('${workspace.path}${Platform.pathSeparator}media'),
        exports = Directory('${workspace.path}${Platform.pathSeparator}exports'),
        cache = Directory('${workspace.path}${Platform.pathSeparator}cache'),
        backups = Directory('${workspace.path}${Platform.pathSeparator}backups'),
        ffmpegPath = ffmpegPath ?? 'ffmpeg';

  Future<void> initialize() async {
    for (final dir in [workspace, projects, media, exports, cache, backups]) {
      await dir.create(recursive: true);
    }
  }
}

class StudioHealth {
  final bool workspaceReady;
  final bool ffmpegAvailable;
  final List<String> warnings;

  const StudioHealth({required this.workspaceReady, required this.ffmpegAvailable, this.warnings = const []});

  bool get ready => workspaceReady && ffmpegAvailable;
}

class StudioRuntime {
  final StudioConfig config;
  final FfmpegRenderEngine renderer;

  const StudioRuntime({required this.config, this.renderer = const FfmpegRenderEngine()});

  Future<StudioHealth> healthCheck() async {
    final warnings = <String>[];
    var workspaceReady = true;
    try {
      await config.initialize();
    } catch (e) {
      workspaceReady = false;
      warnings.add('Workspace unavailable: $e');
    }

    bool ffmpegAvailable = false;
    try {
      ffmpegAvailable = await renderer.isAvailable();
    } catch (e) {
      warnings.add('FFmpeg check failed: $e');
    }
    if (!ffmpegAvailable) warnings.add('FFmpeg is not available. Rendering will not work until it is installed/configured.');
    return StudioHealth(workspaceReady: workspaceReady, ffmpegAvailable: ffmpegAvailable, warnings: List.unmodifiable(warnings));
  }
}

class StudioProjectStore {
  final StudioConfig config;
  final ProjectJsonCodec codec;
  final ProjectBackupManager backups;
  const StudioProjectStore({required this.config, this.codec = const ProjectJsonCodec(), this.backups = const ProjectBackupManager()});

  File projectFile(String projectId) {
    final safe = projectId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('${config.projects.path}${Platform.pathSeparator}$safe.json');
  }

  Future<File> save(SceneProject project, {bool createBackup = true}) async {
    await config.initialize();
    if (createBackup && await projectFile(project.id).exists()) {
      await backups.backup(project, config.backups);
    }
    final file = projectFile(project.id);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(codec.encode(project), flush: true);
    if (await file.exists()) await file.delete();
    return temp.rename(file.path);
  }

  Future<List<File>> listProjects() async {
    await config.initialize();
    return config.projects
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList();
  }
}

class StudioGenerationState {
  final StudioStatus status;
  final double progress;
  final String stage;
  final String message;
  final String? outputPath;
  final String? error;

  const StudioGenerationState({required this.status, required this.progress, required this.stage, required this.message, this.outputPath, this.error});

  static const idle = StudioGenerationState(status: StudioStatus.idle, progress: 0, stage: 'idle', message: 'Ready');
}

class StudioGenerationController {
  final OneClickAiAd pipeline;
  StudioGenerationState state = StudioGenerationState.idle;

  StudioGenerationController({OneClickAiAd? pipeline}) : pipeline = pipeline ?? const OneClickAiAd();

  Future<OneClickAdResult> generate(OneClickAdInput input) async {
    _set(StudioStatus.preparing, 0.02, 'prepare', 'Preparing advertisement');
    try {
      final result = await pipeline.generate(input, onProgress: (p) {
        final status = p.stage == 'render' ? StudioStatus.rendering : StudioStatus.generating;
        _set(status, p.fraction, p.stage, p.message);
      });
      if (result.success) {
        _set(StudioStatus.completed, 1, 'complete', 'Advertisement completed', outputPath: result.outputPath);
      } else {
        _set(StudioStatus.failed, 1, 'failed', 'Advertisement failed', error: result.render.error);
      }
      return result;
    } catch (e) {
      _set(StudioStatus.failed, 1, 'failed', 'Unexpected error', error: '$e');
      rethrow;
    }
  }

  void _set(StudioStatus status, double progress, String stage, String message, {String? outputPath, String? error}) {
    state = StudioGenerationState(status: status, progress: progress.clamp(0, 1).toDouble(), stage: stage, message: message, outputPath: outputPath, error: error);
  }
}

class StudioSessionManifest {
  final String projectId;
  final DateTime createdAt;
  final String appVersion;
  final String? outputPath;

  const StudioSessionManifest({required this.projectId, required this.createdAt, required this.appVersion, this.outputPath});

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'projectId': projectId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'outputPath': outputPath,
  });
}
