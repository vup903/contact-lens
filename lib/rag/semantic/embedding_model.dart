import 'vector_ops.dart';

/// Strategy interface for turning text into a fixed-length vector. The hybrid
/// reranker depends only on this, so a heavier model (e.g. ONNX MiniLM) can be
/// swapped in behind the same contract without touching callers. The default
/// implementation is [HashingEmbeddingModel], which needs no model download.
abstract class EmbeddingModel {
  /// Length of every vector returned by [embed]. Fixed for a given model so
  /// vectors are directly comparable with [cosineSimilarity].
  int get dimensions;

  /// Maps [text] to an L2-normalized vector of length [dimensions].
  List<double> embed(String text);
}

/// Deterministic, dependency-free embedding via the hashing trick.
///
/// Text is broken into word unigrams plus padded character n-grams (so
/// "fundraise" and "fundraising" share most features, and CJK runs like
/// "外匯" produce overlapping grams). Each feature is hashed into a fixed-width
/// vector with a separate sign hash to keep collisions roughly unbiased, then
/// the vector is L2-normalized. Same text always yields the same vector, which
/// makes it offline-friendly and trivially testable.
class HashingEmbeddingModel implements EmbeddingModel {
  const HashingEmbeddingModel({
    this.dimensions = 256,
    this.minGram = 2,
    this.maxGram = 4,
  })  : assert(dimensions > 0, 'dimensions must be positive'),
        assert(minGram >= 1 && minGram <= maxGram, 'require 1 <= minGram <= maxGram');

  @override
  final int dimensions;

  /// Smallest character n-gram length (inclusive).
  final int minGram;

  /// Largest character n-gram length (inclusive).
  final int maxGram;

  @override
  List<double> embed(String text) {
    final vector = List<double>.filled(dimensions, 0);
    final normalized = _normalize(text);
    if (normalized.isEmpty) {
      return vector;
    }

    for (final word in normalized.split(' ')) {
      if (word.isEmpty) {
        continue;
      }
      _accumulate(vector, 'w:$word', 1);
      // Pad so leading/trailing grams are distinct (^fu, se$), which preserves
      // word-boundary signal for short tokens and CJK runs alike.
      final padded = '^$word\$';
      for (var n = minGram; n <= maxGram; n += 1) {
        if (padded.length < n) {
          break;
        }
        for (var i = 0; i + n <= padded.length; i += 1) {
          _accumulate(vector, 'g:${padded.substring(i, i + n)}', 1);
        }
      }
    }

    return l2Normalize(vector);
  }

  void _accumulate(List<double> vector, String feature, double weight) {
    final hash = _fnv1a(feature);
    final index = hash % dimensions;
    // A second, independent hash decides the sign so feature collisions tend to
    // cancel rather than always reinforce one direction.
    final sign = (_fnv1a('$feature#') & 1) == 0 ? 1.0 : -1.0;
    vector[index] += sign * weight;
  }

  String _normalize(String text) {
    final buffer = StringBuffer();
    bool? prevWasCjk;
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      if (_isCjk(rune)) {
        // Keep CJK runs contiguous so n-grams capture adjacent-character pairs
        // (外匯, 匯局); only break at the latin↔CJK boundary.
        if (prevWasCjk == false) {
          buffer.write(' ');
        }
        buffer.write(char);
        prevWasCjk = true;
      } else if (_isAlphaNumeric(rune)) {
        if (prevWasCjk == true) {
          buffer.write(' ');
        }
        buffer.write(char);
        prevWasCjk = false;
      } else {
        buffer.write(' ');
        prevWasCjk = null;
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isCjk(int rune) => rune >= 0x3400 && rune <= 0x9fff;

  static bool _isAlphaNumeric(int rune) {
    return (rune >= 0x30 && rune <= 0x39) || // 0-9
        (rune >= 0x61 && rune <= 0x7a); // a-z (already lowercased)
  }

  /// 32-bit FNV-1a, masked to stay within the JS-safe / Dart int range.
  static int _fnv1a(String s) {
    var hash = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
