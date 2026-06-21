# Demo script — 60-second interview walkthrough

Audience: an AI/ML R&D interviewer. Goal: in one minute, land the message
**"I treat retrieval as a measured cost/quality tradeoff,"** not "I made a search
box." Lead with the measurement, show the tier in action, close with the cost
story.

Total budget ≈ 60 seconds. Each beat below has a *say* line and a *do* line.

---

## Beat 0 — One-sentence frame (5s)

> **Say:** "Contact Lens is a contact retriever built as a tiered, cost-aware
> pipeline — a cheap lexical tier handles easy queries, and a semantic tier fires
> only when the cheap one is unsure. And I can show you the numbers that justify
> it."

*Do:* have the terminal and the app open side by side.

## Beat 1 — Lead with measurement (15s)

> **Say:** "First, I measure. This runs a labeled eval set through the lexical
> baseline and prints precision@k and nDCG@5."

*Do:*

```bash
dart run tool/eval.dart
```

> **Say:** "That's the floor — cheap, deterministic, and scored, not asserted.
> Now the hybrid."

```bash
dart run tool/eval_hybrid.dart
```

> **Say:** "Same queries, same labels — **hybrid nDCG@5 is at or above lexical.**
> The lift comes entirely from the hard queries."

*Point at:* the aggregate nDCG@5 row on both scorecards.

## Beat 2 — Show the tier in the UI (20s)

> **Say:** "Here's why. A keyword query the lexical tier already nails —"

*Do:* in the app, run a high-overlap query (e.g. *"Need a Taiwan finance
contact"*). Point out it answered instantly with matched fields and reasons.

> **Say:** "— Tier 1 only, sub-millisecond, no model. Now an intent query with no
> keyword overlap."

*Do:* run *"someone who can help raise a seed round"* (intent, not keywords).
Toggle hybrid on; show the result surfaces the right contact and the UI marks
that **semantic rerank fired**.

> **Say:** "The confidence gate saw a weak top score, escalated *that* query to
> the on-device semantic tier, and reranked the right person to the top."

## Beat 3 — Close with the cost story (15s)

> **Say:** "So the cost model is `cost_lexical + p · cost_rerank`, where `p` is
> the small fraction of queries the gate escalates. Most queries pay near-zero;
> only the hard ones pay for semantics; everything runs on-device so there's no
> per-call API bill — and the same gate would put a cloud LLM behind a higher
> threshold if quality ever justified the spend."

> **Say (kicker):** "That's the difference between *skipping ML to be cheap* and
> *spending ML where the eval shows it changes the answer.*"

---

## If they ask a follow-up

- **"How do you know the gate fires on the right queries?"** → Per-query
  scorecard rows: the queries where hybrid beats lexical are the low-overlap /
  near-tie ones the gate escalates. See [`EVALUATION.md`](EVALUATION.md).
- **"What's the embedding model?"** → Default is a dependency-free on-device
  hashing embedding so the demo never needs a download; swappable for ONNX MiniLM
  behind the same `EmbeddingModel` interface. See [`RETRIEVAL.md`](RETRIEVAL.md).
- **"Is this private?"** → Yes, fully on-device — but that's a *consequence* of
  the cost design, not the headline.
- **"Would this scale?"** → Tier 2 reranks a candidate pool, not the corpus, and
  contact embeddings are cached against the manifest fingerprint, so rerank cost
  grows with `k`, not with the number of contacts.

## Pre-flight checklist

- [ ] `flutter pub get` already run (no first-run delay on stage).
- [ ] Both `dart run tool/eval.dart` and `dart run tool/eval_hybrid.dart` print
      cleanly and hybrid nDCG@5 ≥ lexical.
- [ ] App seeded with the sample contacts; hybrid toggle visible.
- [ ] The two demo queries (one keyword, one intent) chosen and rehearsed.
