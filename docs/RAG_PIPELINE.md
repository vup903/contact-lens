# Local RAG Pipeline

Contact Lens uses local lexical RAG over contact records.

## Projection

The searchable document is intentionally privacy-minimal:

- name
- company
- job title
- groups
- notes

Phone numbers, email, addresses, and social handles are stored on the contact
but are not needed for recommendation scoring.

## Tokenization

The tokenizer:

- lowercases Latin text
- collapses whitespace
- extracts Latin and numeric tokens
- extracts CJK single-character tokens
- adds CJK bigrams and full CJK runs

This supports queries such as `AI fundraising 台灣人脈`.

## Scoring

Field weights:

- name: 5
- company: 3
- jobTitle: 3
- groups: 2
- other: 1

If the normalized phrase appears in the full contact search document, the
retriever adds a phrase boost.

## Recommendation

The recommender is deterministic. It only explains matched fields and scores.
It does not generate biographical claims or external context.

## Manifest

The manifest tracks:

- pipeline fingerprint
- generated timestamp
- contact ID
- contact content hash

A rebuild is needed when the fingerprint changes or any contact hash changes.

