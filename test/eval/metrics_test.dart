import 'package:contact_lens/eval/metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('precisionAtK', () {
    const relevance = <String, double>{'a': 3, 'c': 1};
    const ranked = <String>['a', 'b', 'c', 'd'];

    test('counts hits within the cutoff over k', () {
      expect(precisionAtK(ranked, relevance, 1), 1.0); // a hit / 1
      expect(precisionAtK(ranked, relevance, 3), closeTo(2 / 3, 1e-9)); // a,c
      expect(precisionAtK(ranked, relevance, 4), 0.5); // 2 / 4
    });

    test('denominator stays k when fewer results are returned', () {
      expect(precisionAtK(const ['a', 'b'], relevance, 4), 0.25); // 1 hit / 4
    });

    test('is 0 for non-positive k or no relevant hits', () {
      expect(precisionAtK(ranked, relevance, 0), 0);
      expect(precisionAtK(const ['b', 'd'], relevance, 3), 0);
    });
  });

  group('dcgAtK', () {
    test('matches the closed-form sum of gain / log2(i + 2)', () {
      const relevance = <String, double>{'a': 3, 'b': 2, 'c': 1};
      // 3/log2(2) + 2/log2(3) + 1/log2(4) = 3 + 1.261859... + 0.5
      expect(
        dcgAtK(const ['a', 'b', 'c'], relevance, 3),
        closeTo(4.761859507, 1e-6),
      );
    });
  });

  group('ndcgAtK', () {
    const relevance = <String, double>{'a': 3, 'b': 2, 'c': 1};

    test('ideal ordering scores 1.0', () {
      expect(ndcgAtK(const ['a', 'b', 'c'], relevance, 3), closeTo(1.0, 1e-9));
    });

    test('reversed ordering is penalised', () {
      // DCG = 1 + 2/log2(3) + 3/2 = 3.761859 ; IDCG = 4.761859
      expect(ndcgAtK(const ['c', 'b', 'a'], relevance, 3), closeTo(0.7900, 1e-3));
    });

    test('single relevant hit at rank 2', () {
      // DCG@2 = 1/log2(3) = 0.630930 ; IDCG@2 = 1/log2(2) = 1
      expect(
        ndcgAtK(const ['x', 'a'], const {'a': 1}, 2),
        closeTo(0.630930, 1e-6),
      );
    });

    test('is 0 when there is no relevant item (IDCG == 0)', () {
      expect(ndcgAtK(const ['x', 'y'], const <String, double>{}, 5), 0);
    });
  });

  group('recallAtK', () {
    const relevance = <String, double>{'a': 1, 'b': 1, 'c': 1};

    test('fraction of all relevant items found within k', () {
      expect(recallAtK(const ['a', 'x', 'b'], relevance, 3), closeTo(2 / 3, 1e-9));
      expect(recallAtK(const ['a', 'x', 'b'], relevance, 1), closeTo(1 / 3, 1e-9));
    });

    test('is 0 when nothing is relevant', () {
      expect(recallAtK(const ['a', 'b'], const <String, double>{}, 5), 0);
    });
  });
}
