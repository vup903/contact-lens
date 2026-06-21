import 'dart:math' as math;

/// Pure vector math shared by the semantic tier. Kept dependency-free so the
/// default hashing embedding path never needs a native package.

/// Euclidean (L2) length of [vector].
double l2Norm(List<double> vector) {
  var sumSquares = 0.0;
  for (final value in vector) {
    sumSquares += value * value;
  }
  return math.sqrt(sumSquares);
}

/// Returns a new vector scaled to unit L2 length. A zero vector is returned
/// unchanged so callers never divide by zero.
List<double> l2Normalize(List<double> vector) {
  final norm = l2Norm(vector);
  if (norm == 0) {
    return List<double>.of(vector);
  }
  return List<double>.generate(vector.length, (i) => vector[i] / norm, growable: false);
}

/// Dot product of two equal-length vectors.
double dotProduct(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError('Vectors must share a dimension: ${a.length} vs ${b.length}');
  }
  var sum = 0.0;
  for (var i = 0; i < a.length; i += 1) {
    sum += a[i] * b[i];
  }
  return sum;
}

/// Cosine similarity in [-1, 1]. Returns 0 when either vector is all-zero
/// (no shared dimension to compare), which keeps it well-defined for empty
/// queries or contacts with no indexable text.
double cosineSimilarity(List<double> a, List<double> b) {
  final normA = l2Norm(a);
  final normB = l2Norm(b);
  if (normA == 0 || normB == 0) {
    return 0;
  }
  return dotProduct(a, b) / (normA * normB);
}
