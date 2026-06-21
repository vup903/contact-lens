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
          'Contact Lens is a tiered, cost-aware retriever: a cheap lexical tier '
          'answers every query, a confidence gate detects the hard ones, and a '
          'semantic rerank tier fires only for those. Quality is measured with a '
          'labeled eval set (precision@k, nDCG@5). Running on-device is a result '
          'of the cost design, not its headline.',
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
          icon: Icons.bolt_outlined,
          title: '3. Tier 1 — Lexical (always on)',
          body: 'Tokenizer + weighted field matching ranks name, company, job '
              'title, groups, and notes. Pure Dart, sub-millisecond, ~0 cost.',
        ),
        const _StepCard(
          icon: Icons.rule,
          title: '4. Confidence gate',
          body: 'Escalates only when Tier 1 is unsure — low top score or a small '
              'top-1 vs top-2 margin. Confident queries stop here.',
        ),
        const _StepCard(
          icon: Icons.hub_outlined,
          title: '5. Tier 2 — Semantic rerank (only when unsure)',
          body: 'On-device embeddings re-score the candidate pool by cosine '
              'similarity and blend with the lexical score. No network, no API key.',
        ),
        const _StepCard(
          icon: Icons.query_stats,
          title: '6. Measured quality',
          body: 'tool/eval.dart and tool/eval_hybrid.dart score retrievers on a '
              'labeled set; hybrid nDCG@5 is expected to match or beat lexical.',
        ),
        const _StepCard(
          icon: Icons.document_scanner_outlined,
          title: '7. Scanning',
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

