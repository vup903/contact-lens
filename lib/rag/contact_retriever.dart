import '../domain/domain.dart';
import 'retrieve_contacts.dart';

/// Common contract for any contact retrieval strategy: lexical, semantic, or
/// hybrid. The evaluation harness and the UI depend only on this interface, so
/// strategies can be swapped or compared head-to-head without touching callers.
abstract class ContactRetriever {
  List<RetrievedContact> retrieve(
    String userNeed,
    List<Contact> contacts, {
    int k,
  });
}
