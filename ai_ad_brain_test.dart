import 'package:test/test.dart';
import '../lib/ai_ad_brain.dart';

void main() {
  test('generates script and scene instructions', () async {
    final brain = AiAdBrain();
    final result = await brain.generate(
      const ProductInput(
        name: 'Smart Watch X1',
        description: 'Smartwatch yenye muonekano wa kisasa.',
        price: 'TSh 85,000',
        features: ['Calls & notifications', 'Sport tracking', 'Stylish design'],
        targetAudience: 'vijana',
      ),
      const AdBrief(productName: 'Smart Watch X1'),
    );

    expect(result.script.hook, isNotEmpty);
    expect(result.script.benefits.length, 3);
    expect(result.scenes.length, greaterThan(2));
    expect(result.script.fullScript, contains(result.script.cta));
  });
}
