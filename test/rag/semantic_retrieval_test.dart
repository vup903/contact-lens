import 'package:contact_lens/data/sample_data.dart';
import 'package:contact_lens/rag/hybrid_retriever.dart';
import 'package:contact_lens/rag/rag.dart';
import 'package:contact_lens/rag/semantic_contact_retriever.dart';
import 'package:contact_lens/rag/semantic/precomputed_embedding_model.dart';
import 'package:contact_lens/rag/semantic/semantic_reranker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const model = PrecomputedEmbeddingModel();

  // A Chinese query with no token overlap against the English-only Alex contact.
  // It is part of the precomputed build set (see lib/eval/eval_dataset.dart).
  const crossLanguageQuery = '需要懂資料落地與企業內部署的資安顧問';

  test('precomputed model returns a real vector for known text, zeros otherwise', () {
    final known = model.embed(crossLanguageQuery);
    expect(known.length, model.dimensions);
    expect(known.any((value) => value != 0), isTrue);

    final unknown = model.embed('a string never embedded at build time');
    expect(unknown.length, model.dimensions);
    expect(unknown.every((value) => value == 0), isTrue,
        reason: 'unknown text must fall back to a zero vector, not invent signal');
  });

  test('lexical tier misses the cross-language query', () {
    final lexical =
        const WeightedContactRetriever().retrieve(crossLanguageQuery, sampleContacts);
    expect(
      lexical.where((r) => r.contact.id == 'sample-alex-chen'),
      isEmpty,
      reason: 'no shared tokens, so lexical cannot recall Alex',
    );
  });

  test('semantic tier recalls the cross-language match lexical cannot', () {
    final semantic = const SemanticContactRetriever(model: model)
        .retrieve(crossLanguageQuery, sampleContacts);
    expect(semantic, isNotEmpty);
    expect(semantic.first.contact.id, 'sample-alex-chen');
  });

  test('semantic tier returns nothing for an unembedded query (no invented match)', () {
    final semantic = const SemanticContactRetriever(model: model)
        .retrieve('a string never embedded at build time', sampleContacts);
    expect(semantic, isEmpty);
  });

  test('hybrid recall surfaces the semantic match in its top result', () {
    const hybrid = HybridContactRetriever(
      reranker: SemanticReranker(model: model),
      semantic: SemanticContactRetriever(model: model),
    );
    final results = hybrid.retrieve(crossLanguageQuery, sampleContacts);
    expect(results, isNotEmpty);
    expect(results.first.contact.id, 'sample-alex-chen');
  });

  test('hybrid without a semantic tier keeps the original rerank-only behavior', () {
    const hybrid = HybridContactRetriever();
    final results =
        hybrid.retrieve('enterprise AI solutions architect', sampleContacts);
    expect(results.first.contact.id, 'sample-alex-chen');
  });
}
