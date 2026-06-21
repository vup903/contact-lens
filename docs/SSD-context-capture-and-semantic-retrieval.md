# SSD — Automated Context Capture & Semantic Retrieval (RAG)

**Project:** contact_lens (Flutter, local-first business-card / contact RAG demo)
**Status:** Design frozen for parallel implementation
**Audience:** the implementation agents (each owns one work package below)
**Date:** 2026-06-21

---

## 1. Purpose & scope

Add two capabilities to Contact Lens without breaking its local-first design:

1. **自動化脈絡紀錄 / Automated context capture.** When a card is exchanged (scan-save or
   manual add), automatically attach **time** and **GPS place** to the contact. Offer a fast
   **note** field (text or voice). Run an **LLM** over the note to produce a short **summary**
   and **structured tags**.

2. **語意檢索 (RAG) / Semantic retrieval.** Replace keyword-only search with natural-language
   questions that mix **time + place + meaning**, e.g.
   *「上個月在舊金山見面、做機器學習那個工程師叫什麼？」*
   ("What's the name of the ML engineer I met last month in San Francisco?")
   The system parses the constraints, filters by encounter metadata, ranks by the existing
   semantic retriever, and returns the matching contact(s) with an explanation.

### 1.1 Non-goals

- No backend, no account system, no cloud sync. Storage stays in `SharedPreferences`.
- No replacement of the existing lexical / semantic / hybrid retrievers — we **extend** them.
- No always-on location tracking. Location is sampled **once**, at capture time, with consent.

---

## 2. Guiding constraints (read before designing anything)

These are inherited from the existing codebase and the interview-demo goal. Every work package
must honor them.

- **C1 — Local-first by default.** The product advertises "No model API is called" (see
  `tool/demo.dart`) and "never invents background beyond saved contact data" (see
  `lib/rag/recommender.dart`). Retrieval stays fully local. The generative LLM is the **only**
  network feature and it is **opt-in, disclosed, and off by default**.
- **C2 — Graceful degradation.** Mirror `RuntimeEmbeddingModel`
  (`lib/rag/semantic/runtime_embedding_model.dart`): if a sensor is denied or the LLM is
  unreachable/unconfigured, swallow the failure and fall back to a deterministic local path.
  Never crash, never block the UI, never invent data.
- **C3 — Pure-Dart demo path.** `dart run tool/demo.dart` must keep working headless with **no
  Flutter plugins and no network**. Therefore the contextual-retrieval logic, the temporal/geo
  parser fallback, and the heuristic note summarizer must be **pure Dart** (no `flutter/`,
  no plugins). Sensors and the Claude HTTP client live in separate files the demo never imports.
- **C4 — Backward-compatible storage.** Existing stored contacts have no encounter data. Decoding
  must default missing fields to empty — same pattern already used in `Contact.fromJson`.
- **C5 — Deterministic & testable.** All time math takes an injectable `now`. Tests are hermetic
  (no network, no real sensors) via fakes. The RAG manifest content-hash must change when
  encounter data changes so the index rebuilds.
- **C6 — Match the house style.** Immutable value objects with `copyWith` / `toJson` / `fromJson`;
  `ChangeNotifier` state passed explicitly to screens; English identifiers and comments.

---

## 3. Current architecture (shared context)

```
lib/
  domain/      Contact, ContactGroup, RagDocument, RagManifest (+ contactContentHash), domain.dart (barrel)
  data/        ContactRepository (iface) + SharedPreferencesContactRepository, ContactDataset,
               sample_data.dart, id_generator.dart (newLocalId), data.dart (barrel)
  rag/         ContactRetriever (iface), RetrievedContact, WeightedContactRetriever (lexical),
               SemanticContactRetriever (cosine), HybridContactRetriever (lexical→gate→semantic),
               contactToRagDocument, LocalContactRecommender, tokenizer, rag.dart (barrel)
    semantic/  EmbeddingModel, RuntimeEmbeddingModel (local Py service via http),
               PrecomputedEmbeddingModel, SemanticReranker, EmbeddingCache, vector_ops
  eval/        eval_runner, metrics, eval_dataset
  scan/        OCR adapters (mobile/stub), business_card_text_parser, ParsedBusinessCard, scan.dart
  ui/          ContactLensState (ChangeNotifier) = app_state.dart; ContactLensApp (4 tabs:
               Contacts, Assistant, Scan, Architecture); screens/*
tool/
  demo.dart    headless pure-Dart CLI; embed/ Python embedding service
```

Key facts implementers rely on:

- `Contact` is immutable; `toIndexJson()` is the canonical projection hashed by
  `contactContentHash()` → drives `RagManifest.needsRebuild`.
- `contactToRagDocument(contact)` currently indexes only `name, company, jobTitle, groups, other`.
  Both the lexical and semantic tiers read from this document. **This is the bridge we extend so
  encounter data becomes searchable with near-zero change to the retrievers.**
- `WeightedContactRetriever.defaultWeights` = `{name:5, company:3, jobTitle:3, groups:2, other:1}`.
- `ContactLensState.recommend()` warms embeddings from
  `contactToRagDocument(contact).fields.values` → new fields are warmed automatically.
- `pubspec.yaml` already depends on `http`. No geo / audio / STT packages yet.

---

## 4. Feature 1 — Automated context capture

### 4.1 Data model: `Encounter`

A contact can be met multiple times, so an encounter is a **list element on `Contact`**, not a
field. New file `lib/domain/encounter.dart`:

```dart
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude, this.accuracyMeters});
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  Map<String, Object?> toJson();
  factory GeoPoint.fromJson(Map<String, Object?> json);
}

enum EncounterSource { scan, manual, imported }

class Encounter {
  const Encounter({
    required this.id,
    required this.occurredAt,          // UTC; when the exchange happened
    this.geo,                          // GeoPoint?  null if unavailable/denied
    this.placeLabel = '',              // human, editable: "San Francisco, CA"
    this.note = '',                    // raw text the user typed
    this.transcript = '',              // STT output (may duplicate note)
    this.audioPath,                    // String?  local file path, mobile only
    this.summary = '',                 // one-line LLM/heuristic summary
    this.tags = const <String>[],      // structured tags, lowercase, deduped
    this.source = EncounterSource.manual,
  });

  final String id;
  final DateTime occurredAt;
  final GeoPoint? geo;
  final String placeLabel;
  final String note;
  final String transcript;
  final String? audioPath;
  final String summary;
  final List<String> tags;
  final EncounterSource source;

  Encounter copyWith({...all fields...});
  Map<String, Object?> toJson();
  factory Encounter.fromJson(Map<String, Object?> json);

  /// Deterministic projection folded into the contact content hash, so changing
  /// any searchable encounter field rebuilds the RAG manifest. Round `occurredAt`
  /// to the day and sort `tags` for stability.
  Map<String, Object?> toIndexJson();
}

/// Pre-persistence capture payload assembled by the UI before LLM enrichment.
class EncounterDraft {
  const EncounterDraft({
    required this.occurredAt,
    this.geo,
    this.placeLabel = '',
    this.note = '',
    this.transcript = '',
    this.audioPath,
    this.source = EncounterSource.manual,
  });
  // same fields as Encounter minus id/summary/tags
}
```

### 4.2 `Contact` extension

In `lib/domain/contact.dart` add:

```dart
final List<Encounter> encounters;   // default const <Encounter>[]
```

- Add to the constructor (defaulted), `copyWith`, `toJson` (`'encounters'`), `fromJson`
  (decode list, default `[]` when missing — **C4**).
- Extend `toIndexJson()` to include a sorted encounter index
  (`encounters.map((e) => e.toIndexJson()).toList()` sorted by `id`) so the content hash and
  `RagManifest.needsRebuild` react to encounter changes (**C5**).
- `lib/domain/domain.dart`: export `encounter.dart`.

### 4.3 RAG bridge (makes encounters searchable)

In `lib/rag/contact_to_text.dart`, add three fields derived from `contact.encounters`:

- `place` → all non-empty `placeLabel`s joined.
- `tags` → all encounter `tags` joined.
- `encounterNotes` → all `summary` (fallback `note`/`transcript`) joined.

All run through `normalizeSearchText`. **Keep the five existing field names unchanged** so the
eval set and semantic warming stay valid. In `lib/rag/retrieve_contacts.dart` extend
`defaultWeights` with `place: 3, tags: 3, encounterNotes: 1`.

### 4.4 Sensors (platform plumbing)

Follow the existing OCR adapter pattern (`ocr_adapter.dart` + `_mobile.dart` + `_stub.dart` with
conditional imports). New `lib/capture/`:

- **Geo** — `geo_location_service.dart` (interface) + mobile + stub. Samples location once,
  best-effort reverse-geocode to `placeLabel`. Permission denied / web-unsupported → returns
  `null` (**C2**). Recommended package: `geolocator` (+ optional `geocoding`).
- **Voice** — `voice_capture_service.dart` (interface) + mobile + stub. Record + on-device
  speech-to-text → transcript (and optional `audioPath`). Recommended packages: `record`,
  `speech_to_text`. Web/unsupported → `ensurePermission()` returns false, UI hides the mic.

Interfaces:

```dart
class GeoReading { const GeoReading({required this.point, this.placeLabel = ''}); ... }
abstract class GeoLocationService {
  Future<bool> ensurePermission();
  Future<GeoReading?> currentLocation();   // null when denied/unavailable
}

class VoiceCaptureResult { const VoiceCaptureResult({required this.transcript, this.audioPath}); ... }
abstract class VoiceCaptureService {
  Future<bool> ensurePermission();
  Future<void> start();
  Future<VoiceCaptureResult> stop();        // returns transcript (+ optional audioPath)
  bool get isRecording;
}
```

Provide `FakeGeoLocationService` / `FakeVoiceCaptureService` for tests and for the web/desktop
build where plugins are absent.

### 4.5 LLM note enrichment

`LlmAdapter.summarizeNote(text)` → `NoteInsight{summary, tags}` (see §6 for the adapter). Called
by `app_state` after the draft is assembled, before persisting the `Encounter`. On failure or
when not configured, the heuristic adapter produces tags via keyword extraction so the field is
never empty (**C2**).

### 4.6 Capture flow (UI)

1. User taps **Save contact** (scan) or **Add** (manual).
2. App requests a one-shot geo reading (non-blocking; proceed without it on denial).
3. A bottom sheet `EncounterCaptureSheet` shows: detected time (editable), place (editable),
   a note field, and a mic button (only if `VoiceCaptureService.ensurePermission()` is true).
4. On confirm → `app_state` builds `EncounterDraft`, calls `llm.summarizeNote`, constructs the
   `Encounter`, attaches it to the contact, persists. Manifest rebuilds via the content hash.
5. Contact detail shows an `EncounterTimeline` (time · place · tags · summary, newest first).

---

## 5. Feature 2 — Semantic retrieval with time + place

### 5.1 Query understanding

`LlmAdapter.parseQuery(nl)` → `ParsedQuery{semanticText, startUtc?, endUtc?, locationText}`.
The UI maps that into a `ContextualQuery`:

```dart
// lib/rag/contextual_query.dart  (pure Dart)
class TimeRange {
  const TimeRange({this.start, this.end});  // UTC, inclusive; null = open bound
  final DateTime? start;
  final DateTime? end;
  bool contains(DateTime t);
  bool get isOpen => start == null && end == null;
}
class GeoFilter {
  const GeoFilter({this.placeText = '', this.center, this.radiusKm});
  final String placeText;            // "san francisco"
  final GeoPoint? center;
  final double? radiusKm;
  bool matchesEncounter(Encounter e);  // placeText substring OR center/radius
}
class ContextualQuery {
  const ContextualQuery({required this.semanticText, this.timeRange, this.geo, this.rawQuery = ''});
  final String semanticText;         // residual meaning, e.g. "machine learning engineer"
  final TimeRange? timeRange;
  final GeoFilter? geo;
  final String rawQuery;
  bool get hasConstraints => timeRange != null || geo != null;
}
```

The heuristic fallback parser (pure Dart, **C3**) must handle at least:
- Relative time in English + Traditional Chinese: "last month/week", 「上個月」「上週」「這個月」「去年」,
  plus explicit ISO dates. Computed against injected `now`.
- Place: known-city list + capitalized tokens + match against existing `placeLabel`s; strips the
  matched span from `semanticText`.

### 5.2 Metadata-filtered retrieval

```dart
// lib/rag/contextual_retriever.dart  (pure Dart)
class ContextualRetrievalResult {
  final List<RetrievedContact> results;
  final bool filterApplied;        // false when we fell back to the full corpus
  final int candidateCount;        // contacts surviving the metadata filter
  final String explanation;        // human, e.g. "Filtered to 2 contacts met last month near
                                   //  San Francisco; ranked by 'machine learning'."
}
class ContextualRetriever {
  ContextualRetriever({required ContactRetriever base});
  ContextualRetrievalResult retrieve(ContextualQuery q, List<Contact> contacts, {int k = 5});
}
```

Algorithm:

1. If `q.hasConstraints`, keep contacts with **≥1 encounter** satisfying every present constraint
   (time via `TimeRange.contains(occurredAt)`, place via `GeoFilter.matchesEncounter`).
2. If the surviving set is non-empty → run `base.retrieve(q.semanticText, survivors, k)`,
   `filterApplied = true`.
3. If the metadata filter is empty (likely a bad parse) → run `base` over the **full** corpus,
   `filterApplied = false`, and say so in `explanation` (**C2** — never return nothing just
   because parsing guessed wrong).
4. If `q.semanticText` is empty (pure time/place question) → rank survivors by encounter recency.
5. Each `RetrievedContact.matchReason` should mention the matched encounter
   (e.g. "met 2026-05-18 in San Francisco; …").

`base` is the existing `HybridContactRetriever` in the live app and `WeightedContactRetriever` in
the headless demo (no embedding service there).

### 5.3 Assistant UI

The Assistant screen sends the raw question through `parseQuery` → `ContextualQuery` →
`ContextualRetriever`, and renders the **parsed filters** as chips
(時間 / 地點 / 語意) above the explainable result list, so the demo visibly shows *why* a contact
was retrieved. Keep the existing hybrid toggle.

---

## 6. LLM integration (the only network feature)

Flutter/Dart has **no official Anthropic SDK**, so use **raw HTTP** via the existing `http`
package (the same approach `RuntimeEmbeddingModel` already uses for the embedding service).

- **Endpoint:** `POST https://api.anthropic.com/v1/messages`
- **Headers:** `x-api-key: <key>`, `anthropic-version: 2023-06-01`, `content-type: application/json`
- **Model:** `claude-opus-4-8`
- **Structured output:** use `output_config: { format: { type: "json_schema", schema: {...} } }`
  so both calls return guaranteed-parseable JSON. Define `additionalProperties: false` + `required`.
  - `summarizeNote` schema → `{ summary: string, tags: string[] }`
  - `parseQuery` schema → `{ semanticText: string, startUtc: string|null, endUtc: string|null, locationText: string }`
- `max_tokens`: ~1024 (small extraction). No `thinking` needed for these single-shot extractions.
- **Failure handling (C2):** any non-200 / timeout / parse error → fall back to the heuristic
  adapter result. Never throw into the UI.

```dart
// lib/llm/llm_adapter.dart  (pure Dart — interface + value types)
class NoteInsight { const NoteInsight({required this.summary, required this.tags});
  final String summary; final List<String> tags; }
class ParsedQuery { const ParsedQuery({required this.semanticText, this.startUtc, this.endUtc, this.locationText = ''});
  final String semanticText; final DateTime? startUtc; final DateTime? endUtc; final String locationText; }
abstract class LlmAdapter {
  Future<NoteInsight> summarizeNote(String text, {DateTime? now});
  Future<ParsedQuery> parseQuery(String naturalLanguageQuery, {DateTime? now});
  bool get isRemote;   // true = Claude, false = heuristic
}
```

Implementations:
- `ClaudeLlmAdapter` (`lib/llm/claude_llm_adapter.dart`) — raw HTTP as above; constructed only
  when a key is present. Inject an `http.Client` for testing.
- `HeuristicLlmAdapter` (`lib/llm/heuristic_llm_adapter.dart`) — pure Dart, deterministic:
  keyword/tag extraction for notes; the temporal/geo parser for queries. **This is the default**
  and the only adapter the headless demo and tests use.
- Selection (`lib/llm/llm_config.dart`): use `ClaudeLlmAdapter` when an API key is configured
  (e.g. from `--dart-define=ANTHROPIC_API_KEY=…` or app settings) **and** the user has enabled
  "cloud enrichment"; otherwise `HeuristicLlmAdapter`. Wrap Claude so any failure falls back to
  heuristic (decorator).

**Privacy (C1):** calling Claude sends note text / query text to Anthropic — an external egress.
Default OFF. Surface a clear toggle + one-line disclosure in the UI. The "No model API is called"
guarantee remains true in the default configuration and in the CLI demo.

---

## 7. Migration & compatibility

- Old stored contacts decode with `encounters: []` (**C4**).
- Bump persistence only if needed; existing keys (`contact_lens.contacts.v1`, `…rag_manifest.v1`)
  stay. The first load after upgrade recomputes hashes; because `toIndexJson` now includes
  encounters, `needsRebuild` triggers exactly once and the manifest is rewritten — no data loss.
- `sample_data.dart` gains encounters, including **one contact who is an ML engineer met "last
  month" in San Francisco**, so the headline demo query returns a correct, non-empty answer.

---

## 8. Work breakdown — 5 agents

Ownership is by **file set** to avoid write conflicts. Contracts in §4–6 are **frozen**; build
against them. Do not edit files outside your package; if you need a new shared type, it belongs to
the package that owns that layer (noted below).

### Agent 1 — Domain & data foundation + RAG bridge  *(no deps; land first)*
**Owns:** `domain/encounter.dart` (new), `domain/contact.dart`, `domain/domain.dart`,
`domain/rag_manifest.dart` (only if hash plumbing needs it — `toIndexJson` change lives in Contact),
`rag/contact_to_text.dart`, `rag/retrieve_contacts.dart` (weights), `data/sample_data.dart`.
**Delivers:** `Encounter`, `GeoPoint`, `EncounterSource`, `EncounterDraft`, Contact w/ encounters
(+ JSON + copyWith + hash), encounter-aware `contactToRagDocument`, new weights, seeded sample
encounters (incl. SF/ML demo contact).
**Tests:** encounter JSON round-trip; backward-compatible decode (no `encounters` key);
`needsRebuild` fires when an encounter changes; lexical retrieval finds a contact by `placeLabel`
and by `tags`.

### Agent 2 — Sensors & platform plumbing  *(no code deps; parallel)*
**Owns:** `lib/capture/geo_location_service.dart` (+ `_mobile.dart`, `_stub.dart`),
`lib/capture/voice_capture_service.dart` (+ `_mobile.dart`, `_stub.dart`), the fakes,
**`pubspec.yaml`** (geo/audio/STT deps — single owner), Android `AndroidManifest.xml` + iOS
`Info.plist` permission strings, web fallbacks.
**Delivers:** the two service interfaces + platform impls + fakes, all denial/web paths returning
null/false per **C2**. No app wiring, no domain edits.
**Tests:** fakes behave; permission-denied → `null` / `false`.

### Agent 3 — LLM adapter (generative)  *(no code deps; parallel)*
**Owns:** `lib/llm/llm_adapter.dart`, `lib/llm/claude_llm_adapter.dart`,
`lib/llm/heuristic_llm_adapter.dart`, `lib/llm/llm_config.dart`.
**Delivers:** `LlmAdapter` + `NoteInsight` + `ParsedQuery`; Claude raw-HTTP impl with
`json_schema` structured output (model `claude-opus-4-8`, injectable `http.Client`); pure-Dart
heuristic impl (tag extraction + EN/zh-TW temporal + place parser keyed on injected `now`); the
fallback decorator + selection.
**Tests:** heuristic tag extraction; "last month"/「上個月」 + "San Francisco"/「舊金山」 parse to
the right `startUtc/endUtc/locationText`; Claude adapter against a mocked `http.Client`; failure
falls back to heuristic.

### Agent 4 — Contextual retrieval + eval  *(deps: A1 Encounter, A3 ParsedQuery; integrate after)*
**Owns:** `lib/rag/contextual_query.dart`, `lib/rag/contextual_retriever.dart`,
`lib/rag/rag.dart` (export the two new files), `eval/eval_dataset.dart` (+ temporal/geo cases).
**Delivers:** `TimeRange`/`GeoFilter`/`ContextualQuery`; `ContextualRetriever` +
`ContextualRetrievalResult` per §5.2 (filter → fall back to full corpus when empty); a small mapper
`ParsedQuery → ContextualQuery`. All pure Dart (**C3**).
**Tests:** time-only / place-only / combined filters; empty-filter fallback path; the headline
SF/ML query returns the seeded contact first; semantic-empty query ranks by recency.

### Agent 5 — UI, integration & CLI demo  *(deps: all; integrate last)*
**Owns:** `ui/app_state.dart`, `ui/contact_lens_app.dart`, `ui/screens/scan_screen.dart`,
`ui/screens/contacts_screen.dart`, `ui/screens/assistant_screen.dart`, new
`ui/widgets/encounter_capture_sheet.dart`, `ui/widgets/encounter_timeline.dart`, `tool/demo.dart`.
**Delivers:** wire `GeoLocationService` + `VoiceCaptureService` + `LlmAdapter` +
`ContextualRetriever` into `ContactLensState`; new methods
`captureEncounter(...)` / `addContactFromParsedCardWithContext(...)` /
`recommendContextual(String)`; capture sheet + timeline; Assistant shows parsed filter chips;
privacy toggle + disclosure (**C1**); extend `tool/demo.dart` to demonstrate both features with the
**heuristic** adapter and a fixed `now` (default still "no model API"), incl. the SF/ML query and a
note-summarization example.
**Tests / verification:** `dart run tool/demo.dart` prints a correct answer to the SF/ML query;
`flutter analyze` clean; existing tests green.

### Dependency graph & sequencing

```
A1 ─┬─────────────► A4 ─► A5
A3 ─┘             ┌───────┘
A2 ───────────────┘
```

- Start **A1, A2, A3 immediately** (independent).
- **A4** builds against the frozen A1+A3 contracts; integrate once A1 lands.
- **A5** integrates everything last.
- Orchestrator (me) freezes contracts, reviews each package, runs `flutter analyze` + tests +
  the CLI demo at integration.

> Collapse option if fewer agents are preferred: merge A3+A4 (LLM+retrieval) and/or fold A5 into the
> orchestrator → 3 building agents. Splitting A2 into geo vs voice → 6. Recommended split is **5**.

---

## 9. Verification plan

- **Unit (hermetic):** per-agent tests above; all sensors/LLM via fakes/mocks.
- **Eval:** `tool/eval.dart` still passes; new temporal/geo cases added by A4.
- **Headless demo (no network, no plugins):** `dart run tool/demo.dart` shows
  (a) note → summary + tags, (b) the SF/ML contextual query returning the seeded contact with a
  parsed-filter explanation.
- **App smoke:** `flutter run` (mobile) — capture sheet records time+GPS+note, timeline renders,
  Assistant answers a NL query and shows filter chips.
- **Static:** `flutter analyze` clean; no new lint regressions.

Run Flutter/Dart with the project SDK (not on PATH):
`& "D:\job hunting\.tools\flutter\bin\dart.bat" run tool/demo.dart`.

## 10. Risks & mitigations

- **Bad query parse → empty results.** Mitigated by the full-corpus fallback (§5.2 step 3).
- **Privacy/egress via LLM.** Off by default, disclosed, heuristic covers the default path (C1).
- **Web/desktop lack sensors/STT.** Stubs return null/false; UI hides unavailable affordances (C2).
- **Index drift.** Encounter fields folded into the content hash so the manifest rebuilds (C5).
- **Demo fragility.** Demo uses heuristic adapter + fixed `now`, so it is deterministic and offline.
