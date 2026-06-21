import '../domain/domain.dart';
import 'contact_retriever.dart';
import 'contextual_query.dart';
import 'retrieve_contacts.dart';

/// Outcome of a contextual retrieval: the ranked contacts plus enough metadata
/// for the UI to explain *why* the set was chosen.
class ContextualRetrievalResult {
  const ContextualRetrievalResult({
    required this.results,
    required this.filterApplied,
    required this.candidateCount,
    required this.explanation,
  });

  /// Ranked contacts, best first.
  final List<RetrievedContact> results;

  /// Whether the metadata filter actually narrowed the corpus. `false` means we
  /// searched everything — either because the query had no constraints, or
  /// because the constraints matched nobody and we fell back (C2).
  final bool filterApplied;

  /// How many contacts survived the metadata filter. Equals the corpus size
  /// when no filter was applied.
  final int candidateCount;

  /// Human-readable account of the filtering + ranking, shown in the demo/UI.
  final String explanation;

  /// Empty result for an empty corpus / unanswerable query.
  const ContextualRetrievalResult.empty()
      : results = const <RetrievedContact>[],
        filterApplied = false,
        candidateCount = 0,
        explanation = 'No contacts to search.';
}

/// Wraps any [ContactRetriever] with time + place metadata filtering over
/// [Encounter]s. The wrapped [base] does the actual relevance ranking
/// (lexical in the headless demo, hybrid in the live app); this class only
/// decides *which* contacts that ranker sees and explains the choice.
///
/// Pure Dart, no IO — safe for the offline demo and hermetic tests (C3/C5).
class ContextualRetriever {
  ContextualRetriever({required this.base});

  /// The relevance ranker applied to the surviving candidates.
  final ContactRetriever base;

  /// Retrieves up to [k] contacts for [q] over [contacts].
  ///
  /// 1. With constraints, keep contacts having ≥1 encounter that satisfies
  ///    *every* present constraint.
  /// 2. Non-empty survivors → rank them with [base] (or by recency when the
  ///    query carries no residual meaning).
  /// 3. Empty survivors (likely a bad parse) → search the full corpus and say
  ///    so, rather than returning nothing (C2).
  /// 4. No constraints → plain [base] ranking over the full corpus.
  ContextualRetrievalResult retrieve(
    ContextualQuery q,
    List<Contact> contacts, {
    int k = 5,
  }) {
    if (contacts.isEmpty) {
      return const ContextualRetrievalResult.empty();
    }

    final hasMeaning = q.semanticText.trim().isNotEmpty;
    final constraintText = _describeConstraints(q);

    // No metadata constraints: behave like the plain base retriever.
    if (!q.hasConstraints) {
      final ranked = hasMeaning
          ? _annotate(base.retrieve(q.semanticText, contacts, k: k), q)
          : _rankByRecency(contacts, q, k);
      final ranker = hasMeaning ? "meaning '${q.semanticText.trim()}'" : 'recency';
      return ContextualRetrievalResult(
        results: ranked,
        filterApplied: false,
        candidateCount: contacts.length,
        explanation:
            'No time or place constraints; ranked all ${contacts.length} '
            'contacts by $ranker.',
      );
    }

    // Constraint path: keep contacts with a satisfying encounter.
    final survivors = <Contact>[];
    for (final contact in contacts) {
      if (_matchingEncounters(contact, q).isNotEmpty) {
        survivors.add(contact);
      }
    }

    // Bad parse / nobody matched: fall back to the full corpus (C2).
    if (survivors.isEmpty) {
      final ranked = hasMeaning
          ? _annotate(base.retrieve(q.semanticText, contacts, k: k), q)
          : _rankByRecency(contacts, q, k);
      return ContextualRetrievalResult(
        results: ranked,
        filterApplied: false,
        candidateCount: contacts.length,
        explanation:
            'No contacts matched $constraintText, so searched all '
            '${contacts.length} contacts instead.',
      );
    }

    // Pure time/place question (no residual meaning): rank by encounter recency.
    if (!hasMeaning) {
      return ContextualRetrievalResult(
        results: _rankByRecency(survivors, q, k),
        filterApplied: true,
        candidateCount: survivors.length,
        explanation:
            'Filtered to ${survivors.length} contact(s) $constraintText; '
            'ranked by most recent encounter.',
      );
    }

    // Rank survivors by meaning. If the ranker scores none of them (no lexical
    // overlap — common for a cross-language query against a lexical-only base),
    // fall back to recency so the filter is still honored, and say so honestly
    // rather than claiming a meaning ranking that did not happen.
    final byMeaning = _annotate(base.retrieve(q.semanticText, survivors, k: k), q);
    final rankedByMeaning = byMeaning.isNotEmpty;
    final ranked = rankedByMeaning ? byMeaning : _rankByRecency(survivors, q, k);
    return ContextualRetrievalResult(
      results: ranked,
      filterApplied: true,
      candidateCount: survivors.length,
      explanation: rankedByMeaning
          ? 'Filtered to ${survivors.length} contact(s) $constraintText; '
              "ranked by meaning '${q.semanticText.trim()}'."
          : 'Filtered to ${survivors.length} contact(s) $constraintText; '
              "no contact text matched '${q.semanticText.trim()}', so ranked by "
              'most recent encounter.',
    );
  }

  // --- Encounter matching --------------------------------------------------

  /// Encounters on [contact] that satisfy every present constraint in [q].
  List<Encounter> _matchingEncounters(Contact contact, ContextualQuery q) {
    return contact.encounters.where((e) {
      if (q.timeRange != null &&
          !q.timeRange!.isOpen &&
          !q.timeRange!.contains(e.occurredAt)) {
        return false;
      }
      if (q.geo != null && !q.geo!.isEmpty && !q.geo!.matchesEncounter(e)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  /// The most recent encounter on [contact] satisfying the constraints, or the
  /// most recent encounter overall when the query is unconstrained.
  Encounter? _bestEncounter(Contact contact, ContextualQuery q) {
    final candidates =
        q.hasConstraints ? _matchingEncounters(contact, q) : contact.encounters;
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.reduce(
      (a, b) => a.occurredAt.isAfter(b.occurredAt) ? a : b,
    );
  }

  // --- Ranking helpers -----------------------------------------------------

  /// Re-emits [base] results with the matched encounter prepended to the
  /// match reason (SSD §5.2 step 5), so the UI can show "met … in …; why".
  List<RetrievedContact> _annotate(
    List<RetrievedContact> ranked,
    ContextualQuery q,
  ) {
    return ranked.map((r) {
      final encounter = _bestEncounter(r.contact, q);
      if (encounter == null) {
        return r;
      }
      return RetrievedContact(
        contact: r.contact,
        score: r.score,
        matchedFields: r.matchedFields,
        matchReason: '${_encounterPrefix(encounter)}; ${r.matchReason}',
      );
    }).toList(growable: false);
  }

  /// Ranks [contacts] by their best matching encounter's recency (newest
  /// first); contacts without a matching encounter sort last by name.
  List<RetrievedContact> _rankByRecency(
    List<Contact> contacts,
    ContextualQuery q,
    int k,
  ) {
    final scored = <({Contact contact, Encounter? encounter})>[
      for (final c in contacts) (contact: c, encounter: _bestEncounter(c, q)),
    ];
    scored.sort((a, b) {
      final at = a.encounter?.occurredAt;
      final bt = b.encounter?.occurredAt;
      if (at == null && bt == null) {
        return a.contact.displayName.compareTo(b.contact.displayName);
      }
      if (at == null) return 1;
      if (bt == null) return -1;
      final cmp = bt.compareTo(at);
      if (cmp != 0) return cmp;
      return a.contact.displayName.compareTo(b.contact.displayName);
    });

    final results = <RetrievedContact>[];
    for (final entry in scored.take(k)) {
      final encounter = entry.encounter;
      final reason = encounter == null
          ? '${entry.contact.displayName} matched the requested context.'
          : '${_encounterPrefix(encounter)}; ranked by encounter recency.';
      results.add(
        RetrievedContact(
          contact: entry.contact,
          // Monotonic, deterministic recency score in [0, 1].
          score: encounter == null
              ? 0
              : encounter.occurredAt.toUtc().millisecondsSinceEpoch / 1e15,
          matchedFields: encounter == null
              ? const <String>[]
              : const <String>['encounter'],
          matchReason: reason,
        ),
      );
    }
    return results;
  }

  // --- Explanation formatting ----------------------------------------------

  String _encounterPrefix(Encounter e) {
    final place = e.placeLabel.trim();
    final date = _formatDate(e.occurredAt);
    return place.isEmpty ? 'met $date' : 'met $date in $place';
  }

  String _describeConstraints(ContextualQuery q) {
    final parts = <String>[];
    final time = q.timeRange;
    if (time != null && !time.isOpen) {
      if (time.start != null && time.end != null) {
        parts.add('between ${_formatDate(time.start!)} and '
            '${_formatDate(time.end!)}');
      } else if (time.start != null) {
        parts.add('on or after ${_formatDate(time.start!)}');
      } else {
        parts.add('on or before ${_formatDate(time.end!)}');
      }
    }
    final geo = q.geo;
    if (geo != null && !geo.isEmpty && geo.placeText.trim().isNotEmpty) {
      parts.add('near ${geo.placeText.trim()}');
    } else if (geo != null && !geo.isEmpty) {
      parts.add('near the requested location');
    }
    if (parts.isEmpty) {
      return 'the requested context';
    }
    return parts.join(' ');
  }

  static String _formatDate(DateTime t) {
    final u = t.toUtc();
    final mm = u.month.toString().padLeft(2, '0');
    final dd = u.day.toString().padLeft(2, '0');
    return '${u.year}-$mm-$dd';
  }
}
