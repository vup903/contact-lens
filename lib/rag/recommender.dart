import '../domain/domain.dart';
import 'retrieve_contacts.dart';

class LocalRecommendation {
  const LocalRecommendation({
    required this.analysis,
    required this.recommendations,
    required this.suggestions,
  });

  final String analysis;
  final List<ContactRecommendation> recommendations;
  final String suggestions;
}

class ContactRecommendation {
  const ContactRecommendation({
    required this.contact,
    required this.reason,
    required this.score,
    required this.matchedFields,
  });

  final Contact contact;
  final String reason;
  final double score;
  final List<String> matchedFields;
}

class LocalContactRecommender {
  const LocalContactRecommender({
    this.retriever = const WeightedContactRetriever(),
  });

  final WeightedContactRetriever retriever;

  LocalRecommendation recommend(
    String userNeed,
    List<Contact> contacts, {
    int k = 5,
  }) {
    final query = userNeed.trim();
    if (query.isEmpty) {
      return const LocalRecommendation(
        analysis: 'Enter a business need to search your local contact index.',
        recommendations: <ContactRecommendation>[],
        suggestions: 'Try a company, job title, market, group, or note keyword.',
      );
    }

    final retrieved = retriever.retrieve(query, contacts, k: k);
    if (retrieved.isEmpty) {
      return LocalRecommendation(
        analysis: 'No local contact has enough matching evidence for "$query".',
        recommendations: const <ContactRecommendation>[],
        suggestions:
            'Add more structured notes, groups, industries, or job titles to improve local RAG recall.',
      );
    }

    final topFields = retrieved
        .expand((item) => item.matchedFields)
        .where((field) => field != 'phrase')
        .toSet()
        .toList()
      ..sort();

    return LocalRecommendation(
      analysis:
          'Found ${retrieved.length} candidate(s) using local weighted retrieval. Strongest evidence came from ${topFields.isEmpty ? 'phrase matches' : topFields.join(', ')}.',
      recommendations: retrieved
          .map(
            (item) => ContactRecommendation(
              contact: item.contact,
              reason: item.matchReason,
              score: item.score,
              matchedFields: item.matchedFields,
            ),
          )
          .toList(growable: false),
      suggestions:
          'Review the matched fields before reaching out. This assistant never invents background beyond saved contact data.',
    );
  }
}

