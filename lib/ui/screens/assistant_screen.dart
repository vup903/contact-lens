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
          const Text('No model API. Retrieval and recommendation run on saved contact fields only.'),
          const SizedBox(height: 16),
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
            onPressed: () {
              setState(() => _result = widget.appState.recommend(_queryController.text));
            },
            icon: const Icon(Icons.manage_search),
            label: const Text('Run local RAG'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _result == null
                ? const Center(child: Text('Ask a business need to see deterministic recommendations.'))
                : _RecommendationView(result: _result!),
          ),
        ],
      ),
    );
  }
}

class _RecommendationView extends StatelessWidget {
  const _RecommendationView({required this.result});

  final LocalRecommendation result;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
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

