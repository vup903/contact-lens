# Retrieval: lexical baseline, semantic rerank, and the hybrid gate

This is the core engineering story of Contact Lens. The claim is not "we built a
search box." The claim is:

> We treat retrieval quality as a **cost/latency tradeoff**, build a cheap tier
> and a strong tier behind one interface, and let a **measured confidence gate**
> decide per query which one to pay for.

Everything here is written against the frozen contracts in
[`SDD_retrieval_v2.md`](SDD_retrieval_v2.md) §3, so it holds regardless of the
order the implementation lands.

## The shared contract

Every tier is one `ContactRetriever`:

```dart
abstract class ContactRetriever {
  List<RetrievedContact> retrieve(String userNeed, List<Contact> contacts, {int k});
}
```

Because the lexical baseline, the semantic reranker, and the hybrid all satisfy
this single interface:

- the **eval harness** can score any of them with the same `runEval(...)` call,
- the **UI** can swap strategies (and toggle hybrid on/off) without code changes,
- a future **cloud LLM tier** drops in behind the same method signature.

The interface is the thing that makes "tiered and cost-aware" an architecture
rather than a slogan.

## Tier 1 — lexical baseline (`WeightedContactRetriever`)

Each contact is projected into a small document (`name`, `company`, `jobTitle`,
`groups`, `other`). A query is tokenized (Latin + CJK), matched per field, scored
with field weights, and given a phrase boost. Results carry their matched fields
and a deterministic reason string.

**Why it's the default tier**

| Property | Value |
|---|---|
| Cost / query | ~0 — pure Dart, in-memory scan, no model |
| Latency | sub-millisecond |
| Explainability | total — you can point at the field and token that scored |
| Failure mode | brittle on **intent and synonyms**: "fundraising help" won't match a contact described as "venture partner, seed-stage" if no tokens overlap |

For high keyword-overlap queries this tier is not just *cheap enough* — it is
genuinely *good*, and a more expensive tier would not change the answer. Paying
model cost there would be waste.

## Tier 2 — semantic rerank

When overlap fails, meaning still carries. The semantic tier embeds the query and
the candidate documents into vectors and re-scores by cosine similarity, then
blends that with the lexical score so strong keyword evidence is not thrown away.

**Why it isn't always on**

| Property | Value |
|---|---|
| Cost / query | small — embed query + cosine over the candidate pool |
| Latency | low; on-device embeddings, **no network** |
| Strength | intent, synonyms, paraphrase, cross-lingual hints |
| Cost driver | the embedding step, paid per query it runs on |

The default embedding model is a deterministic **hashing embedding** (char/word
n-grams → fixed-dimension, L2-normalized vector). It needs no download, runs
offline, and is fully testable — so the demo never blocks on a model artifact. A
learned model (e.g. ONNX MiniLM) can replace it behind the same `EmbeddingModel`
interface when stronger semantics are worth the extra weight.

## The confidence gate — where the money is

Running Tier 2 on every query would erase the cost advantage. Running it on *no*
query leaves quality on the table. The gate spends Tier 2 only where Tier 1 is
unsure:

```
escalate to semantic rerank  ⇔  topScore < T   OR   (top1 - top2) < margin
```

- **Low top score** → nothing matched well lexically; meaning is the only hope.
- **Small top1–top2 margin** → a near-tie the cheap signal can't break;
  reranking is most likely to reorder the right contact to the top.

Both thresholds (`T`, `margin`) are not guessed — they are tuned empirically
against the eval set (see [`EVALUATION.md`](EVALUATION.md)), so the gate's
operating point is a measured decision.

Let `p` be the fraction of queries that escalate. Expected cost per query is:

```
E[cost] = cost_lexical + p · cost_rerank
```

A good gate drives `p` down toward "only the hard queries" while keeping nDCG@5
at or above always-on rerank — the gate should cost you almost nothing in
quality while saving most of the rerank spend.

## When each tier is worth its cost

| Situation | Best tier | Why |
|---|---|---|
| Query shares keywords with the right contact | Lexical only | Tier 1 already wins; rerank wouldn't move it |
| Query expresses intent with no token overlap | Semantic rerank | Lexical can't see the match; meaning can |
| Two candidates nearly tie on lexical score | Hybrid (gated rerank) | Semantic signal breaks the tie correctly |
| Clear no-match (deliberate in the eval set) | Lexical | Cheapest way to correctly return "no strong match" |
| Need best possible quality, latency/$ no object | Cloud LLM (stretch) | Escalation tier behind the same gate, higher threshold |

## The hybrid retriever

`HybridContactRetriever implements ContactRetriever` composes the above:

1. Run Tier 1 (`WeightedContactRetriever`) to get a candidate pool and scores.
2. Apply the confidence gate.
3. If unsure, run Tier 2 over the pool and blend scores; otherwise return Tier 1
   directly.
4. Return `RetrievedContact`s whose `matchReason` notes any semantic
   contribution, so the UI can show *which tier did the work*.

Contact embeddings are cached against the RAG-manifest fingerprint, so the rerank
cost is paid once per contact version, not once per query.

## The result we report

The deliverable is not "semantic search is better." It is a **scorecard** showing
**hybrid nDCG@5 ≥ lexical nDCG@5** on the labeled set — the tiered design buys
back the quality that pure lexical leaves on hard queries, without paying model
cost on the easy ones. How that scorecard is produced and read is documented in
[`EVALUATION.md`](EVALUATION.md).
