import 'package:contact_lens/llm/heuristic_llm_adapter.dart';
import 'package:contact_lens/llm/llm_adapter.dart';
import 'package:contact_lens/llm/llm_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Always-failing remote stand-in for the Claude adapter.
class _ThrowingAdapter implements LlmAdapter {
  @override
  bool get isRemote => true;

  @override
  Future<NoteInsight> summarizeNote(String text, {DateTime? now}) =>
      throw Exception('boom');

  @override
  Future<ParsedQuery> parseQuery(String naturalLanguageQuery, {DateTime? now}) =>
      throw Exception('boom');
}

void main() {
  group('FallbackLlmAdapter', () {
    const heuristic = HeuristicLlmAdapter();
    final fallback = FallbackLlmAdapter(
      primary: _ThrowingAdapter(),
      fallback: heuristic,
    );

    test('reports the configured (remote) intent', () {
      expect(fallback.isRemote, isTrue);
    });

    test('summarizeNote falls back to the heuristic on failure', () async {
      final insight = await fallback.summarizeNote('A machine learning founder.');
      expect(insight.tags, containsAll(<String>['machine learning', 'founder']));
    });

    test('parseQuery falls back to the heuristic on failure', () async {
      final parsed = await fallback.parseQuery(
        'met last month in Tokyo',
        now: DateTime.utc(2026, 6, 21),
      );
      expect(parsed.startUtc, DateTime.utc(2026, 5, 1));
      expect(parsed.locationText, 'Tokyo');
    });
  });

  group('createLlmAdapter', () {
    test('defaults to the heuristic when no key / cloud disabled', () {
      expect(createLlmAdapter(), isA<HeuristicLlmAdapter>());
      expect(
        createLlmAdapter(apiKey: 'sk-test', cloudEnrichmentEnabled: false),
        isA<HeuristicLlmAdapter>(),
      );
    });

    test('an enabled key with no value still yields the heuristic', () {
      expect(
        createLlmAdapter(apiKey: '   ', cloudEnrichmentEnabled: true),
        isA<HeuristicLlmAdapter>(),
      );
    });

    test('a configured key + enabled cloud yields the fallback wrapper', () {
      final adapter = createLlmAdapter(
        apiKey: 'sk-test',
        cloudEnrichmentEnabled: true,
      );
      expect(adapter, isA<FallbackLlmAdapter>());
      expect(adapter.isRemote, isTrue);
    });
  });
}
