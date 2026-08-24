# ASAZU STUDIO 0.14.1

Android-ready Flutter source for ASAZU STUDIO.

## Fixes
- Fixed Phase 14 provider URL regex.
- Android-safe app storage using `path_provider`.
- Added FFmpegKit mobile rendering support.
- Added current FFmpegKit 4.6.2 and path_provider 2.1.6.
- Added CI build workflow.

## Build
Run `flutter pub get`, then `flutter build apk --release`.
If the Android platform folder is missing, run `flutter create . --platforms=android` first.

## Note
Real cloud AI/TTS/avatar providers still require provider credentials/configuration.
