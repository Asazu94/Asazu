import 'package:test/test.dart';
import '../lib/ai_ad_brain.dart';
import '../lib/effects.dart';
import '../lib/scene_builder.dart';

void main() {
  test('Phase 7 adds effects and caption animation to scenes', () async {
    final result = await const AiAdBrain().generate(
      const ProductInput(name: 'Smart Watch', description: 'Fitness smartwatch'),
      const AdBrief(),
    );
    final project = const AutomaticSceneBuilder().build(result);

    expect(project.scenes, isNotEmpty);
    expect(project.scenes.first.effects, isNotEmpty);
    expect(project.scenes.first.captionAnimation.animation, isNot(CaptionAnimation.none));
    expect(project.scenes.last.effects, isNotEmpty);
  });

  test('templates expose reusable defaults', () {
    expect(Phase7Defaults.socialVertical.defaultEffects, isNotEmpty);
    expect(Phase7Defaults.cleanProduct.captions.animation, CaptionAnimation.fade);
  });
}
