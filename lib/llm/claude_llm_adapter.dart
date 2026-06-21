import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_adapter.dart';

/// Remote [LlmAdapter] backed by the Anthropic Messages API over raw HTTP —
/// Dart has no official Anthropic SDK, so this mirrors the `http`-based approach
/// `RuntimeEmbeddingModel` already uses. Constructed only when an API key is
/// present and "cloud enrichment" is enabled; see `llm_config.dart`.
///
/// This is the **only** network feature in the app and sends note/query text to
/// Anthropic (C1). Both calls request guaranteed-parseable JSON via
/// `output_config.format`. Any non-200 / timeout / malformed response throws;
/// the fallback decorator in `llm_config.dart` turns that into the heuristic
/// result so nothing ever throws into the UI (C2).
class ClaudeLlmAdapter implements LlmAdapter {
  ClaudeLlmAdapter({
    required this.apiKey,
    http.Client? client,
    this.model = 'claude-opus-4-8',
    this.endpoint = 'https://api.anthropic.com/v1/messages',
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final String endpoint;
  final Duration timeout;
  final http.Client _client;

  static const _anthropicVersion = '2023-06-01';
  static const _maxTokens = 1024;

  @override
  bool get isRemote => true;

  static const Map<String, Object?> _noteSchema = {
    'type': 'object',
    'properties': {
      'summary': {'type': 'string'},
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['summary', 'tags'],
    'additionalProperties': false,
  };

  static const Map<String, Object?> _querySchema = {
    'type': 'object',
    'properties': {
      'semanticText': {'type': 'string'},
      'startUtc': {
        'anyOf': [
          {'type': 'string'},
          {'type': 'null'},
        ],
      },
      'endUtc': {
        'anyOf': [
          {'type': 'string'},
          {'type': 'null'},
        ],
      },
      'locationText': {'type': 'string'},
    },
    'required': ['semanticText', 'startUtc', 'endUtc', 'locationText'],
    'additionalProperties': false,
  };

  @override
  Future<NoteInsight> summarizeNote(String text, {DateTime? now}) async {
    final data = await _complete(
      system:
          'You extract a concise one-line summary and a short list of lowercase '
          'topical tags from a professional contact-encounter note. Tags are 1-6 '
          'short keywords (skills, roles, interests, topics), lowercase and '
          'deduplicated. Respond using the provided JSON schema.',
      userText: text,
      schema: _noteSchema,
    );

    final tags = (data['tags'] as List? ?? const [])
        .map((tag) => tag.toString().trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return NoteInsight(
      summary: (data['summary'] as String? ?? '').trim(),
      tags: tags,
    );
  }

  @override
  Future<ParsedQuery> parseQuery(
    String naturalLanguageQuery, {
    DateTime? now,
  }) async {
    final reference = (now ?? DateTime.now()).toUtc();
    final data = await _complete(
      system:
          'You convert a natural-language contact-search question into structured '
          'search constraints. Extract: "semanticText" (the residual meaning with '
          'time and place phrases removed, used for semantic search); "startUtc" '
          'and "endUtc" (ISO 8601 UTC timestamps bounding any time period '
          'mentioned, inclusive, or null); and "locationText" (a place or city '
          'mentioned, or an empty string). Resolve relative dates against the '
          'provided current time. Respond using the provided JSON schema.',
      userText:
          'Current time (UTC): ${reference.toIso8601String()}\n'
          'Question: $naturalLanguageQuery',
      schema: _querySchema,
    );

    return ParsedQuery(
      semanticText: (data['semanticText'] as String? ?? '').trim(),
      startUtc: _parseUtc(data['startUtc']),
      endUtc: _parseUtc(data['endUtc']),
      locationText: (data['locationText'] as String? ?? '').trim(),
    );
  }

  /// Posts a single-shot structured-output request and returns the decoded JSON
  /// object. Throws on any transport, status, refusal, or parse failure.
  Future<Map<String, dynamic>> _complete({
    required String system,
    required String userText,
    required Map<String, Object?> schema,
  }) async {
    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': _anthropicVersion,
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': _maxTokens,
            'system': system,
            'messages': [
              {'role': 'user', 'content': userText},
            ],
            'output_config': {
              'format': {'type': 'json_schema', 'schema': schema},
            },
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Anthropic API returned ${response.statusCode}',
        Uri.parse(endpoint),
      );
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (body['stop_reason'] == 'refusal') {
      throw const FormatException('Anthropic API refused the request');
    }

    final content = body['content'] as List? ?? const [];
    final textBlock = content.cast<Map<String, dynamic>>().firstWhere(
          (block) => block['type'] == 'text',
          orElse: () => throw const FormatException('No text block in response'),
        );

    return jsonDecode(textBlock['text'] as String) as Map<String, dynamic>;
  }

  static DateTime? _parseUtc(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.trim())?.toUtc();
  }
}
