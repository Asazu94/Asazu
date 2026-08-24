import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'effects.dart';
import 'scene_builder.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Phase 8: real FFmpeg rendering models and engine.

enum RenderPreset { tiktok, reels, shorts, youtubeLandscape, square }

enum RenderStatus { queued, rendering, completed, failed, cancelled }

class RenderProfile {
  final int width;
  final int height;
  final int fps;
  final int videoBitrateKbps;
  final String audioCodec;
  final String videoCodec;

  const RenderProfile({
    required this.width,
    required this.height,
    this.fps = 30,
    this.videoBitrateKbps = 6000,
    this.videoCodec = 'libx264',
    this.audioCodec = 'aac',
  });

  static const vertical = RenderProfile(width: 1080, height: 1920);
  static const landscape = RenderProfile(width: 1920, height: 1080);
  static const square = RenderProfile(width: 1080, height: 1080);

  factory RenderProfile.fromPreset(RenderPreset preset) => switch (preset) {
        RenderPreset.tiktok || RenderPreset.reels || RenderPreset.shorts => vertical,
        RenderPreset.youtubeLandscape => landscape,
        RenderPreset.square => square,
      };
}

class RenderRequest {
  final SceneProject project;
  final String outputPath;
  final RenderProfile profile;
  final String ffmpegPath;
  final String? workingDirectory;
  final bool overwrite;
  final String? musicPath;

  const RenderRequest({
    required this.project,
    required this.outputPath,
    this.profile = RenderProfile.vertical,
    this.ffmpegPath = 'ffmpeg',
    this.workingDirectory,
    this.overwrite = true,
    this.musicPath,
  });
}

class RenderProgress {
  final RenderStatus status;
  final int sceneIndex;
  final int sceneCount;
  final Duration elapsed;
  final Duration? currentPosition;
  final String? message;

  const RenderProgress({
    required this.status,
    this.sceneIndex = 0,
    this.sceneCount = 0,
    this.elapsed = Duration.zero,
    this.currentPosition,
    this.message,
  });

  double get fraction => sceneCount == 0 ? 0 : sceneIndex / sceneCount;
}

class RenderResult {
  final RenderStatus status;
  final String outputPath;
  final Duration duration;
  final String? error;

  const RenderResult({
    required this.status,
    required this.outputPath,
    this.duration = Duration.zero,
    this.error,
  });
}

class FfmpegException implements Exception {
  final String message;
  const FfmpegException(this.message);
  @override
  String toString() => 'FfmpegException: $message';
}

abstract class RenderEngine {
  Future<bool> isAvailable();
  Future<RenderResult> render(
    RenderRequest request, {
    void Function(RenderProgress progress)? onProgress,
  });
}

class FfmpegRenderEngine implements RenderEngine {
  const FfmpegRenderEngine();

  @override
  Future<bool> isAvailable() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final session = await FFmpegKit.execute('-version');
        return ReturnCode.isSuccess(await session.getReturnCode());
      } catch (_) {
        return false;
      }
    }
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<RenderResult> render(
    RenderRequest request, {
    void Function(RenderProgress progress)? onProgress,
  }) async {
    final started = DateTime.now();
    Directory? temp;
    try {
      final output = File(request.outputPath);
      await output.parent.create(recursive: true);
      if (request.overwrite && await output.exists()) await output.delete();

      temp = await Directory.systemTemp.createTemp('asazu_render_');
      final sceneFiles = <String>[];

      for (var i = 0; i < request.project.scenes.length; i++) {
        final scene = request.project.scenes[i];
        onProgress?.call(RenderProgress(
          status: RenderStatus.rendering,
          sceneIndex: i,
          sceneCount: request.project.scenes.length,
          elapsed: DateTime.now().difference(started),
          message: 'Rendering scene ${i + 1}/${request.project.scenes.length}',
        ));
        final scenePath = '${temp.path}${Platform.pathSeparator}scene_$i.mp4';
        await _renderScene(request, scene, scenePath);
        sceneFiles.add(scenePath);
      }

      if (sceneFiles.isEmpty) {
        throw const FfmpegException('Project has no scenes to render.');
      }

      final concatList = File('${temp.path}${Platform.pathSeparator}concat.txt');
      await concatList.writeAsString(
        sceneFiles.map((p) => "file '${p.replaceAll("'", "'\\''")}'").join('\n'),
      );

      final silentOutput = '${temp.path}${Platform.pathSeparator}video.mp4';
      await _run(request.ffmpegPath, [
        '-y', '-f', 'concat', '-safe', '0', '-i', concatList.path,
        '-c', 'copy', silentOutput,
      ], request.workingDirectory);

      if (request.musicPath != null) {
        await _mixMusic(request, silentOutput, request.outputPath);
      } else {
        await File(silentOutput).copy(request.outputPath);
      }

      onProgress?.call(RenderProgress(
        status: RenderStatus.completed,
        sceneIndex: request.project.scenes.length,
        sceneCount: request.project.scenes.length,
        elapsed: DateTime.now().difference(started),
        message: 'Render completed',
      ));
      return RenderResult(
        status: RenderStatus.completed,
        outputPath: request.outputPath,
        duration: DateTime.now().difference(started),
      );
    } catch (e) {
      onProgress?.call(RenderProgress(
        status: RenderStatus.failed,
        sceneCount: request.project.scenes.length,
        elapsed: DateTime.now().difference(started),
        message: e.toString(),
      ));
      return RenderResult(
        status: RenderStatus.failed,
        outputPath: request.outputPath,
        duration: DateTime.now().difference(started),
        error: e.toString(),
      );
    } finally {
      if (temp != null && await temp.exists()) {
        try {
          await temp.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<void> _renderScene(
    RenderRequest request,
    EditableAdScene scene,
    String outputPath,
  ) async {
    final profile = request.profile;
    final asset = _primaryVisualAsset(scene);
    final voice = _asset(scene, 'voice');
    final input = asset?.source;
    final hasImage = input != null && _isImage(input);
    final hasVideo = input != null && _isVideo(input);
    final duration = scene.duration.clamp(0.1, 3600.0).toDouble();

    final args = <String>['-y'];
    if (hasImage) {
      args.addAll(['-loop', '1', '-i', input]);
    } else if (hasVideo) {
      args.addAll(['-stream_loop', '-1', '-i', input]);
    }
    if (voice?.source != null && File(voice!.source!).existsSync()) {
      args.addAll(['-i', voice.source!]);
    }

    final filter = _videoFilter(scene, profile, duration, hasImage || hasVideo);
    if (!hasImage && !hasVideo) {
      args.addAll(['-f', 'lavfi', '-i', 'color=c=${_backgroundColor(scene.background)}:s=${profile.width}x${profile.height}:r=${profile.fps}:d=$duration']);
    }
    args.addAll(['-filter_complex', filter]);
    args.addAll(['-map', '[vout]']);
    if (voice?.source != null && File(voice!.source!).existsSync()) {
      args.addAll(['-map', '1:a:0', '-c:a', profile.audioCodec, '-shortest']);
    } else {
      args.addAll(['-an']);
    }
    args.addAll([
      '-r', '${profile.fps}',
      '-c:v', profile.videoCodec,
      '-b:v', '${profile.videoBitrateKbps}k',
      '-pix_fmt', 'yuv420p',
      '-t', duration.toStringAsFixed(3),
      '-movflags', '+faststart',
      outputPath,
    ]);
    await _run(request.ffmpegPath, args, request.workingDirectory);
  }

  String _videoFilter(
    EditableAdScene scene,
    RenderProfile profile,
    double duration,
    bool hasVisual,
  ) {
    final filters = <String>[];
    final bg = _backgroundColor(scene.background);
    final input = hasVisual ? '[0:v]' : 'color=c=$bg:s=${profile.width}x${profile.height}:r=${profile.fps}:d=$duration';

    if (hasVisual) {
      filters.add('$input scale=${profile.width}:${profile.height}:force_original_aspect_ratio=increase,crop=${profile.width}:${profile.height}');
    } else {
      filters.add(input);
    }

    var zoom = 1.0;
    var blur = 0.0;
    var glow = false;
    for (final effect in scene.effects.where((e) => e.enabled)) {
      switch (effect.type) {
        case EffectType.zoom:
        case EffectType.kenBurns:
          zoom = 1.0 + (effect.intensity.clamp(0, 1) * 0.12);
          break;
        case EffectType.blur:
          blur = effect.intensity.clamp(0, 1) * 8;
          break;
        case EffectType.glow:
          glow = true;
          break;
        default:
          break;
      }
    }
    if (zoom > 1) filters.add('scale=iw*$zoom:ih*$zoom,crop=${profile.width}:${profile.height}');
    if (blur > 0) filters.add('gblur=sigma=$blur');
    if (glow) filters.add('eq=contrast=1.04:saturation=1.06');

    final fadeIn = scene.transitionIn == TransitionType.fade ? 0.35 : 0.0;
    final fadeOut = scene.transitionOut == TransitionType.fade ? 0.35 : 0.0;
    if (fadeIn > 0) filters.add('fade=t=in:st=0:d=$fadeIn');
    if (fadeOut > 0 && duration > fadeOut) filters.add('fade=t=out:st=${duration - fadeOut}:d=$fadeOut');

    final text = _escapeDrawtext(scene.onScreenText);
    if (scene.captions.enabled && text.isNotEmpty) {
      final fontsize = scene.captions.fontSize.clamp(12, 160).round();
      final y = scene.captions.position == 'top' ? 90 : '(h-text_h-100)';
      filters.add("drawtext=text='$text':fontsize=$fontsize:fontcolor=white:borderw=4:bordercolor=black:x=(w-text_w)/2:y=$y");
    }
    filters.add('format=yuv420p');
    return '${filters.join(',')}[vout]';
  }

  Future<void> _mixMusic(RenderRequest request, String video, String output) async {
    final volume = 0.18;
    final hasVoice = request.project.scenes.any(
      (scene) => scene.assets.any((asset) => asset.type == 'voice' && asset.source != null),
    );
    if (hasVoice) {
      await _run(request.ffmpegPath, [
        '-y', '-i', video, '-stream_loop', '-1', '-i', request.musicPath!,
        '-filter_complex', '[1:a]volume=$volume[m];[0:a][m]amix=inputs=2:duration=first:dropout_transition=2[a]',
        '-map', '0:v:0', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-shortest', '-movflags', '+faststart', output,
      ], request.workingDirectory);
    } else {
      await _run(request.ffmpegPath, [
        '-y', '-i', video, '-stream_loop', '-1', '-i', request.musicPath!,
        '-map', '0:v:0', '-map', '1:a:0', '-c:v', 'copy', '-c:a', 'aac', '-shortest', '-movflags', '+faststart', output,
      ], request.workingDirectory);
    }
  }

  Future<void> _run(String executable, List<String> args, String? cwd) async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final command = args.map(_quoteShellArg).join(' ');
        final session = await FFmpegKit.execute(command);
        final code = await session.getReturnCode();
        if (!ReturnCode.isSuccess(code)) {
          final output = (await session.getOutput())?.trim() ?? '';
          throw FfmpegException(output.isEmpty ? 'FFmpeg exited with code $code' : output);
        }
        return;
      } catch (e) {
        if (e is FfmpegException) rethrow;
        throw FfmpegException('Unable to run FFmpeg on mobile: $e');
      }
    }
    ProcessResult result;
    try {
      result = await Process.run(executable, args, workingDirectory: cwd);
    } catch (e) {
      throw FfmpegException('Unable to start FFmpeg: $e');
    }
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      throw FfmpegException(stderr.isEmpty ? 'FFmpeg exited with code ${result.exitCode}' : stderr);
    }
  }

  String _quoteShellArg(String value) => "'${value.replaceAll("'", "'\\''")}'";


  SceneAsset? _primaryVisualAsset(EditableAdScene scene) {
    for (final asset in scene.assets) {
      if (asset.type == 'product' || asset.type == 'image' || asset.type == 'video') return asset;
    }
    return null;
  }

  SceneAsset? _asset(EditableAdScene scene, String type) {
    for (final asset in scene.assets) {
      if (asset.type == type) return asset;
    }
    return null;
  }

  bool _isImage(String path) => RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false).hasMatch(path);
  bool _isVideo(String path) => RegExp(r'\.(mp4|mov|mkv|webm)$', caseSensitive: false).hasMatch(path);

  String _backgroundColor(BackgroundConfig background) {
    if (background.type == BackgroundType.solid) return background.value == 'neutral' ? '0x202020' : background.value;
    if (background.value == 'brand') return '0x111827';
    if (background.value == 'product') return '0x172554';
    return '0x101010';
  }

  String _escapeDrawtext(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll(':', r'\:')
      .replaceAll("'", r"\'")
      .replaceAll('%', r'\%')
      .replaceAll('\n', ' ');
}

/// Small JSON progress utility for future desktop/mobile render workers.
String renderProgressJson(RenderProgress progress) => jsonEncode({
      'status': progress.status.name,
      'sceneIndex': progress.sceneIndex,
      'sceneCount': progress.sceneCount,
      'fraction': progress.fraction,
      'elapsedMs': progress.elapsed.inMilliseconds,
      'currentPositionMs': progress.currentPosition?.inMilliseconds,
      'message': progress.message,
    });
