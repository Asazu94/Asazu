import 'package:test/test.dart';
import '../lib/render_engine.dart';

void main() {
  test('render presets use correct resolutions', () {
    expect(RenderProfile.fromPreset(RenderPreset.tiktok).width, 1080);
    expect(RenderProfile.fromPreset(RenderPreset.tiktok).height, 1920);
    expect(RenderProfile.fromPreset(RenderPreset.youtubeLandscape).width, 1920);
    expect(RenderProfile.fromPreset(RenderPreset.youtubeLandscape).height, 1080);
    expect(RenderProfile.fromPreset(RenderPreset.square).width, 1080);
    expect(RenderProfile.fromPreset(RenderPreset.square).height, 1080);
  });

  test('progress fraction is safe', () {
    const progress = RenderProgress(status: RenderStatus.rendering, sceneIndex: 2, sceneCount: 4);
    expect(progress.fraction, 0.5);
    const empty = RenderProgress(status: RenderStatus.queued);
    expect(empty.fraction, 0);
  });

  test('progress serializes to JSON', () {
    const progress = RenderProgress(
      status: RenderStatus.completed,
      sceneIndex: 4,
      sceneCount: 4,
      message: 'done',
    );
    final json = renderProgressJson(progress);
    expect(json, contains('completed'));
    expect(json, contains('"fraction":1.0'));
  });
}
