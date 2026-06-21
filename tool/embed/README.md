# Embedding tooling

Real multilingual semantic vectors for Contact Lens, produced by
`sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` run through ONNX
Runtime via [`fastembed`](https://github.com/qdrant/fastembed) (no torch).

Two paths share one model and vector space:

- **Offline / baked** — precompute vectors for the fixed eval + demo string set
  and bake them into a generated Dart map. Zero runtime inference; works in the
  Flutter Web build and `dart run` with no service.
- **Runtime / service** — a tiny local HTTP service embeds *arbitrary* typed
  queries on demand, so the live UI is not limited to the curated set.

## Setup (once)

```bash
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt   # Windows
# .venv/bin/python -m pip install -r requirements.txt      # macOS/Linux
```

## Scripts

| Script | What it does |
|---|---|
| `dump_texts.dart` | Writes `texts.json` — the exact strings Dart will embed (contact docs + eval/demo queries), tagged `passage`/`query`. Run with `dart run tool/embed/dump_texts.dart`. |
| `build_embeddings.py` | Reads `texts.json`, embeds them, writes `lib/rag/semantic/precomputed_embeddings.g.dart` (the baked const map). |
| `serve_embeddings.py` | Local CORS-enabled HTTP service (`127.0.0.1:8077`) exposing `POST /embed` for runtime query embedding. Optional; the app degrades gracefully without it. |

## Rebuild the baked vectors

After changing the sample contacts or the eval/demo queries:

```bash
dart run tool/embed/dump_texts.dart
.venv/Scripts/python build_embeddings.py
```

`texts.json` and `.venv/` are git-ignored; the generated `*.g.dart` is committed.
