import 'dart:io';

import 'package:test/test.dart';
import '../lib/ai_ad_brain.dart';
import '../lib/one_click_ai_ad.dart';
import '../lib/render_engine.dart';
import '../lib/scene_builder.dart';
import '../lib/voice.dart';

class FakeTts implements TtsProvider {
  int calls = 0;
  @override
  Future<String> synthesize(String text, VoiceSettings settings) async {
    calls++;
    return 'voice-$calls.wav';
  }
}

class FakeRenderer implements RenderEngine {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<RenderResult> render(RenderRequest request, {void Function(RenderProgress progress)? onProgress}) async {
    onProgress?.call(const RenderProgress(status: RenderStatus.completed, sceneIndex: 1, sceneCount: 1));
    return RenderResult(status: RenderStatus.completed, outputPath: request.outputPath);
  }
}

void main() {
  test('one-click pipeline builds scenes, voice and lip-sync', () async {
    final tts = FakeTts();
    final temp = await Directory.systemTemp.createTemp('asazu_phase10_');
    final output = '${temp.path}/ad.mp4';
    final pipeline = OneClickAiAd(
      tts: TtsService(provider: tts),
      renderer: const FakeRenderer(),
    );
    final result = await pipeline.generate(OneClickAdInput(
      product: const ProductInput(
        name: 'Smart Watch',
        description: 'Smart watch for everyday use.',
        features: ['Calls', 'Notifications', 'Fitness tracking'],
        targetAudience: 'young professionals',
      ),
      productImagePath: '${temp.path}/watch.jpg',
      outputPath: output,
    ));

    expect(result.success, isTrue);
    expect(result.project.scenes, isNotEmpty);
    expect(tts.calls, result.project.scenes.length);
    expect(result.lipSyncFrames, isNotEmpty);
    expect(await File(result.manifestPath).exists(), isTrue);
    await temp.delete(recursive: true);
  });

  test('render preset maps correctly', () {
    expect(RenderProfile.fromPreset(RenderPreset.tiktok).height, 1920);
    expect(RenderProfile.fromPreset(RenderPreset.youtubeLandscape).width, 1920);
    expect(RenderProfile.fromPreset(RenderPreset.square).width, 1080);
  });
}
