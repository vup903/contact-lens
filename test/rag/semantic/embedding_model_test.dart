import 'package:contact_lens/rag/semantic/embedding_model.dart';
import 'package:contact_lens/rag/semantic/vector_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const model = HashingEmbeddingModel();

  test('produces a fixed-dimension vector', () {
    expect(model.embed('hello world').length, model.dimensions);
  });

  test('is deterministic for the same input', () {
    expect(model.embed('AI fundraising'), model.embed('AI fundraising'));
  });

  test('output is L2-normalized for non-empty text', () {
    expect(l2Norm(model.embed('vector search')), closeTo(1, 1e-9));
  });

  test('empty / non-indexable text yields the zero vector', () {
    expect(model.embed('').every((v) => v == 0), isTrue);
    expect(model.embed('   !!!   ').every((v) => v == 0), isTrue);
  });

  test('morphological variants are more similar than unrelated text', () {
    final fundraise = model.embed('fundraise');
    final fundraising = model.embed('fundraising');
    final unrelated = model.embed('design screenshots');
    expect(
      cosineSimilarity(fundraise, fundraising),
      greaterThan(cosineSimilarity(fundraise, unrelated)),
    );
  });

  test('captures adjacent-character signal for CJK runs', () {
    // Shared 外匯 / 匯局 bigrams should pull these closer than an unrelated
    // CJK name.
    final forex = model.embed('外匯局');
    final central = model.embed('中央銀行外匯局');
    final name = model.embed('林美雅');
    expect(
      cosineSimilarity(forex, central),
      greaterThan(cosineSimilarity(forex, name)),
    );
  });

  test('respects a custom dimension', () {
    const small = HashingEmbeddingModel(dimensions: 32);
    expect(small.embed('hello').length, 32);
  });
}
