import 'package:contact_lens/rag/semantic/vector_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('l2Norm', () {
    test('computes Euclidean length', () {
      expect(l2Norm(<double>[3, 4]), closeTo(5, 1e-12));
    });

    test('is zero for the zero vector', () {
      expect(l2Norm(<double>[0, 0, 0]), 0);
    });
  });

  group('l2Normalize', () {
    test('scales to unit length', () {
      final unit = l2Normalize(<double>[3, 4]);
      expect(l2Norm(unit), closeTo(1, 1e-12));
      expect(unit[0], closeTo(0.6, 1e-12));
      expect(unit[1], closeTo(0.8, 1e-12));
    });

    test('returns the zero vector unchanged instead of dividing by zero', () {
      expect(l2Normalize(<double>[0, 0]), <double>[0, 0]);
    });
  });

  group('cosineSimilarity', () {
    test('is 1 for identical directions', () {
      expect(cosineSimilarity(<double>[1, 2, 3], <double>[2, 4, 6]), closeTo(1, 1e-12));
    });

    test('is 0 for orthogonal vectors', () {
      expect(cosineSimilarity(<double>[1, 0], <double>[0, 1]), closeTo(0, 1e-12));
    });

    test('is -1 for opposite directions', () {
      expect(cosineSimilarity(<double>[1, 1], <double>[-1, -1]), closeTo(-1, 1e-12));
    });

    test('is 0 when either vector is all-zero', () {
      expect(cosineSimilarity(<double>[0, 0], <double>[1, 1]), 0);
    });
  });

  test('dotProduct rejects mismatched dimensions', () {
    expect(() => dotProduct(<double>[1, 2], <double>[1]), throwsArgumentError);
  });
}
