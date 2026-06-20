import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../scan/scan.dart';
import '../app_state.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    required this.appState,
    super.key,
  });

  final ContactLensState appState;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _rawTextController = TextEditingController();
  ParsedBusinessCard? _parsed;
  var _isWorking = false;

  @override
  void dispose() {
    _rawTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final messenger = ScaffoldMessenger.of(context);
        final editor = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Card Scan', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Mobile can use local OCR. Web demo supports pasted OCR text.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isWorking ? null : _pickImageAndRecognize,
                  icon: const Icon(Icons.image_search),
                  label: const Text(kIsWeb ? 'Pick image (web fallback)' : 'Pick image + OCR'),
                ),
                OutlinedButton.icon(
                  onPressed: _parseText,
                  icon: const Icon(Icons.rule),
                  label: const Text('Parse text'),
                ),
                if (_parsed != null)
                  FilledButton.icon(
                    onPressed: () async {
                      await widget.appState.addContactFromParsedCard(_parsed!);
                      if (!mounted) {
                        return;
                      }
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Saved parsed contact.')),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save contact'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _rawTextController,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Paste OCR text here, then parse.',
                ),
              ),
            ),
          ],
        );
        final preview = _ParsedPreview(parsed: _parsed);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: constraints.maxWidth < 820
              ? Column(
                  children: [
                    Expanded(child: editor),
                    const SizedBox(height: 12),
                    preview,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: editor),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: preview),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _pickImageAndRecognize() async {
    setState(() => _isWorking = true);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        return;
      }
      if (kIsWeb) {
        _rawTextController.text =
            'Web OCR is intentionally not bundled. Paste OCR text here for the demo.\nSelected: ${image.name}';
        return;
      }
      final text = await const LocalOcrAdapter().recognizeImagePath(image.path);
      _rawTextController.text = text;
      _parseText();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  void _parseText() {
    setState(() {
      _parsed = parseBusinessCardText(_rawTextController.text);
    });
  }
}

class _ParsedPreview extends StatelessWidget {
  const _ParsedPreview({required this.parsed});

  final ParsedBusinessCard? parsed;

  @override
  Widget build(BuildContext context) {
    final parsed = this.parsed;
    if (parsed == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Parsed fields will appear here.'),
        ),
      );
    }

    final rows = <(String, String)>[
      ('Name', parsed.name),
      ('Company', parsed.company),
      ('Job title', parsed.jobTitle),
      ('Phone', parsed.phone),
      ('Mobile', parsed.mobilePhone),
      ('Fax', parsed.fax),
      ('Email', parsed.email),
      ('Address', parsed.address),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parsed contact', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.$1, style: Theme.of(context).textTheme.labelSmall),
                    Text(row.$2.isEmpty ? '-' : row.$2),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
