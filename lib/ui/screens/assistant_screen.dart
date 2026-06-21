import 'package:flutter/material.dart';

import '../../rag/rag.dart';
import '../app_state.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    required this.appState,
    super.key,
  });

  final ContactLensState appState;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _queryController = TextEditingController();
  LocalRecommendation? _result;
  bool _rerankFired = false;
  bool _loading = false;

  Future<void> _runQuery() async {
    setState(() => _loading = true);
    final result = await widget.appState.recommend(_queryController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _rerankFired = widget.appState.lastRerankFired;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact header: title + a small inline hybrid toggle, so the
              // result list below keeps most of the vertical space.
              Row(
                children: [
                  Expanded(
                    child: Text('Local RAG Assistant', style: theme.textTheme.titleLarge),
                  ),
                  Text('Hybrid', style: theme.textTheme.labelLarge),
                  Switch(
                    value: widget.appState.hybridEnabled,
                    onChanged: (value) {
                      setState(() => widget.appState.setHybridEnabled(value));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'e.g. Find a product designer for mobile onboarding',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _loading ? null : _runQuery,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.manage_search),
                    label: const Text('Search'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.appState.hybridEnabled
                    ? 'Tiered: lexical + a multilingual MiniLM that recalls & reranks only when the lexical tier is unsure. No model API.'
                    : 'Lexical baseline only — no semantic tier, no model API.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const Divider(height: 20),
              Expanded(
                child: _result == null
                    ? const Center(child: Text('Ask a business need to see ranked, explainable matches.'))
                    : _RecommendationView(result: _result!, rerankFired: _rerankFired),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationView extends StatelessWidget {
  const _RecommendationView({required this.result, this.rerankFired = false});

  final LocalRecommendation result;
  final bool rerankFired;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (rerankFired)
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const ListTile(
              leading: Icon(Icons.auto_awesome),
              title: Text('Semantic tier fired'),
              subtitle: Text(
                'The lexical tier was unsure, so a multilingual MiniLM recalled and reranked the candidates.',
              ),
            ),
          ),
        if (rerankFired) const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.insights),
            title: const Text('Analysis'),
            subtitle: Text(result.analysis),
          ),
        ),
        const SizedBox(height: 8),
        for (final recommendation in result.recommendations)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.contact.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (recommendation.contact.subtitle.isNotEmpty)
                    Text(recommendation.contact.subtitle),
                  const SizedBox(height: 8),
                  Text(recommendation.reason),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(label: Text('score ${recommendation.score.toStringAsFixed(1)}')),
                      for (final field in recommendation.matchedFields)
                        Chip(label: Text(field)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Suggestions'),
            subtitle: Text(result.suggestions),
          ),
        ),
      ],
    );
  }
}

