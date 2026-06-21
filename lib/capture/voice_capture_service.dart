// Same conditional-import shape as `geo_location_service.dart` and the OCR
// adapter: the stub everywhere except native builds, where the io variant pulls
// in `record` + `speech_to_text`.
import 'voice_capture_service_stub.dart'
    if (dart.library.io) 'voice_capture_service_mobile.dart' as platform;

/// Result of one voice note: the on-device transcript plus, on mobile, the path
/// to the saved audio file.
class VoiceCaptureResult {
  const VoiceCaptureResult({required this.transcript, this.audioPath});

  /// Speech-to-text output. Empty when nothing was recognized.
  final String transcript;

  /// Local audio file path; `null` on platforms without file-backed recording.
  final String? audioPath;
}

/// Records a short voice note and transcribes it on-device.
///
/// Degrades gracefully (SSD C2): where recording or speech recognition is
/// unavailable (web, missing permission) [ensurePermission] returns `false` and
/// the UI hides the mic affordance. [start]/[stop] never throw.
abstract class VoiceCaptureService {
  /// Requests mic + speech-recognition permission. Returns whether granted.
  Future<bool> ensurePermission();

  /// Begins recording and live transcription. No-op if already recording.
  Future<void> start();

  /// Stops recording and returns the transcript (and optional audio path).
  Future<VoiceCaptureResult> stop();

  /// Whether a recording is currently in progress.
  bool get isRecording;
}

/// Builds the right [VoiceCaptureService] for the current platform.
VoiceCaptureService createVoiceCaptureService() =>
    platform.createPlatformVoiceCaptureService();

/// In-memory [VoiceCaptureService] for tests and for web/desktop builds where
/// the audio/STT plugins are absent. Defaults to "permission denied" (SSD C2);
/// tests set [permitted] and a [cannedTranscript] to drive the happy path.
class FakeVoiceCaptureService implements VoiceCaptureService {
  FakeVoiceCaptureService({
    this.permitted = false,
    this.cannedTranscript = '',
    this.audioPath,
  });

  /// Whether [ensurePermission] grants access and recording proceeds.
  final bool permitted;

  /// Transcript returned by [stop].
  final String cannedTranscript;

  /// Audio path returned by [stop]; `null` mirrors a transcript-only platform.
  final String? audioPath;

  bool _isRecording = false;

  @override
  Future<bool> ensurePermission() async => permitted;

  @override
  Future<void> start() async {
    if (permitted) {
      _isRecording = true;
    }
  }

  @override
  Future<VoiceCaptureResult> stop() async {
    _isRecording = false;
    return VoiceCaptureResult(
      transcript: permitted ? cannedTranscript : '',
      audioPath: permitted ? audioPath : null,
    );
  }

  @override
  bool get isRecording => _isRecording;
}
