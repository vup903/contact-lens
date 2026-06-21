import 'package:http/http.dart' as http;

import 'claude_llm_adapter.dart';
import 'heuristic_llm_adapter.dart';
import 'llm_adapter.dart';

/// API key supplied at build time, e.g.
/// `--dart-define=ANTHROPIC_API_KEY=sk-ant-...`. Empty when unset.
const String _envApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');

/// Wraps a remote [primary] adapter so any failure transparently falls back to
/// a local [fallback] (the heuristic). This is what keeps the "never throw into
/// the UI, never block, never invent data" guarantee (C2): a Claude timeout or
/// parse error silently degrades to the deterministic local result.
class FallbackLlmAdapter implements LlmAdapter {
  const FallbackLlmAdapter({required this.primary, required this.fallback});

  final LlmAdapter primary;
  final LlmAdapter fallback;

  /// Reflects the configured intent (cloud enrichment on), not which path a
  /// given call happened to take.
  @override
  bool get isRemote => primary.isRemote;

  @override
  Future<NoteInsight> summarizeNote(String text, {DateTime? now}) async {
    try {
      return await primary.summarizeNote(text, now: now);
    } catch (_) {
      return fallback.summarizeNote(text, now: now);
    }
  }

  @override
  Future<ParsedQuery> parseQuery(
    String naturalLanguageQuery, {
    DateTime? now,
  }) async {
    try {
      return await primary.parseQuery(naturalLanguageQuery, now: now);
    } catch (_) {
      return fallback.parseQuery(naturalLanguageQuery, now: now);
    }
  }
}

/// Builds the adapter the app should use.
///
/// Returns a Claude-backed adapter (wrapped so failures fall back to the
/// heuristic) only when **both** an API key is configured ([apiKey], or the
/// `ANTHROPIC_API_KEY` dart-define) **and** the user has enabled
/// [cloudEnrichmentEnabled]. Otherwise returns the pure-Dart heuristic — the
/// default, so the "No model API is called" guarantee holds out of the box and
/// in the headless demo (C1).
LlmAdapter createLlmAdapter({
  String? apiKey,
  bool cloudEnrichmentEnabled = false,
  http.Client? client,
}) {
  const heuristic = HeuristicLlmAdapter();

  final resolvedKey = (apiKey ?? _envApiKey).trim();
  if (!cloudEnrichmentEnabled || resolvedKey.isEmpty) {
    return heuristic;
  }

  return FallbackLlmAdapter(
    primary: ClaudeLlmAdapter(apiKey: resolvedKey, client: client),
    fallback: heuristic,
  );
}

/// Whether a Claude API key is available (build-time define or [override]),
/// so the UI can decide whether to even show the "cloud enrichment" toggle.
bool hasConfiguredApiKey({String? override}) =>
    (override ?? _envApiKey).trim().isNotEmpty;
