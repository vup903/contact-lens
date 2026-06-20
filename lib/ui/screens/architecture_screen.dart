import 'package:flutter/material.dart';

import '../app_state.dart';

class ArchitectureScreen extends StatelessWidget {
  const ArchitectureScreen({
    required this.appState,
    super.key,
  });

  final ContactLensState appState;

  @override
  Widget build(BuildContext context) {
    final manifest = appState.manifest;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Architecture Demo', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Contact Lens is local-first: contacts stay on device/browser storage, local RAG ranks candidates, and no paid model API is called.',
        ),
        const SizedBox(height: 16),
        _StepCard(
          icon: Icons.badge_outlined,
          title: '1. Contacts',
          body: '${appState.contacts.length} contacts are available in the local repository.',
        ),
        _StepCard(
          icon: Icons.fingerprint,
          title: '2. Manifest',
          body:
              'Fingerprint: ${manifest.pipelineFingerprint.tokenizerVersion} / ${manifest.pipelineFingerprint.weightsVersion}\nIndexed records: ${manifest.contacts.length}',
        ),
        const _StepCard(
          icon: Icons.manage_search,
          title: '3. Retrieval',
          body: 'Tokenizer + weighted field matching ranks name, company, job title, groups, and notes.',
        ),
        const _StepCard(
          icon: Icons.rule,
          title: '4. Recommendation',
          body: 'The assistant renders deterministic reasons from matched fields. It does not invent background.',
        ),
        const _StepCard(
          icon: Icons.document_scanner_outlined,
          title: '5. Scanning',
          body: 'Business card OCR text is parsed with local rules adapted from the original Bizcard project.',
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(body),
      ),
    );
  }
}

