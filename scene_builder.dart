import 'ai_ad_brain.dart';
import 'effects.dart';

/// Phase 6: actual editable scene model produced from the Phase 5 script.
enum SceneKind { hook, benefit, body, cta }
enum VisualType { productHero, productFeature, lifestyle, endCard }
enum AvatarAction { none, enter, point, explain, smile, callToAction }
enum TransitionType { cut, fade, slide, zoom }

class SceneAsset {
  final String id;
  final String type;
  final String? source;
  const SceneAsset({required this.id, required this.type, this.source});
}

class CaptionStyle {
  final bool enabled;
  final double fontSize;
  final String position;
  final bool highlightKeywords;
  const CaptionStyle({
    this.enabled = true,
    this.fontSize = 42,
    this.position = 'bottom',
    this.highlightKeywords = true,
  });
}

class AvatarPlan {
  final bool enabled;
  final AvatarAction action;
  final String emotion;
  const AvatarPlan({
    this.enabled = false,
    this.action = AvatarAction.none,
    this.emotion = 'neutral',
  });
}

class SceneAnimation {
  final String camera;
  final double intensity;
  const SceneAnimation({this.camera = 'static', this.intensity = 0.5});
}

class EditableAdScene {
  final String id;
  final int index;
  final SceneKind kind;
  final double duration;
  final String narration;
  final String onScreenText;
  final VisualType visualType;
  final List<SceneAsset> assets;
  final AvatarPlan avatar;
  final CaptionStyle captions;
  final SceneAnimation animation;
  final TransitionType transitionIn;
  final TransitionType transitionOut;
  final List<EffectConfig> effects;
  final BackgroundConfig background;
  final CaptionAnimationConfig captionAnimation;

  const EditableAdScene({
    required this.id,
    required this.index,
    required this.kind,
    required this.duration,
    required this.narration,
    required this.onScreenText,
    required this.visualType,
    this.assets = const [],
    this.avatar = const AvatarPlan(),
    this.captions = const CaptionStyle(),
    this.animation = const SceneAnimation(),
    this.transitionIn = TransitionType.cut,
    this.transitionOut = TransitionType.cut,
    this.effects = const [],
    this.background = const BackgroundConfig(),
    this.captionAnimation = const CaptionAnimationConfig(),
  });

  EditableAdScene copyWith({
    double? duration,
    String? narration,
    String? onScreenText,
    VisualType? visualType,
    List<SceneAsset>? assets,
    AvatarPlan? avatar,
    CaptionStyle? captions,
    SceneAnimation? animation,
    TransitionType? transitionIn,
    TransitionType? transitionOut,
    List<EffectConfig>? effects,
    BackgroundConfig? background,
    CaptionAnimationConfig? captionAnimation,
  }) => EditableAdScene(
    id: id,
    index: index,
    kind: kind,
    duration: duration ?? this.duration,
    narration: narration ?? this.narration,
    onScreenText: onScreenText ?? this.onScreenText,
    visualType: visualType ?? this.visualType,
    assets: assets ?? this.assets,
    avatar: avatar ?? this.avatar,
    captions: captions ?? this.captions,
    animation: animation ?? this.animation,
    transitionIn: transitionIn ?? this.transitionIn,
    transitionOut: transitionOut ?? this.transitionOut,
    effects: effects ?? this.effects,
    background: background ?? this.background,
    captionAnimation: captionAnimation ?? this.captionAnimation,
  );
}

class SceneProject {
  final String id;
  final String title;
  final int width;
  final int height;
  final int fps;
  final List<EditableAdScene> scenes;

  const SceneProject({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    this.fps = 30,
    this.scenes = const [],
  });

  double get duration => scenes.fold(0, (sum, scene) => sum + scene.duration);

  SceneProject copyWith({List<EditableAdScene>? scenes}) => SceneProject(
    id: id,
    title: title,
    width: width,
    height: height,
    fps: fps,
    scenes: scenes ?? this.scenes,
  );
}

class AutomaticSceneBuilder {
  const AutomaticSceneBuilder();

  SceneProject build(AdBrainResult result, {String projectId = 'ad-project-1'}) {
    final source = result.scenes;
    final scenes = <EditableAdScene>[];

    for (final instruction in source) {
      final kind = _kind(instruction.index, source.length);
      final visual = _visual(kind);
      final avatar = _avatar(kind);
      final assets = [
        SceneAsset(id: 'product-${instruction.index}', type: 'product', source: null),
      ];

      scenes.add(EditableAdScene(
        id: 'scene-${instruction.index}',
        index: instruction.index,
        kind: kind,
        duration: instruction.duration,
        narration: instruction.narration,
        onScreenText: instruction.onScreenText,
        visualType: visual,
        assets: assets,
        avatar: avatar,
        captions: CaptionStyle(enabled: instruction.narration.trim().isNotEmpty),
        animation: SceneAnimation(
          camera: kind == SceneKind.hook ? 'slowZoomIn' : kind == SceneKind.cta ? 'pushIn' : 'gentlePan',
          intensity: kind == SceneKind.cta ? 0.35 : 0.55,
        ),
        transitionIn: kind == SceneKind.hook ? TransitionType.fade : TransitionType.cut,
        transitionOut: kind == SceneKind.cta ? TransitionType.fade : TransitionType.cut,
        effects: _effectsFor(kind),
        background: _backgroundFor(kind),
        captionAnimation: CaptionAnimationConfig(
          animation: kind == SceneKind.cta ? CaptionAnimation.bounce : CaptionAnimation.wordPop,
          speed: kind == SceneKind.hook ? 1.15 : 1.0,
        ),
      ));
    }

    return SceneProject(
      id: projectId,
      title: '${result.brief.productName} Advertisement',
      width: 1080,
      height: 1920,
      fps: 30,
      scenes: scenes,
    );
  }

  SceneKind _kind(int index, int total) {
    if (index == 1) return SceneKind.hook;
    if (index == total) return SceneKind.cta;
    // Phase 5 places benefits before body, so all middle scenes remain editable
    // and can later be classified more precisely by an online AI provider.
    return index == total - 1 ? SceneKind.body : SceneKind.benefit;
  }

  VisualType _visual(SceneKind kind) => switch (kind) {
    SceneKind.hook => VisualType.productHero,
    SceneKind.benefit => VisualType.productFeature,
    SceneKind.body => VisualType.lifestyle,
    SceneKind.cta => VisualType.endCard,
  };

  List<EffectConfig> _effectsFor(SceneKind kind) => switch (kind) {
    SceneKind.hook => const [
      EffectConfig(id: 'hook-zoom', type: EffectType.zoom, intensity: 0.55, duration: 1.2),
      EffectConfig(id: 'hook-glow', type: EffectType.glow, intensity: 0.25, duration: 1.0),
    ],
    SceneKind.benefit => const [
      EffectConfig(id: 'benefit-slide', type: EffectType.slide, intensity: 0.35, duration: 0.6),
    ],
    SceneKind.body => const [
      EffectConfig(id: 'body-kenburns', type: EffectType.kenBurns, intensity: 0.3, duration: 2.0),
    ],
    SceneKind.cta => const [
      EffectConfig(id: 'cta-pop', type: EffectType.pop, intensity: 0.5, duration: 0.7),
      EffectConfig(id: 'cta-glow', type: EffectType.glow, intensity: 0.3, duration: 0.8),
    ],
  };

  BackgroundConfig _backgroundFor(SceneKind kind) => switch (kind) {
    SceneKind.hook => const BackgroundConfig(type: BackgroundType.gradient, value: 'brand'),
    SceneKind.benefit => const BackgroundConfig(type: BackgroundType.gradient, value: 'product'),
    SceneKind.body => const BackgroundConfig(type: BackgroundType.image, value: 'lifestyle'),
    SceneKind.cta => const BackgroundConfig(type: BackgroundType.gradient, value: 'brand'),
  };

  AvatarPlan _avatar(SceneKind kind) => switch (kind) {
    SceneKind.hook => const AvatarPlan(enabled: true, action: AvatarAction.enter, emotion: 'excited'),
    SceneKind.benefit => const AvatarPlan(enabled: true, action: AvatarAction.point, emotion: 'confident'),
    SceneKind.body => const AvatarPlan(enabled: true, action: AvatarAction.explain, emotion: 'friendly'),
    SceneKind.cta => const AvatarPlan(enabled: true, action: AvatarAction.callToAction, emotion: 'smiling'),
  };
}
