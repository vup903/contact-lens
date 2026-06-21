// Headless demo for Contact Lens.
//
// Exercises the deterministic local RAG retrieval and the business card
// parser without a Flutter device, emulator, or browser. Useful for quick
// reviews, CI smoke checks, and live walkthroughs where only a terminal is
// available.
//
//   flutter pub get
//   dart run tool/demo.dart
//
// Optionally pass one or more business needs as arguments to override the
// default query set:
//
//   dart run tool/demo.dart "Find a Taiwan finance contact"
//
// This entry point imports only the pure-Dart layers (domain, rag, sample
// data, and the card parser). It deliberately avoids the scan barrel so it
// does not pull in mobile-only OCR plugins.

import 'dart:io';

import 'package:contact_lens/data/sample_data.dart';
import 'package:contact_lens/rag/rag.dart';
import 'package:contact_lens/scan/business_card_text_parser.dart';

const _demoQueries = <String>[
  'Find someone who can help with AI product fundraising',
  'Need a Taiwan finance contact',
  'Who knows vector search and data privacy?',
  'Find a product designer for mobile onboarding',
];

const _demoCard = '''
中央銀行外匯局
吳桂華
襄理
電話：(02)2357-1234 分機 321
手機：0912-345-678
Email: kuei.hua@example.gov.tw
地址：台北市中正區羅斯福路一段2號
''';

void main(List<String> args) {
  const recommender = LocalContactRecommender();
  final queries = args.isNotEmpty ? args : _demoQueries;

  stdout.writeln('Contact Lens — local RAG demo');
  stdout.writeln(
    'Indexed ${sampleContacts.length} sample contacts. No model API is called.\n',
  );

  for (final query in queries) {
    _runQuery(recommender, query);
  }

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
