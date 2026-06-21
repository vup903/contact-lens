import 'voice_capture_service.dart';

/// Web/desktop fallback: no audio/STT plugins, so deny permission. The UI hides
/// the mic and the user types the note instead (SSD C2).
VoiceCaptureService createPlatformVoiceCaptureService() =>
    FakeVoiceCaptureService();
