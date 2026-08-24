import 'package:test/test.dart';
import '../lib/ai_ad_brain.dart';
import '../lib/scene_builder.dart';

void main() {
  test('Phase 6 converts Phase 5 instructions into editable scenes', () async {
    final brain = AiAdBrain();
    final result = await brain.generate(
      const ProductInput(
        name: 'Smart Watch X1',
        description: 'Smartwatch yenye muonekano wa kisasa.',
        features: ['Calls', 'Sport tracking'],
        targetAudience: 'vijana',
      ),
      const AdBrief(productName: 'Smart Watch X1'),
    );

    final project = const AutomaticSceneBuilder().build(result);

    expect(project.scenes, isNotEmpty);
    expect(project.width, 1080);
    expect(project.height, 1920);
    expect(project.scenes.first.kind, SceneKind.hook);
    expect(project.scenes.last.kind, SceneKind.cta);
    expect(project.duration, greaterThan(0));
    expect(project.scenes.every((s) => s.assets.isNotEmpty), isTrue);
  });
}
