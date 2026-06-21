import '../domain/domain.dart';
import 'contact_retriever.dart';
import 'contact_to_text.dart';
import 'tokenizer.dart';

class RetrievedContact {
  const RetrievedContact({
    required this.contact,
    required this.score,
    required this.matchedFields,
    required this.matchReason,
  });

  final Contact contact;
  final double score;
  final List<String> matchedFields;
  final String matchReason;
}

class WeightedContactRetriever implements ContactRetriever {
  const WeightedContactRetriever({
    this.weights = defaultWeights,
    this.phraseBoost = 10,
  });

  static const defaultWeights = <String, double>{
    'name': 5,
    'company': 3,
    'jobTitle': 3,
    'groups': 2,
    'other': 1,
  };

  final Map<String, double> weights;
  final double phraseBoost;

  @override
  List<RetrievedContact> retrieve(
    String userNeed,
    List<Contact> contacts, {
    int k = 8,
  }) {
    final tokens = tokenizeQuery(userNeed);
    if (tokens.isEmpty) {
      return const <RetrievedContact>[];
    }

    final phrase = normalizeSearchText(userNeed);
    final scored = <RetrievedContact>[];

    for (final contact in contacts) {
      final document = contactToRagDocument(contact);
      var score = 0.0;
      final matchedFields = <String>{};
      final tokenHits = <String, List<String>>{};

      for (final token in tokens) {
        for (final entry in document.fields.entries) {
          final fieldName = entry.key;
          final fieldText = entry.value;
          final occurrences = countOccurrences(fieldText, token);
          if (occurrences == 0) {
            continue;
          }
          score += occurrences * (weights[fieldName] ?? 1);
          matchedFields.add(fieldName);
          tokenHits.putIfAbsent(fieldName, () => <String>[]).add(token);
        }
      }

      if (phrase.length >= 3 && document.text.contains(phrase)) {
        score += phraseBoost;
        matchedFields.add('phrase');
      }

      if (score <= 0) {
        continue;
      }

      scored.add(
        RetrievedContact(
          contact: contact,
          score: score,
          matchedFields: matchedFields.toList()..sort(),
          matchReason: _buildReason(contact, tokenHits, phrase, document.text),
        ),
      );
    }

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.contact.displayName.compareTo(b.contact.displayName);
    });
    return scored.take(k).toList(growable: false);
  }

  String _buildReason(
    Contact contact,
    Map<String, List<String>> tokenHits,
    String phrase,
    String documentText,
  ) {
    final labels = <String, String>{
      'name': 'name',
      'company': 'company',
      'jobTitle': 'job title',
      'groups': 'groups',
      'other': 'notes',
    };

    final parts = <String>[];
    for (final entry in tokenHits.entries) {
      final uniqueTokens = entry.value.toSet().take(4).join(', ');
      final label = labels[entry.key] ?? entry.key;
      parts.add('$label matched "$uniqueTokens"');
    }
    if (phrase.length >= 3 && documentText.contains(phrase)) {
      parts.add('the full phrase appears in this contact record');
    }
    if (parts.isEmpty) {
      return '${contact.displayName} matched the local contact index.';
    }
    return '${contact.displayName}: ${parts.join('; ')}.';
  }
}

