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

  void _runQuery() {
    setState(() {
      _result = widget.appState.recommend(_queryController.text);
      _rerankFired = widget.appState.lastRerankFired;
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Local RAG Assistant', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('On-device tiered retrieval: a cheap lexical tier, with a semantic rerank that fires only when the lexical tier is unsure.'),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: widget.appState.hybridEnabled,
            onChanged: (value) {
              setState(() => widget.appState.setHybridEnabled(value));
            },
            title: const Text('Hybrid semantic rerank'),
            subtitle: Text(
              widget.appState.hybridEnabled
                  ? 'Lexical candidates, reranked by on-device embeddings when the confidence gate trips.'
                  : 'Lexical baseline only (no semantic tier).',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _queryController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Example: Find someone who can help with AI product fundraising',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _runQuery,
            icon: const Icon(Icons.manage_search),
            label: const Text('Run local RAG'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _result == null
                ? const Center(child: Text('Ask a business need to see deterministic recommendations.'))
                : _RecommendationView(result: _result!, rerankFired: _rerankFired),
          ),
        ],
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
              title: Text('Semantic rerank fired'),
              subtitle: Text(
                'The lexical tier was unsure, so on-device embeddings re-ranked the candidates.',
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

