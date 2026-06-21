import 'dart:convert';

import 'package:contact_lens/llm/claude_llm_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Wraps [text] in the shape the Anthropic Messages API returns for a
/// structured-output request: the first text block holds the JSON payload.
http.Response _anthropicResponse(String text, {String stopReason = 'end_turn'}) {
  return http.Response(
    jsonEncode({
      'content': [
        {'type': 'text', 'text': text},
      ],
      'stop_reason': stopReason,
    }),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

void main() {
  test('summarizeNote posts the right request and parses the JSON', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return _anthropicResponse(
        jsonEncode({
          'summary': 'ML engineer met in SF',
          'tags': ['machine learning', 'engineer'],
        }),
      );
    });

    final adapter = ClaudeLlmAdapter(apiKey: 'sk-test', client: client);
    final insight = await adapter.summarizeNote('note text');

    expect(adapter.isRemote, isTrue);
    expect(insight.summary, 'ML engineer met in SF');
    expect(insight.tags, ['machine learning', 'engineer']);

    // Request shape per the frozen SSD contract.
    expect(captured.url.toString(), 'https://api.anthropic.com/v1/messages');
    expect(captured.headers['x-api-key'], 'sk-test');
    expect(captured.headers['anthropic-version'], '2023-06-01');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'claude-opus-4-8');
    final format =
        (body['output_config'] as Map)['format'] as Map<String, dynamic>;
    expect(format['type'], 'json_schema');
  });

  test('parseQuery parses ISO bounds into UTC DateTimes', () async {
    final client = MockClient((request) async {
      return _anthropicResponse(
        jsonEncode({
          'semanticText': 'machine learning engineer',
          'startUtc': '2026-05-01T00:00:00Z',
          'endUtc': '2026-05-31T23:59:59Z',
          'locationText': 'San Francisco',
        }),
      );
    });

    final adapter = ClaudeLlmAdapter(apiKey: 'sk-test', client: client);
    final parsed = await adapter.parseQuery(
      'ML engineer last month in SF',
      now: DateTime.utc(2026, 6, 21),
    );

    expect(parsed.semanticText, 'machine learning engineer');
    expect(parsed.startUtc, DateTime.utc(2026, 5, 1));
    expect(parsed.endUtc, DateTime.utc(2026, 5, 31, 23, 59, 59));
    expect(parsed.locationText, 'San Francisco');
  });

  test('null bounds parse to null DateTimes', () async {
    final client = MockClient((request) async {
      return _anthropicResponse(
        jsonEncode({
          'semanticText': 'designer',
          'startUtc': null,
          'endUtc': null,
          'locationText': '',
        }),
      );
    });

    final adapter = ClaudeLlmAdapter(apiKey: 'sk-test', client: client);
    final parsed = await adapter.parseQuery('a designer');

    expect(parsed.startUtc, isNull);
    expect(parsed.endUtc, isNull);
    expect(parsed.locationText, isEmpty);
  });

  test('non-200 response throws', () async {
    final client = MockClient((request) async => http.Response('nope', 500));
    final adapter = ClaudeLlmAdapter(apiKey: 'sk-test', client: client);
    expect(adapter.summarizeNote('x'), throwsA(isA<http.ClientException>()));
  });

  test('a refusal stop reason throws', () async {
    final client = MockClient(
      (request) async => _anthropicResponse('{}', stopReason: 'refusal'),
    );
    final adapter = ClaudeLlmAdapter(apiKey: 'sk-test', client: client);
    expect(adapter.summarizeNote('x'), throwsA(isA<FormatException>()));
  });
}
