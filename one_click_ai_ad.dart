import 'dart:convert';
import 'dart:io';

import 'ai_ad_brain.dart';
import 'import_export.dart';
import 'render_engine.dart';
import 'render_queue.dart';
import 'scene_builder.dart';
import 'voice.dart';

/// Phase 10: the end-to-end One-Click AI Ad pipeline.
///
/// The individual providers are replaceable so a real cloud AI, avatar,
/// TTS or lip-sync service can be plugged in without changing the pipeline.
class OneClickAdInput {
  final ProductInput product;
  final String productImagePath;
  final String outputPath;
  final RenderPreset preset;
  final String ffmpegPath;
  final String? musicPath;
  final String projectId;

  const OneClickAdInput({
    required this.product,
    required this.productImagePath,
    required this.outputPath,
    this.preset = RenderPreset.tiktok,
    this.ffmpegPath = 'ffmpeg',
    this.musicPath,
    this.projectId = 'one-click-ad',
  });
}

class ProductAnalysis {
  final ProductInput product;
  final List<String> sellingPoints;
  final String visualDirection;

  const ProductAnalysis({
    required this.product,
    required this.sellingPoints,
    required this.visualDirection,
  });
}

abstract class ProductAnalyzer {
  Future<ProductAnalysis> analyze(ProductInput product, String imagePath);
}

class LocalProductAnalyzer implements ProductAnalyzer {
  @override
  Future<ProductAnalysis> analyze(ProductInput product, String imagePath) async {
    final points = product.features
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(6)
        .toList();
    return ProductAnalysis(
      product: product,
      sellingPoints: points,
      visualDirection: imagePath.isEmpty
          ? 'Use a clean product-focused visual.'
          : 'Use the supplied product image as the hero visual.',
    );
  }
}

class AvatarOutput {
  final String? mediaPath;
  final String provider;
  const AvatarOutput({this.mediaPath, this.provider = 'none'});
}

abstract class AvatarProvider {
  Future<AvatarOutput> create({required AdBrainResult ad, required String outputDirectory});
}

/// Placeholder provider. It deliberately does not fake an avatar file.
/// A real HeyGen/Synthesia/local avatar provider can implement this interface.
class LocalAvatarProvider implements AvatarProvider {
  @override
  Future<AvatarOutput> create({required AdBrainResult ad, required String outputDirectory}) async =>
      const AvatarOutput(provider: 'local-placeholder');
}

class OneClickProgress {
  final String stage;
  final double fraction;
  final String message;

  const OneClickProgress({required this.stage, required this.fraction, required this.message});
}

class OneClickAdResult {
  final bool success;
  final String outputPath;
  final ProductAnalysis analysis;
  final AdBrainResult ad;
  final SceneProject project;
  final List<LipSyncFrame> lipSyncFrames;
  final AvatarOutput avatar;
  final RenderResult render;
  final String manifestPath;

  const OneClickAdResult({
    required this.success,
    required this.outputPath,
    required this.analysis,
    required this.ad,
    required this.project,
    required this.lipSyncFrames,
    required this.avatar,
    required this.render,
    required this.manifestPath,
  });
}

class OneClickAiAd {
  final ProductAnalyzer analyzer;
  final AiAdBrain adBrain;
  final AutomaticSceneBuilder sceneBuilder;
  final TtsService tts;
  final LipSyncService lipSync;
  final AvatarProvider avatar;
  final RenderEngine renderer;

  const OneClickAiAd({
    this.analyzer = const LocalProductAnalyzer(),
    this.adBrain = const AiAdBrain(),
    this.sceneBuilder = const AutomaticSceneBuilder(),
    this.tts = const TtsService(),
    this.lipSync = const LipSyncService(),
    this.avatar = const LocalAvatarProvider(),
    this.renderer = const FfmpegRenderEngine(),
  });

  Future<OneClickAdResult> generate(
    OneClickAdInput input, {
    void Function(OneClickProgress progress)? onProgress,
  }) async {
    _report(onProgress, 'analysis', 0.05, 'Analyzing product');
    final analysis = await analyzer.analyze(input.product, input.productImagePath);

    _report(onProgress, 'ai-script', 0.18, 'Generating advertisement script');
    final brief = AdBrief(
      productName: analysis.product.name,
      audience: analysis.product.targetAudience,
      voice: const VoiceSettings(),
    );
    final ad = await adBrain.generate(analysis.product, brief);

    _report(onProgress, 'scenes', 0.32, 'Building scenes automatically');
    var project = sceneBuilder.build(ad, projectId: input.projectId);
    project = _attachProductImage(project, input.productImagePath);

    _report(onProgress, 'voice', 0.45, 'Generating voice audio');
    project = await _attachVoice(project, ad.brief.voice);

    _report(onProgress, 'avatar', 0.60, 'Preparing avatar');
    final outputDirectory = Directory(input.outputPath).parent.path;
    await Directory(outputDirectory).create(recursive: true);
    final avatarOutput = await avatar.create(ad: ad, outputDirectory: outputDirectory);
    project = _attachAvatar(project, avatarOutput.mediaPath);

    _report(onProgress, 'lip-sync', 0.70, 'Generating lip-sync timing');
    final lipFrames = _buildLipSync(project);

    _report(onProgress, 'render', 0.78, 'Rendering final MP4');
    final request = RenderRequest(
      project: project,
      outputPath: input.outputPath,
      profile: RenderProfile.fromPreset(input.preset),
      ffmpegPath: input.ffmpegPath,
      musicPath: input.musicPath,
    );
    final render = await renderer.render(request);

    final manifestPath = '${input.outputPath}.json';
    await File(manifestPath).writeAsString(const JsonEncoder.withIndent('  ').convert({
      'phase': 10,
      'pipeline': 'one-click-ai-ad',
      'success': render.status == RenderStatus.completed,
      'outputPath': input.outputPath,
      'product': input.product.name,
      'preset': input.preset.name,
      'avatarProvider': avatarOutput.provider,
      'lipSyncFrames': lipFrames.length,
      'renderStatus': render.status.name,
      'renderError': render.error,
    }), flush: true);

    _report(onProgress, 'complete', 1.0, render.status == RenderStatus.completed
        ? 'One-click advertisement completed'
        : 'Advertisement pipeline finished with render errors');

    return OneClickAdResult(
      success: render.status == RenderStatus.completed,
      outputPath: input.outputPath,
      analysis: analysis,
      ad: ad,
      project: project,
      lipSyncFrames: lipFrames,
      avatar: avatarOutput,
      render: render,
      manifestPath: manifestPath,
    );
  }

  SceneProject _attachProductImage(SceneProject project, String imagePath) {
    if (imagePath.trim().isEmpty) return project;
    final scenes = project.scenes.map((scene) {
      final assets = scene.assets.map((asset) {
        if (asset.type == 'product') {
          return SceneAsset(id: asset.id, type: 'product', source: imagePath);
        }
        return asset;
      }).toList();
      return scene.copyWith(assets: assets);
    }).toList();
    return project.copyWith(scenes: scenes);
  }

  Future<SceneProject> _attachVoice(SceneProject project, VoiceSettings settings) async {
    final scenes = <EditableAdScene>[];
    for (final scene in project.scenes) {
      final path = await tts.speak(scene.narration, settings);
      final assets = [...scene.assets, SceneAsset(id: '${scene.id}-voice', type: 'voice', source: path)];
      scenes.add(scene.copyWith(assets: assets));
    }
    return project.copyWith(scenes: scenes);
  }

  SceneProject _attachAvatar(SceneProject project, String? path) {
    if (path == null || path.trim().isEmpty) return project;
    final scenes = project.scenes.map((scene) => scene.copyWith(
      assets: [...scene.assets, SceneAsset(id: '${scene.id}-avatar', type: 'avatar', source: path)],
    )).toList();
    return project.copyWith(scenes: scenes);
  }

  List<LipSyncFrame> _buildLipSync(SceneProject project) {
    final frames = <LipSyncFrame>[];
    var cursor = 0.0;
    for (final scene in project.scenes) {
      final words = scene.narration.trim().isEmpty
          ? 1
          : scene.narration.trim().split(RegExp(r'\s+')).length;
      final segments = <SpeechSegment>[];
      final wordDuration = scene.duration / words.clamp(1, 1000);
      for (var i = 0; i < words; i++) {
        segments.add(SpeechSegment(
          text: 'word-$i',
          start: cursor + i * wordDuration,
          end: cursor + (i + 1) * wordDuration,
        ));
      }
      frames.addAll(lipSync.generate(segments));
      cursor += scene.duration;
    }
    return frames;
  }

  void _report(void Function(OneClickProgress progress)? callback, String stage, double fraction, String message) {
    callback?.call(OneClickProgress(stage: stage, fraction: fraction, message: message));
  }
}
