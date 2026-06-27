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
  ContextualRecommendation? _recommendation;
  bool _rerankFired = false;
  bool _loading = false;

  Future<void> _runQuery() async {
    setState(() => _loading = true);
    final recommendation =
        await widget.appState.recommendContextual(_queryController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _recommendation = recommendation;
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
    final appState = widget.appState;
    final recommendation = _recommendation;
    final hasResult =
        recommendation != null && recommendation.query.rawQuery.isNotEmpty;

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
                    child: Text('Local RAG Assistant',
                        style: theme.textTheme.titleLarge),
                  ),
                  Text('Hybrid', style: theme.textTheme.labelLarge),
                  Switch(
                    value: appState.hybridEnabled,
                    onChanged: (value) {
                      setState(() => appState.setHybridEnabled(value));
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
                      onSubmitted: (_) => _loading ? null : _runQuery(),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'e.g. 上個月在舊金山見面、做機器學習那個工程師叫什麼？',
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
                appState.hybridEnabled
                    ? 'Time + place + meaning. Constraints filter encounters; a multilingual MiniLM recalls & reranks when the lexical tier is unsure.'
                    : 'Lexical baseline only — constraints still filter encounters, but no semantic tier.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              if (appState.cloudEnrichmentAvailable)
                _CloudEnrichmentToggle(appState: appState),
              const Divider(height: 20),
              Expanded(
                child: !hasResult
                    ? const Center(
                        child: Text(
                            'Ask a question mixing time, place, and meaning to see explainable matches.'))
                    : _ContextualResultView(
                        recommendation: recommendation,
                        rerankFired: _rerankFired,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cloud-enrichment opt-in with a one-line egress disclosure (SSD C1/§6). Only
/// shown when an API key is configured; off by default so the "No model API is
/// called" guarantee holds out of the box.
class _CloudEnrichmentToggle extends StatelessWidget {
  const _CloudEnrichmentToggle({required this.appState});

  final ContactLensState appState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = appState.cloudEnrichmentEnabled;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            on ? Icons.cloud_outlined : Icons.cloud_off_outlined,
            size: 18,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              on
                  ? 'Cloud enrichment ON — note & query text is sent to Anthropic (Claude).'
                  : 'Cloud enrichment OFF — all parsing & summarizing stays on-device.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          Switch(
            value: on,
            onChanged: (value) => appState.setCloudEnrichmentEnabled(value),
          ),
        ],
      ),
    );
  }
}

class _ContextualResultView extends StatelessWidget {
  const _ContextualResultView({
    required this.recommendation,
    this.rerankFired = false,
  });

  final ContextualRecommendation recommendation;
  final bool rerankFired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = recommendation.query;
    final result = recommendation.result;

    return ListView(
      children: [
        // Parsed filter chips: the demo visibly shows *why* a contact matched.
        _FilterChips(query: query),
        const SizedBox(height: 8),
        if (rerankFired)
          Card(
            color: theme.colorScheme.secondaryContainer,
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
            leading: Icon(
              result.filterApplied
                  ? Icons.filter_alt
                  : Icons.filter_alt_off_outlined,
            ),
            title: const Text('How this was answered'),
            subtitle: Text(result.explanation),
          ),
        ),
        const SizedBox(height: 8),
        if (result.results.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.search_off),
              title: Text('No matching contact'),
              subtitle: Text(
                  'Nothing in the local index matched. Add encounters with places, tags, and notes to improve recall.'),
            ),
          ),
        for (final retrieved in result.results)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    retrieved.contact.displayName,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (retrieved.contact.subtitle.isNotEmpty)
                    Text(retrieved.contact.subtitle),
                  const SizedBox(height: 8),
                  Text(retrieved.matchReason),
                  const SizedBox(height: 8),
                  if (retrieved.matchedFields.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final field in retrieved.matchedFields)
                          Chip(label: Text(field)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Local-first'),
            subtitle: Text(
                'Retrieval runs fully on-device and never invents background beyond saved contact data.'),
          ),
        ),
      ],
    );
  }
}

/// Renders the parsed 時間 / 地點 / 語意 constraints as chips above the results.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.query});

  final ContextualQuery query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    final time = query.timeRange;
    if (time != null && !time.isOpen) {
      chips.add(_chip(Icons.event, '時間', _timeLabel(time)));
    }
    final geo = query.geo;
    if (geo != null && !geo.isEmpty && geo.placeText.trim().isNotEmpty) {
      chips.add(_chip(Icons.place_outlined, '地點', geo.placeText.trim()));
    }
    final meaning = query.semanticText.trim();
    if (meaning.isNotEmpty) {
      chips.add(_chip(Icons.psychology_outlined, '語意', meaning));
    }

    if (chips.isEmpty) {
      return Text(
        'No time or place constraints detected — ranked by meaning across all contacts.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(IconData icon, String kind, String value) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$kind · $value'),
    );
  }

  static String _timeLabel(TimeRange range) {
    if (range.start != null && range.end != null) {
      return '${_date(range.start!)} – ${_date(range.end!)}';
    }
    if (range.start != null) {
      return '≥ ${_date(range.start!)}';
    }
    return '≤ ${_date(range.end!)}';
  }

  static String _date(DateTime t) {
    final u = t.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}-${two(u.month)}-${two(u.day)}';
  }
}
