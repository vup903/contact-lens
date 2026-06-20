# Architecture

Contact Lens is organized by responsibility rather than by screen first.

## Layers

- `lib/domain`: immutable-ish data models for contacts, groups, RAG documents,
  and manifests.
- `lib/data`: sample data, local storage, ID generation, and repository
  contracts.
- `lib/rag`: tokenizer, document projection, weighted retrieval, and
  deterministic recommendation.
- `lib/scan`: OCR adapter boundary and business card parser.
- `lib/ui`: app state and Flutter screens.
- `test`: unit tests for parser, RAG, manifest, and storage.

## Data Flow

1. A user manually adds a contact or parses OCR text.
2. The contact is saved in local storage.
3. The manifest records content hashes and pipeline fingerprint.
4. Assistant queries are tokenized locally.
5. Contacts are ranked with weighted lexical retrieval.
6. The UI renders matched fields, score, and deterministic reasons.

## Platform Notes

- Mobile is the primary app target.
- Flutter Web is a demo target for recruiters and reviewers.
- Web does not bundle production OCR in v1.
- No paid AI/model API is required on any platform.

