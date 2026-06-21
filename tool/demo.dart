// Headless demo for Contact Lens.
//
// Exercises the deterministic local RAG retrieval, the automated context
// capture (note → summary + tags), and the contextual time + place + meaning
// query — all without a Flutter device, emulator, or browser. Useful for quick
// reviews, CI smoke checks, and live walkthroughs where only a terminal is
// available.
//
//   flutter pub get
//   dart run tool/demo.dart
//
// Optionally pass one or more business needs as arguments to override the
// default keyword query set:
//
//   dart run tool/demo.dart "Find a Taiwan finance contact"
//
// This entry point imports only the pure-Dart layers (domain, rag, the
// heuristic LLM adapter, sample data, and the card parser). It deliberately
// avoids the scan barrel and the Claude adapter, so it pulls in no mobile
// plugins and makes no network calls — "No model API is called" holds here.

import 'dart:io';

import 'package:contact_lens/data/sample_data.dart';
import 'package:contact_lens/llm/heuristic_llm_adapter.dart';
import 'package:contact_lens/rag/rag.dart';
import 'package:contact_lens/scan/business_card_text_parser.dart';

// Fixed clock so relative phrases ("last month" / 「上個月」) resolve
// deterministically and the demo stays offline + reproducible (SSD C3/C5).
final _demoNow = DateTime.utc(2026, 6, 21);

// The default, pure-Dart adapter — the only one the demo and tests use.
const _adapter = HeuristicLlmAdapter();

const _demoQueries = <String>[
  'Find someone who can help with AI product fundraising',
  'Need a Taiwan finance contact',
  'Who knows vector search and data privacy?',
  'Find a product designer for mobile onboarding',
];

// Flagship contextual queries (time + place + meaning), in Traditional Chinese
// and English. Both should surface the seeded SF/ML engineer, Daniel Rivera.
const _contextualQueries = <String>[
  '上個月在舊金山見面、做機器學習那個工程師叫什麼？',
  'Who was the ML engineer I met last month in San Francisco?',
];

const _demoNote =
    'Talked with a startup founder about machine learning and fundraising for '
    'their fintech product.';

const _demoCard = '''
中央銀行外匯局
吳桂華
襄理
電話：(02)2357-1234 分機 321
手機：0912-345-678
Email: kuei.hua@example.gov.tw
地址：台北市中正區羅斯福路一段2號
''';

Future<void> main(List<String> args) async {
  const recommender = LocalContactRecommender();
  final queries = args.isNotEmpty ? args : _demoQueries;

  stdout.writeln('Contact Lens — local RAG demo');
  stdout.writeln(
    'Indexed ${sampleContacts.length} sample contacts. No model API is called.\n',
  );

  stdout
      .writeln('── Keyword retrieval ───────────────────────────────────────');
  for (final query in queries) {
    _runQuery(recommender, query);
  }

  // Feature 1 — automated context capture: note → heuristic summary + tags.
  stdout
      .writeln('── Note enrichment (Feature 1) ─────────────────────────────');
  await _runNoteSummary();

  // Feature 2 — semantic retrieval with time + place.
  stdout
      .writeln('── Contextual retrieval (Feature 2) ────────────────────────');
  for (final query in _contextualQueries) {
    await _runContextualQuery(query);
  }

  stdout
      .writeln('── Business card parser ────────────────────────────────────');
  _runScanDemo();
}

void _runQuery(LocalContactRecommender recommender, String query) {
  final result = recommender.recommend(query, sampleContacts);
  stdout.writeln('> $query');
  stdout.writeln('  ${result.analysis}');
  if (result.recommendations.isEmpty) {
    stdout.writeln('  (no match) ${result.suggestions}');
  } else {
    for (final rec in result.recommendations) {
      final subtitle = rec.contact.subtitle;
      final fields = rec.matchedFields.join(', ');
      stdout.writeln(
        '  • ${rec.contact.displayName}'
        '${subtitle.isEmpty ? '' : ' — $subtitle'}'
        '  [score ${rec.score.toStringAsFixed(1)}; $fields]',
      );
      stdout.writeln('      ${rec.reason}');
    }
  }
  stdout.writeln('');
}

Future<void> _runNoteSummary() async {
  stdout.writeln('  note    : $_demoNote');
  final insight = await _adapter.summarizeNote(_demoNote);
  stdout.writeln('  summary : ${insight.summary}');
  stdout.writeln('  tags    : ${insight.tags.join(', ')}');
  stdout.writeln('');
}

Future<void> _runContextualQuery(String rawQuery) async {
  // Parse the natural-language question into structured constraints, then map
  // them onto the encounter-aware contextual retriever (lexical base here).
  final parsed = await _adapter.parseQuery(rawQuery, now: _demoNow);
  final query = ContextualQuery.fromParsedQuery(parsed, rawQuery: rawQuery);
  final retriever = ContextualRetriever(base: const WeightedContactRetriever());
  final result = retriever.retrieve(query, sampleContacts, k: 3);

  stdout.writeln('? $rawQuery');
  stdout.writeln('  parsed  → ${_describeFilters(query)}');
  stdout.writeln('  ${result.explanation}');
  if (result.results.isEmpty) {
    stdout.writeln('  (no match)');
  } else {
    for (final retrieved in result.results) {
      final subtitle = retrieved.contact.subtitle;
      stdout.writeln(
        '  • ${retrieved.contact.displayName}'
        '${subtitle.isEmpty ? '' : ' — $subtitle'}'
        '  [score ${retrieved.score.toStringAsFixed(2)}]',
      );
      stdout.writeln('      ${retrieved.matchReason}');
    }
  }
  stdout.writeln('');
}

String _describeFilters(ContextualQuery q) {
  final parts = <String>[];
  final time = q.timeRange;
  if (time != null && !time.isOpen) {
    parts.add('time ${_date(time.start)}…${_date(time.end)}');
  }
  final geo = q.geo;
  if (geo != null && !geo.isEmpty && geo.placeText.trim().isNotEmpty) {
    parts.add('place "${geo.placeText.trim()}"');
  }
  if (q.semanticText.trim().isNotEmpty) {
    parts.add('meaning "${q.semanticText.trim()}"');
  }
  return parts.isEmpty ? 'no constraints' : parts.join(', ');
}

String _date(DateTime? t) {
  if (t == null) {
    return '∞';
  }
  final u = t.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}-${two(u.month)}-${two(u.day)}';
}

void _runScanDemo() {
  final parsed = parseBusinessCardText(_demoCard);
  stdout.writeln('Business card parser (local rules, no cloud OCR call)');
  stdout.writeln('  name      : ${parsed.name}');
  stdout.writeln('  company   : ${parsed.company}');
  stdout.writeln('  job title : ${parsed.jobTitle}');
  stdout.writeln('  phone     : ${parsed.phone}');
  stdout.writeln('  mobile    : ${parsed.mobilePhone}');
  stdout.writeln('  email     : ${parsed.email}');
  stdout.writeln('  address   : ${parsed.address}');
}
