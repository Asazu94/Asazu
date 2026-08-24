/// Phase 7: Effects, templates and media styling models.
enum EffectType {
  fade,
  zoom,
  shake,
  blur,
  glow,
  bounce,
  slide,
  pop,
  kenBurns,
}

enum BackgroundType { solid, gradient, image, video, transparent }
enum CaptionAnimation { none, fade, wordPop, typewriter, karaoke, bounce }
enum MusicFit { none, low, medium, high }

class EffectConfig {
  final String id;
  final EffectType type;
  final double intensity;
  final double start;
  final double duration;
  final bool enabled;

  const EffectConfig({
    required this.id,
    required this.type,
    this.intensity = 0.5,
    this.start = 0,
    this.duration = 1,
    this.enabled = true,
  });
}

class BackgroundConfig {
  final BackgroundType type;
  final String value;
  final double opacity;

  const BackgroundConfig({
    this.type = BackgroundType.gradient,
    this.value = 'dark',
    this.opacity = 1,
  });
}

class CaptionAnimationConfig {
  final CaptionAnimation animation;
  final double speed;
  final bool highlightKeywords;

  const CaptionAnimationConfig({
    this.animation = CaptionAnimation.wordPop,
    this.speed = 1,
    this.highlightKeywords = true,
  });
}

class MusicConfig {
  final String? trackId;
  final double volume;
  final MusicFit fit;
  final bool duckUnderVoice;

  const MusicConfig({
    this.trackId,
    this.volume = 0.18,
    this.fit = MusicFit.medium,
    this.duckUnderVoice = true,
  });
}

class AdTemplate {
  final String id;
  final String name;
  final String description;
  final BackgroundConfig background;
  final CaptionAnimationConfig captions;
  final List<EffectConfig> defaultEffects;
  final MusicConfig music;

  const AdTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.background = const BackgroundConfig(),
    this.captions = const CaptionAnimationConfig(),
    this.defaultEffects = const [],
    this.music = const MusicConfig(),
  });
}

class Phase7Defaults {
  static const socialVertical = AdTemplate(
    id: 'social-vertical',
    name: 'ASAZU Social Vertical',
    description: 'Fast product-first template for TikTok, Reels and Shorts.',
    background: BackgroundConfig(type: BackgroundType.gradient, value: 'brand'),
    captions: CaptionAnimationConfig(animation: CaptionAnimation.wordPop),
    defaultEffects: [
      EffectConfig(id: 'hook-zoom', type: EffectType.zoom, intensity: 0.55, duration: 1.2),
      EffectConfig(id: 'cta-pop', type: EffectType.pop, intensity: 0.45, duration: 0.7),
    ],
    music: MusicConfig(volume: 0.16, fit: MusicFit.medium),
  );

  static const cleanProduct = AdTemplate(
    id: 'clean-product',
    name: 'Clean Product',
    description: 'Minimal product presentation with gentle movement.',
    background: BackgroundConfig(type: BackgroundType.solid, value: 'neutral'),
    captions: CaptionAnimationConfig(animation: CaptionAnimation.fade),
    defaultEffects: [
      EffectConfig(id: 'product-kenburns', type: EffectType.kenBurns, intensity: 0.35, duration: 2),
    ],
    music: MusicConfig(volume: 0.1, fit: MusicFit.low),
  );
}
