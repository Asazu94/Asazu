import 'dart:convert';
import 'dart:io';

import 'import_export.dart';
import 'render_engine.dart';
import 'scene_builder.dart';

class ProjectValidationIssue {
  final String code;
  final String message;
  const ProjectValidationIssue(this.code, this.message);
  @override
  String toString() => '$code: $message';
}

class ProjectValidationResult {
  final List<ProjectValidationIssue> issues;
  const ProjectValidationResult(this.issues);
  bool get isValid => issues.isEmpty;
}

class ProjectValidator {
  const ProjectValidator();

  ProjectValidationResult validate(SceneProject project) {
    final issues = <ProjectValidationIssue>[];
    if (project.id.trim().isEmpty) issues.add(const ProjectValidationIssue('PROJECT_ID', 'Project id is empty.'));
    if (project.width <= 0 || project.height <= 0) issues.add(const ProjectValidationIssue('DIMENSIONS', 'Project dimensions must be positive.'));
    if (project.fps <= 0) issues.add(const ProjectValidationIssue('FPS', 'FPS must be positive.'));
    if (project.scenes.isEmpty) issues.add(const ProjectValidationIssue('NO_SCENES', 'Project contains no scenes.'));
    for (final scene in project.scenes) {
      if (scene.duration <= 0) issues.add(ProjectValidationIssue('SCENE_DURATION', 'Scene ${scene.id} has invalid duration.'));
      for (final asset in scene.assets) {
        if (asset.source.trim().isEmpty && asset.type != 'background') {
          issues.add(ProjectValidationIssue('ASSET_SOURCE', 'Scene ${scene.id} has an empty ${asset.type} asset source.'));
        }
      }
    }
    return ProjectValidationResult(List.unmodifiable(issues));
  }
}

class RenderRetryPolicy {
  final int maxAttempts;
  final Duration delay;
  const RenderRetryPolicy({this.maxAttempts = 2, this.delay = const Duration(milliseconds: 500)})
      : assert(maxAttempts >= 1);
}

class SafeRenderEngine implements RenderEngine {
  final RenderEngine delegate;
  final ProjectValidator validator;
  final RenderRetryPolicy retryPolicy;

  const SafeRenderEngine({required this.delegate, this.validator = const ProjectValidator(), this.retryPolicy = const RenderRetryPolicy()});

  @override
  Future<bool> isAvailable() => delegate.isAvailable();

  @override
  Future<RenderResult> render(RenderRequest request, {void Function(RenderProgress progress)? onProgress}) async {
    final validation = validator.validate(request.project);
    if (!validation.isValid) {
      return RenderResult(status: RenderStatus.failed, outputPath: request.outputPath,
          error: validation.issues.map((e) => e.toString()).join('; '));
    }
    RenderResult? last;
    for (var attempt = 1; attempt <= retryPolicy.maxAttempts; attempt++) {
      try {
        last = await delegate.render(request, onProgress: onProgress);
        if (last.status == RenderStatus.completed) return last;
      } catch (error) {
        last = RenderResult(status: RenderStatus.failed, outputPath: request.outputPath, error: '$error');
      }
      if (attempt < retryPolicy.maxAttempts) await Future<void>.delayed(retryPolicy.delay);
    }
    return last ?? RenderResult(status: RenderStatus.failed, outputPath: request.outputPath, error: 'Render failed.');
  }
}

class ProjectBackupManager {
  final ProjectJsonCodec codec;
  const ProjectBackupManager({this.codec = const ProjectJsonCodec()});

  Future<File> backup(SceneProject project, Directory backupDirectory) async {
    await backupDirectory.create(recursive: true);
    final safeId = project.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[^0-9TZ-]'), '');
    final target = File('${backupDirectory.path}${Platform.pathSeparator}$safeId-$stamp.json');
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(codec.encode(project), flush: true);
    await temp.rename(target.path);
    return target;
  }
}

class RenderDiagnostics {
  final DateTime startedAt;
  final DateTime finishedAt;
  final RenderStatus status;
  final String outputPath;
  final String? error;
  final int outputBytes;

  const RenderDiagnostics({required this.startedAt, required this.finishedAt, required this.status,
      required this.outputPath, this.error, this.outputBytes = 0});

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    'durationMs': finishedAt.difference(startedAt).inMilliseconds,
    'status': status.name,
    'outputPath': outputPath,
    'outputBytes': outputBytes,
    'error': error,
  };

  Future<File> write(File file) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(const JsonEncoder.withIndent('  ').convert(toJson()), flush: true);
    await temp.rename(file.path);
    return file;
  }
}

class StorageGuard {
  const StorageGuard();

  Future<bool> hasEnoughSpace(Directory directory, int requiredBytes) async {
    // Directory.stat() is portable but does not expose free disk space in Dart IO.
    // This guard therefore validates the requested size and directory accessibility;
    // platform-specific free-space APIs can be plugged in later.
    if (requiredBytes < 0) return false;
    try {
      await directory.create(recursive: true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
