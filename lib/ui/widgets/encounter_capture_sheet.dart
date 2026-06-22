import 'package:flutter/material.dart';

import '../../capture/capture.dart';
import '../../domain/domain.dart';

/// Shows the [EncounterCaptureSheet] as a modal bottom sheet and resolves to the
/// assembled [EncounterDraft], or `null` if the user dismisses it.
///
/// [reading] pre-fills the place and carries the GPS point; [source] records how
/// the encounter was captured (scan vs. manual); [now] is injectable so the
/// default timestamp is deterministic in tests.
Future<EncounterDraft?> showEncounterCaptureSheet(
  BuildContext context, {
  required VoiceCaptureService voiceService,
  GeoReading? reading,
  EncounterSource source = EncounterSource.manual,
  DateTime? now,
}) {
  return showModalBottomSheet<EncounterDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => EncounterCaptureSheet(
      voiceService: voiceService,
      reading: reading,
      source: source,
      now: now ?? DateTime.now().toUtc(),
    ),
  );
}

/// Fast capture panel shown right after a card is exchanged: detected time
/// (editable), GPS place (editable), a free-form note, and — only where
/// recording is supported — a mic button for a spoken note (SSD §4.6). The point
/// and timestamp are sampled once, with consent; nothing is tracked continuously.
class EncounterCaptureSheet extends StatefulWidget {
  const EncounterCaptureSheet({
    required this.voiceService,
    required this.now,
    this.reading,
    this.source = EncounterSource.manual,
    super.key,
  });

  final VoiceCaptureService voiceService;
  final DateTime now;
  final GeoReading? reading;
  final EncounterSource source;

  @override
  State<EncounterCaptureSheet> createState() => _EncounterCaptureSheetState();
}

class _EncounterCaptureSheetState extends State<EncounterCaptureSheet> {
  late final TextEditingController _placeController;
  late final TextEditingController _noteController;
  late DateTime _occurredAt;

  // Mic state. `_micAvailable` is resolved asynchronously; until then (and on
  // platforms without recording) the mic affordance stays hidden (SSD C2).
  bool _micAvailable = false;
  bool _recording = false;
  bool _busy = false;
  String _transcript = '';
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _occurredAt = widget.now.toUtc();
    _placeController =
        TextEditingController(text: widget.reading?.placeLabel ?? '');
    _noteController = TextEditingController();
    _probeMic();
  }

  Future<void> _probeMic() async {
    final available = await widget.voiceService.ensurePermission();
    if (mounted) {
      setState(() => _micAvailable = available);
    }
  }

  @override
  void dispose() {
    _placeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (_recording) {
        final result = await widget.voiceService.stop();
        setState(() {
          _recording = false;
          _transcript = result.transcript;
          _audioPath = result.audioPath;
        });
      } else {
        await widget.voiceService.start();
        setState(() => _recording = true);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt.toLocal(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        // Keep the captured time-of-day, just move the day.
        _occurredAt = DateTime.utc(
          picked.year,
          picked.month,
          picked.day,
          _occurredAt.hour,
          _occurredAt.minute,
        );
      });
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      EncounterDraft(
        occurredAt: _occurredAt,
        geo: widget.reading?.point,
        placeLabel: _placeController.text.trim(),
        note: _noteController.text.trim(),
        transcript: _transcript.trim(),
        audioPath: _audioPath,
        source: widget.source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Lift the sheet above the keyboard while typing the note.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.place_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Capture context',
                        style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Time and place are sampled once, with consent. The note is '
                'summarized locally unless cloud enrichment is on.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),
              // Detected time (editable via the date picker).
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(_formatTimestamp(_occurredAt)),
                subtitle: const Text('When you met (tap to change the date)'),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _placeController,
                decoration: const InputDecoration(
                  labelText: 'Place',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  hintText: 'e.g. San Francisco, CA',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'What did you talk about?',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              if (_transcript.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    leading: const Icon(Icons.graphic_eq),
                    title: const Text('Voice transcript'),
                    subtitle: Text(_transcript.trim()),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_micAvailable)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _toggleRecording,
                      icon: Icon(_recording ? Icons.stop : Icons.mic),
                      label: Text(_recording ? 'Stop' : 'Voice note'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _recording ? null : _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Save context'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `yyyy-MM-dd HH:mm` in UTC — matches the deterministic, UTC-everywhere style
/// the rest of the app uses for encounter timestamps.
String _formatTimestamp(DateTime t) {
  final u = t.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}-${two(u.month)}-${two(u.day)} '
      '${two(u.hour)}:${two(u.minute)} UTC';
}
