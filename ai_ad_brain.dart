import 'voice.dart';

enum AdTone { professional, friendly, energetic, persuasive, luxury }

enum AdGoal { awareness, sales, engagement, launch }

class ProductInput {
  final String name;
  final String description;
  final String price;
  final List<String> features;
  final String targetAudience;
  final String brandName;

  const ProductInput({
    required this.name,
    this.description = '',
    this.price = '',
    this.features = const [],
    this.targetAudience = '',
    this.brandName = 'ASAZU STORE',
  });
}

class AdBrief {
  final String productName;
  final String audience;
  final AdGoal goal;
  final AdTone tone;
  final VoiceSettings voice;

  const AdBrief({
    required this.productName,
    required this.audience,
    this.goal = AdGoal.sales,
    this.tone = AdTone.energetic,
    this.voice = const VoiceSettings(),
  });
}

class AdScript {
  final String hook;
  final List<String> benefits;
  final String body;
  final String cta;
  final String fullScript;
  final int estimatedSeconds;

  const AdScript({
    required this.hook,
    required this.benefits,
    required this.body,
    required this.cta,
    required this.fullScript,
    required this.estimatedSeconds,
  });
}

class AdSceneInstruction {
  final int index;
  final double duration;
  final String narration;
  final String visual;
  final String onScreenText;

  const AdSceneInstruction({
    required this.index,
    required this.duration,
    required this.narration,
    required this.visual,
    required this.onScreenText,
  });
}

class AdBrainResult {
  final AdBrief brief;
  final AdScript script;
  final List<AdSceneInstruction> scenes;

  const AdBrainResult({
    required this.brief,
    required this.script,
    required this.scenes,
  });
}

abstract class AiAdProvider {
  Future<AdScript> generateScript(ProductInput product, AdBrief brief);
}

/// Offline fallback. It lets the UI and Scene Builder work before an
/// online AI provider is connected.
class LocalAdProvider implements AiAdProvider {
  @override
  Future<AdScript> generateScript(ProductInput product, AdBrief brief) async {
    final name = product.name.trim().isEmpty ? 'Bidhaa hii' : product.name.trim();
    final audience = product.targetAudience.trim().isEmpty
        ? 'wateja wanaotafuta bidhaa bora'
        : product.targetAudience.trim();

    final hook = switch (brief.goal) {
      AdGoal.launch => '🚀 ${name} mpya imewasili — uko tayari kuiona?',
      AdGoal.engagement => 'Ungechagua ${name} kwa matumizi yako ya kila siku?',
      AdGoal.awareness => 'Kuna sababu kwa nini ${name} inavutia ${audience}.',
      AdGoal.sales => 'Unatafuta ${name} bora bila usumbufu? Angalia hii.',
    };

    final benefits = <String>[];
    for (final feature in product.features) {
      final value = feature.trim();
      if (value.isNotEmpty && !benefits.contains(value)) benefits.add(value);
      if (benefits.length == 4) break;
    }
    if (benefits.isEmpty) {
      benefits.addAll([
        'Muonekano wa kuvutia',
        'Rahisi kutumia',
        'Inafaa kwa matumizi ya kila siku',
      ]);
    }

    final description = product.description.trim();
    final body = description.isEmpty
        ? 'Imeundwa kwa ${audience.toLowerCase()} na inalenga kukupa matumizi rahisi na yenye thamani.'
        : description;

    final priceLine = product.price.trim().isEmpty ? '' : ' Bei: ${product.price.trim()}.';
    final cta = brief.goal == AdGoal.awareness || brief.goal == AdGoal.engagement
        ? 'Fuata ${product.brandName} kwa bidhaa zaidi.'
        : 'Agiza ${name} leo kupitia ${product.brandName}.$priceLine';

    final full = [
      hook,
      body,
      ...benefits.map((b) => 'Faida: $b.'),
      cta,
    ].join(' ');

    final seconds = (full.split(RegExp(r'\s+')).length / 2.2).ceil().clamp(10, 60);
    return AdScript(
      hook: hook,
      benefits: benefits,
      body: body,
      cta: cta,
      fullScript: full,
      estimatedSeconds: seconds,
    );
  }
}

class AdSceneBuilder {
  List<AdSceneInstruction> build(AdScript script) {
    final scenes = <AdSceneInstruction>[];
    var index = 1;

    scenes.add(AdSceneInstruction(
      index: index++, duration: 3.0, narration: script.hook,
      visual: 'Show product hero image with a slow zoom-in.',
      onScreenText: script.hook,
    ));

    final benefitDuration = script.benefits.isEmpty
        ? 3.5
        : (script.estimatedSeconds - 7) / script.benefits.length;
    for (final benefit in script.benefits) {
      scenes.add(AdSceneInstruction(
        index: index++, duration: benefitDuration.clamp(2.0, 5.0),
        narration: 'Faida: $benefit.',
        visual: 'Show the product and supporting visual for: $benefit.',
        onScreenText: benefit,
      ));
    }

    scenes.add(AdSceneInstruction(
      index: index++, duration: 4.0, narration: script.body,
      visual: 'Product lifestyle shot with subtle motion.',
      onScreenText: '',
    ));

    scenes.add(AdSceneInstruction(
      index: index, duration: 4.0, narration: script.cta,
      visual: 'End card with product, brand and call-to-action.',
      onScreenText: script.cta,
    ));

    return scenes;
  }
}

class AiAdBrain {
  final AiAdProvider provider;
  final AdSceneBuilder sceneBuilder;

  AiAdBrain({AiAdProvider? provider, AdSceneBuilder? sceneBuilder})
      : provider = provider ?? LocalAdProvider(),
        sceneBuilder = sceneBuilder ?? AdSceneBuilder();

  Future<AdBrainResult> generate(ProductInput product, AdBrief brief) async {
    final script = await provider.generateScript(product, brief);
    final scenes = sceneBuilder.build(script);
    return AdBrainResult(brief: brief, script: script, scenes: scenes);
  }
}
