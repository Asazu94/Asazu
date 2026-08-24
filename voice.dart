enum VoiceLanguage { swahili, english }
enum VoiceGender { male, female }
enum VoiceStyle { professional, friendly, energetic, calm }

class VoiceSettings {
  final VoiceLanguage language;
  final VoiceGender gender;
  final VoiceStyle style;
  final double speed;
  final double volume;
  const VoiceSettings({
    this.language=VoiceLanguage.swahili,
    this.gender=VoiceGender.male,
    this.style=VoiceStyle.professional,
    this.speed=1.0,
    this.volume=1.0,
  });
}

class SpeechSegment {
  final String text;
  final double start;
  final double end;
  const SpeechSegment({
    required this.text, required this.start, required this.end,
  });
}

class LipSyncFrame {
  final double time;
  final String mouth;
  const LipSyncFrame({required this.time, required this.mouth});
}

abstract class TtsProvider {
  Future<String> synthesize(String text, VoiceSettings settings);
}

class LocalTtsProvider implements TtsProvider {
  @override
  Future<String> synthesize(String text, VoiceSettings settings) async =>
      'local-tts-placeholder.wav';
}

class TtsService {
  final TtsProvider provider;
  TtsService({TtsProvider? provider})
      : provider=provider ?? LocalTtsProvider();

  Future<String> speak(String text, VoiceSettings settings) =>
      provider.synthesize(text, settings);
}

class LipSyncService {
  List<LipSyncFrame> generate(List<SpeechSegment> segments) {
    final result=<LipSyncFrame>[];
    for(final s in segments) {
      final d=(s.end-s.start).clamp(0.05,30.0);
      final n=(d*8).round().clamp(1,240);
      for(var i=0;i<n;i++) {
        result.add(LipSyncFrame(
          time:s.start+d*i/n,
          mouth:i.isEven?'open':'closed',
        ));
      }
    }
    return result;
  }
}
