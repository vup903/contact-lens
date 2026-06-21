import 'dart:io';

import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'voice_capture_service.dart';

/// Native [VoiceCaptureService]: records audio with `record` and transcribes it
/// live with on-device `speech_to_text`. Both run together so the user gets a
/// transcript plus a saved audio file. Every plugin call is guarded — a denied
/// mic, a failed STT init, or a recorder error degrades to "no recording" and a
/// best-effort transcript rather than throwing into the UI (SSD C2).
class MobileVoiceCaptureService implements VoiceCaptureService {
  MobileVoiceCaptureService();

  final AudioRecorder _recorder = AudioRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isRecording = false;
  String _transcript = '';
  String? _audioPath;

  @override
  Future<bool> ensurePermission() async {
    try {
      final micGranted = await _recorder.hasPermission();
      final speechReady = await _speech.initialize();
      return micGranted && speechReady;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start() async {
    if (_isRecording) {
      return;
    }
    try {
      _transcript = '';
      _audioPath =
          '${Directory.systemTemp.path}/encounter_'
          '${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: _audioPath!);
      await _speech.listen(
        onResult: (result) => _transcript = result.recognizedWords,
      );
      _isRecording = true;
    } catch (_) {
      _isRecording = false;
    }
  }

  @override
  Future<VoiceCaptureResult> stop() async {
    try {
      await _speech.stop();
      final recordedPath = await _recorder.stop();
      _audioPath = recordedPath ?? _audioPath;
    } catch (_) {
      // Swallow and return whatever transcript we managed to capture (C2).
    }
    _isRecording = false;
    return VoiceCaptureResult(
      transcript: _transcript.trim(),
      audioPath: _audioPath,
    );
  }

  @override
  bool get isRecording => _isRecording;
}

/// Factory selected by the conditional import in `voice_capture_service.dart`.
VoiceCaptureService createPlatformVoiceCaptureService() =>
    MobileVoiceCaptureService();
