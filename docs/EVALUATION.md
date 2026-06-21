# Evaluation: measuring retrieval quality

The point of this project is judgment you can *check*. This doc explains how
retrieval quality is measured, what the metrics mean, and how to read the
scorecard. It is written against the frozen contracts in
[`SDD_retrieval_v2.md`](SDD_retrieval_v2.md) §3 — the metric definitions here are
the authoritative ones the harness implements.

## Why measure at all

"Hybrid is better than lexical" is an assertion until there is a number behind
it. The eval harness turns the demo from *an app* into *I measured retrieval
quality and the tiered design wins where I claimed it would.* The same harness
scores any `ContactRetriever`, so lexical, semantic, and hybrid are compared on
identical queries and labels.

## Run it

```bash
flutter pub get

# Lexical baseline scorecard
dart run tool/eval.dart

# Hybrid (tiered) scorecard — expected to match or beat the baseline on nDCG@5
dart run tool/eval_hybrid.dart
```

Each command runs the labeled eval set through `runEval(...)`, prints a per-query
breakdown and an aggregate row, and (for `tool/eval.dart`) **exits non-zero if
aggregate nDCG@5 falls below a documented floor** — so the same command works as
a CI gate, not just a demo print.

## The eval set

The labeled dataset lives in `lib/eval/eval_dataset.dart` as a
`List<EvalCase>` over the sample contacts (ids such as `sample-alex-chen`,
`sample-mia-lin`, `sample-jordan-lee`, `sample-wu-kuei-hua`,
`sample-priya-shah`). It is intentionally small and hand-labeled so the tradeoff
is legible; it is not a production benchmark. It includes:

- **≥ 8 queries**, a mix of **English and Chinese**, and
- a deliberate **no-match case**, so the metrics also reward correctly returning
  "no strong match" rather than forcing a wrong contact to the top.

Each case carries graded relevance, not just yes/no:

```dart
class EvalCase {
  final String query;
  final Map<String, double> relevance; // contactId -> graded gain (3, 2, 1; 0 = irrelevant)
}
```

Graded gains (e.g. 3 = ideal, 2 = good, 1 = acceptable) are what let nDCG reward
ranking the *most* relevant contact above a merely *acceptable* one.

## What the metrics mean

Let `rankedIds` be the retriever's output order for a query, and
`relevance[id]` the labeled gain (0 if absent).

### precision@k

> Of the top `k` results, what fraction are relevant at all?

```
precision@k = |{ i < k : relevance[rankedIds[i]] > 0 }| / k
```

Simple and intuitive, but blind to ordering and to *how* relevant — a relevant
contact at rank 1 and at rank 3 count the same. That is why we also report nDCG.

### nDCG@k

> How good is the *ordering*, rewarding highly-relevant hits near the top?

```
gain_i  = relevance[rankedIds[i]] ?? 0
DCG@k   = Σ_{i=0}^{k-1}  gain_i / log2(i + 2)
IDCG@k  = DCG@k of the ideal ordering (gains sorted descending)
nDCG@k  = DCG@k / IDCG@k          (0 when IDCG@k == 0)
```

The `log2(i + 2)` discount means a relevant contact at rank 1 is worth more than
the same contact at rank 5. Normalizing by the *ideal* DCG puts every query on a
0–1 scale, so queries with different numbers of relevant contacts can be averaged
fairly. **nDCG@5 is the headline metric** because it captures exactly what the
tiered design is supposed to improve: getting the right person ranked high on the
hard queries.

`recall@k` (fraction of all relevant contacts retrieved within `k`) is also
available for completeness.

## How to read the scorecard

`runEval` returns an `EvalReport`:

```dart
class EvalReport {
  final Map<int, double> meanPrecisionAtK; // k -> mean precision@k
  final Map<int, double> meanNdcgAtK;      // k -> mean nDCG@k
  // + per-case rows for the printed scorecard
}
```

Read it in three passes:

1. **Aggregate row first.** Compare `meanNdcgAtK[5]` between the lexical and
   hybrid runs. The success criterion is `nDCG@5(hybrid) ≥ nDCG@5(lexical)`. If
   `precision@1` is also up, the right contact is landing at rank 1 more often.
2. **Per-query rows next.** Find the queries where hybrid beats lexical — these
   should be the low-overlap / near-tie cases, i.e. exactly the queries the
   confidence gate escalates. That alignment is the evidence the gate is firing
   for the right reasons, not randomly.
3. **The no-match case.** Confirm it does *not* get a confident wrong answer.
   Good behavior here shows the system knows when to stay quiet.

A useful framing when presenting: lexical sets the floor cheaply, the gate spends
the semantic tier only on the hard rows, and the aggregate nDCG@5 lift is the
quality those hard rows were leaving on the table.

## Tuning the gate from the scorecard

The gate thresholds (`T`, `margin`) are calibrated, not guessed. Sweep them and
watch two numbers move in opposite directions:

- raising the thresholds → more queries escalate → `p` (rerank rate) rises, cost
  rises, nDCG@5 may rise;
- lowering them → fewer escalate → cheaper, but quality risk on hard queries.

Pick the operating point where nDCG@5 is at/above the always-on-rerank number
while `p` stays small. That single chosen point is the cost-aware decision the
whole architecture is built to make — and the scorecard is what justifies it.

See [`RETRIEVAL.md`](RETRIEVAL.md) for the tier design these numbers evaluate.
