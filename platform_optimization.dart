import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Phase 9: platform-aware defaults shared by Android and Windows.
enum AsazuPlatform { android, windows, other }

enum RenderPriority { low, normal, high }

class PlatformOptimizationProfile {
  final AsazuPlatform platform;
  final int maxConcurrentRenders;
  final int memoryBudgetMb;
  final int thumbnailCacheMb;
  final int maxImportMb;
  final bool backgroundRendering;

  const PlatformOptimizationProfile({
    required this.platform,
    required this.maxConcurrentRenders,
    required this.memoryBudgetMb,
    required this.thumbnailCacheMb,
    required this.maxImportMb,
    required this.backgroundRendering,
  });

  static const android = PlatformOptimizationProfile(
    platform: AsazuPlatform.android,
    maxConcurrentRenders: 1,
    memoryBudgetMb: 768,
    thumbnailCacheMb: 128,
    maxImportMb: 1024,
    backgroundRendering: true,
  );

  static const windows = PlatformOptimizationProfile(
    platform: AsazuPlatform.windows,
    maxConcurrentRenders: 2,
    memoryBudgetMb: 4096,
    thumbnailCacheMb: 512,
    maxImportMb: 8192,
    backgroundRendering: true,
  );

  static PlatformOptimizationProfile detect() {
    if (Platform.isAndroid) return android;
    if (Platform.isWindows) return windows;
    return const PlatformOptimizationProfile(
      platform: AsazuPlatform.other,
      maxConcurrentRenders: 1,
      memoryBudgetMb: 1024,
      thumbnailCacheMb: 256,
      maxImportMb: 2048,
      backgroundRendering: true,
    );
  }
}

class FfmpegLocator {
  final String? configuredPath;
  const FfmpegLocator({this.configuredPath});

  String get executable {
    if (configuredPath != null && configuredPath!.trim().isNotEmpty) {
      return configuredPath!;
    }
    // Android packaging can expose ffmpeg through an app-private files/bin path.
    if (Platform.isAndroid) return 'ffmpeg';
    // Windows installers commonly place ffmpeg beside the application or on PATH.
    return 'ffmpeg';
  }

  Future<bool> available() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final session = await FFmpegKit.execute('-version');
        return ReturnCode.isSuccess(await session.getReturnCode());
      } catch (_) {
        return false;
      }
    }
    try {
      final result = await Process.run(executable, ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
