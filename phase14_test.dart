import 'package:test/test.dart';
import '../lib/phase14_providers.dart';

void main() {
  test('unconfigured settings use safe fallback providers', () {
    const settings = Phase14Settings(
      ai: AiProviderConfig(baseUrl: '', apiKey: '', model: 'test'),
      tts: TtsProviderConfig(endpoint: '', apiKey: ''),
      avatar: AvatarProviderConfig(endpoint: '', apiKey: ''),
    );
    final factory = Phase14ProviderFactory(settings);
    expect(factory.createAi(), isNotNull);
    expect(factory.createTts(), isNotNull);
    expect(factory.createAvatar(), isNotNull);
  });

  test('configured flags are correct', () {
    const ai = AiProviderConfig(baseUrl: 'https://example.com/v1', apiKey: 'secret', model: 'x');
    expect(ai.isConfigured, isTrue);
  });
}
