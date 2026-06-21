import 'dart:convert';

import 'package:http/http.dart' as http;

import 'embedding_model.dart';
import 'precomputed_embeddings.g.dart';

/// [EmbeddingModel] that embeds *arbitrary* text at request time via a local
/// embedding service (`tool/embed/serve_embeddings.py`), so the live UI works on
/// free-form queries — not only the precomputed curated set.
///
/// [embed] stays synchronous (the retrieval pipeline is sync): it reads from a
/// runtime cache, then the baked [precomputedEmbeddings], then a zero vector.
/// Callers must first [warm] the texts they are about to score so the cache is
/// populated. If the service is unreachable, [warm] fails quietly and unknown
/// text resolves to a zero vector — the semantic tier simply contributes
/// nothing and results fall back to the lexical order (never an invented match).
class RuntimeEmbeddingModel implements EmbeddingModel {
  RuntimeEmbeddingModel({this.endpoint = 'http://localhost:8077/embed'});

  /// Local embedding service endpoint. Cross-origin from the Flutter Web dev
  /// server, so the service sends permissive CORS headers.
  final String endpoint;

  final Map<String, List<double>> _cache = <String, List<double>>{};

  /// Whether the last [warm] call reached the service. Lets the UI hint that
  /// free-form semantics need the service running.
  bool serviceReachable = false;

  @override
  int get dimensions => precomputedEmbeddingDim;

  @override
  List<double> embed(String text) {
    return _cache[text] ??
        precomputedEmbeddings[text] ??
        List<double>.filled(dimensions, 0);
  }

  bool _known(String text) =>
      _cache.containsKey(text) || precomputedEmbeddings.containsKey(text);

  /// Fetches embeddings for any [texts] not already cached or precomputed and
  /// stores them. Network/format failures are swallowed so the demo never
  /// crashes on a missing service.
  Future<void> warm(Iterable<String> texts) async {
    final missing = texts
        .where((text) => text.trim().isNotEmpty && !_known(text))
        .toSet()
        .toList();
    if (missing.isEmpty) {
      return;
    }
    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'texts': missing}),
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        serviceReachable = false;
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final vectors = (data['vectors'] as List).cast<List<dynamic>>();
      for (var i = 0; i < missing.length && i < vectors.length; i += 1) {
        _cache[missing[i]] = vectors[i]
            .map((value) => (value as num).toDouble())
            .toList(growable: false);
      }
      serviceReachable = true;
    } catch (_) {
      serviceReachable = false;
    }
  }
}
