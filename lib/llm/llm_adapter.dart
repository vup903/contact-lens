/// Generative LLM contract for the two enrichment tasks in the SSD:
///
///  * [summarizeNote] turns a free-form encounter note (typed or transcribed)
///    into a one-line [NoteInsight.summary] plus structured [NoteInsight.tags].
///  * [parseQuery] turns a natural-language search question into the structured
///    [ParsedQuery] constraints the contextual retriever filters on.
///
/// Two implementations satisfy this contract: a remote `ClaudeLlmAdapter`
/// (raw HTTP, opt-in) and a pure-Dart `HeuristicLlmAdapter` (the default and
/// the only adapter the headless demo and tests use). Everything here is pure
/// Dart so the contract can be imported by the offline demo path (C3).
library;

/// Result of enriching an encounter note.
class NoteInsight {
  const NoteInsight({required this.summary, required this.tags});

  /// Empty insight — the safe value when there is nothing to enrich.
  const NoteInsight.empty() : summary = '', tags = const <String>[];

  /// One-line, human-readable summary of the note.
  final String summary;

  /// Short, lowercase, deduped topical tags (skills, roles, interests).
  final List<String> tags;

  @override
  String toString() => 'NoteInsight(summary: "$summary", tags: $tags)';
}

/// Structured form of a natural-language search question. The UI maps this into
/// a `ContextualQuery` (time + place + meaning) for the contextual retriever.
class ParsedQuery {
  const ParsedQuery({
    required this.semanticText,
    this.startUtc,
    this.endUtc,
    this.locationText = '',
  });

  /// Residual meaning with any time/place phrases removed, e.g. for
  /// "the ML engineer I met last month in San Francisco" this is roughly
  /// "ML engineer I met". Ranked by the existing semantic retriever.
  final String semanticText;

  /// Inclusive UTC bounds of any time period mentioned; `null` = open bound.
  final DateTime? startUtc;
  final DateTime? endUtc;

  /// Place/city mentioned, e.g. "San Francisco"; empty when none.
  final String locationText;

  @override
  String toString() =>
      'ParsedQuery(semanticText: "$semanticText", startUtc: $startUtc, '
      'endUtc: $endUtc, locationText: "$locationText")';
}

/// Generative enrichment used by note capture and query understanding.
abstract class LlmAdapter {
  /// Summarizes and tags an encounter [text]. [now] is accepted for symmetry
  /// with [parseQuery]; note enrichment does not depend on the current time.
  Future<NoteInsight> summarizeNote(String text, {DateTime? now});

  /// Parses a search question into structured constraints. Relative dates
  /// ("last month", 「上個月」) are resolved against [now] (defaults to the
  /// current time when omitted) so the result is deterministic in tests (C5).
  Future<ParsedQuery> parseQuery(String naturalLanguageQuery, {DateTime? now});

  /// `true` when this adapter calls Claude, `false` for the heuristic path.
  bool get isRemote;
}
