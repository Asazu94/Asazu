import 'dart:convert';
import 'dart:io';

import 'ai_ad_brain.dart';
import 'one_click_ai_ad.dart';
import 'voice.dart';

/// Phase 14 provider configuration. No API key is hard-coded in the app.
class AiProviderConfig {
  final String baseUrl;
  final String apiKey;
  final String model;
  final Duration timeout;

  const AiProviderConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.timeout = const Duration(seconds: 90),
  });

  bool get isConfigured => apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;
}

class TtsProviderConfig {
  final String endpoint;
  final String apiKey;
  final Duration timeout;
  const TtsProviderConfig({required this.endpoint, required this.apiKey, this.timeout = const Duration(seconds: 90)});
  bool get isConfigured => endpoint.trim().isNotEmpty && apiKey.trim().isNotEmpty;
}

class AvatarProviderConfig {
  final String endpoint;
  final String apiKey;
  final Duration timeout;
  const AvatarProviderConfig({required this.endpoint, required this.apiKey, this.timeout = const Duration(minutes: 5)});
  bool get isConfigured => endpoint.trim().isNotEmpty && apiKey.trim().isNotEmpty;
}

class Phase14Settings {
  final AiProviderConfig ai;
  final TtsProviderConfig tts;
  final AvatarProviderConfig avatar;
  const Phase14Settings({required this.ai, required this.tts, required this.avatar});

  factory Phase14Settings.fromEnvironment() => Phase14Settings(
    ai: AiProviderConfig(
      baseUrl: Platform.environment['ASAZU_AI_BASE_URL'] ?? 'https://api.openai.com/v1',
      apiKey: Platform.environment['ASAZU_AI_API_KEY'] ?? '',
      model: Platform.environment['ASAZU_AI_MODEL'] ?? 'gpt-4o-mini',
    ),
    tts: TtsProviderConfig(
      endpoint: Platform.environment['ASAZU_TTS_URL'] ?? '',
      apiKey: Platform.environment['ASAZU_TTS_API_KEY'] ?? '',
    ),
    avatar: AvatarProviderConfig(
      endpoint: Platform.environment['ASAZU_AVATAR_URL'] ?? '',
      apiKey: Platform.environment['ASAZU_AVATAR_API_KEY'] ?? '',
    ),
  );
}

class _HttpJsonClient {
  Future<Map<String, dynamic>> postJson({
    required Uri uri,
    required Map<String, String> headers,
    required Object body,
    required Duration timeout,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      headers.forEach(request.headers.set);
      request.write(jsonEncode(body));
      final response = await request.close().timeout(timeout);
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}: ${text.substring(0, text.length.clamp(0, 1000))}');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) throw const FormatException('Expected JSON object');
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}

/// OpenAI-compatible chat provider. Works with compatible gateways as well.
class OpenAiCompatibleAdProvider implements AiAdProvider {
  final AiProviderConfig config;
  final _HttpJsonClient _http;
  OpenAiCompatibleAdProvider(this.config, {_HttpJsonClient? http}) : _http = http ?? _HttpJsonClient();

  @override
  Future<AdScript> generateScript(ProductInput product, AdBrief brief) async {
    if (!config.isConfigured) throw StateError('AI provider is not configured.');
    final response = await _http.postJson(
      uri: Uri.parse('${config.baseUrl.replaceFirst(RegExp(r'/+$'), '')}/chat/completions'),
      headers: {'Authorization': 'Bearer ${config.apiKey}'},
      timeout: config.timeout,
      body: {
        'model': config.model,
        'temperature': 0.8,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': 'You are ASAZU STUDIO Ad Brain. Create concise, truthful advertising copy. Return JSON with hook, benefits(array), body, cta, estimatedSeconds(integer), fullScript.'},
          {'role': 'user', 'content': jsonEncode({
            'product': {'name': product.name, 'description': product.description, 'price': product.price, 'features': product.features, 'targetAudience': product.targetAudience, 'brandName': product.brandName},
            'goal': brief.goal.name,
            'tone': brief.tone.name,
            'language': brief.voice.language.name,
          })},
        ],
      },
    );
    final choices = response['choices'];
    final first = choices is List && choices.isNotEmpty ? choices.first : null;
    final message = first is Map ? first['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String) throw const FormatException('AI response did not contain message content.');
    final json = jsonDecode(content);
    return AdScript(
      hook: '${json['hook'] ?? ''}',
      benefits: (json['benefits'] as List? ?? const []).map((e) => '$e').toList(),
      body: '${json['body'] ?? ''}',
      cta: '${json['cta'] ?? ''}',
      fullScript: '${json['fullScript'] ?? ''}',
      estimatedSeconds: int.tryParse('${json['estimatedSeconds'] ?? 20}') ?? 20,
    );
  }
}

/// Generic HTTP TTS adapter. The endpoint must return {"audioUrl":"..."}.
class HttpTtsProvider implements TtsProvider {
  final TtsProviderConfig config;
  final _HttpJsonClient _http;
  HttpTtsProvider(this.config, {_HttpJsonClient? http}) : _http = http ?? _HttpJsonClient();

  @override
  Future<String> synthesize(String text, VoiceSettings settings) async {
    if (!config.isConfigured) throw StateError('TTS provider is not configured.');
    final response = await _http.postJson(
      uri: Uri.parse(config.endpoint),
      headers: {'Authorization': 'Bearer ${config.apiKey}'},
      timeout: config.timeout,
      body: {'text': text, 'language': settings.language.name, 'gender': settings.gender.name, 'speed': settings.speed, 'volume': settings.volume},
    );
    final url = response['audioUrl'];
    if (url is! String || url.isEmpty) throw const FormatException('TTS response missing audioUrl.');
    return url;
  }
}

/// Generic avatar job adapter. Endpoint must return {"mediaPath":"..."}.
class HttpAvatarProvider implements AvatarProvider {
  final AvatarProviderConfig config;
  final _HttpJsonClient _http;
  HttpAvatarProvider(this.config, {_HttpJsonClient? http}) : _http = http ?? _HttpJsonClient();

  @override
  Future<AvatarOutput> create({required AdBrainResult ad, required String outputDirectory}) async {
    if (!config.isConfigured) throw StateError('Avatar provider is not configured.');
    final response = await _http.postJson(
      uri: Uri.parse(config.endpoint),
      headers: {'Authorization': 'Bearer ${config.apiKey}'},
      timeout: config.timeout,
      body: {'outputDirectory': outputDirectory, 'script': ad.script.fullScript, 'scenes': ad.scenes.map((s) => {'duration': s.duration, 'narration': s.narration}).toList()},
    );
    final path = response['mediaPath'];
    if (path is! String || path.isEmpty) throw const FormatException('Avatar response missing mediaPath.');
    return AvatarOutput(mediaPath: path, provider: 'http-avatar');
  }
}

/// Builds production providers while retaining local fallback behavior.
class Phase14ProviderFactory {
  final Phase14Settings settings;
  const Phase14ProviderFactory(this.settings);

  AiAdProvider createAi({bool fallbackToLocal = true}) =>
      settings.ai.isConfigured ? OpenAiCompatibleAdProvider(settings.ai) : LocalAdProvider();

  TtsProvider createTts({bool fallbackToLocal = true}) =>
      settings.tts.isConfigured ? HttpTtsProvider(settings.tts) : LocalTtsProvider();

  AvatarProvider createAvatar({bool fallbackToLocal = true}) =>
      settings.avatar.isConfigured ? HttpAvatarProvider(settings.avatar) : LocalAvatarProvider();
}
