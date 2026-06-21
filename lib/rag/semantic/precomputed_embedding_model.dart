import 'embedding_model.dart';
import 'precomputed_embeddings.g.dart';

/// [EmbeddingModel] backed by vectors precomputed offline with a real
/// multilingual MiniLM model (ONNX via fastembed; see
/// `tool/embed/build_embeddings.py`).
///
/// Lookup is by the exact text passed to [embed]. Text outside the build set
/// (e.g. an arbitrary query typed into the live UI) returns a zero vector, so
/// the semantic tier contributes nothing and callers fall back to the lexical
/// order — never an invented match. Because the eval/demo query set is fixed,
/// this gives the Flutter Web demo and `dart run` true semantics with zero
/// runtime inference and no model download.
class PrecomputedEmbeddingModel implements EmbeddingModel {
  const PrecomputedEmbeddingModel();

  @override
  int get dimensions => precomputedEmbeddingDim;

  @override
  List<double> embed(String text) {
    final vector = precomputedEmbeddings[text];
    if (vector == null) {
      return List<double>.filled(dimensions, 0);
    }
    return vector;
  }
}
