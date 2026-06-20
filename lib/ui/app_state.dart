import 'package:flutter/foundation.dart';

import '../data/data.dart';
import '../domain/domain.dart';
import '../rag/rag.dart';
import '../scan/scan.dart';

class ContactLensState extends ChangeNotifier {
  ContactLensState({
    ContactRepository repository = const SharedPreferencesContactRepository(),
  }) : _repository = repository;

  final ContactRepository _repository;
  final _recommender = const LocalContactRecommender();

  var _contacts = <Contact>[];
  var _groups = <ContactGroup>[];
  RagManifest _manifest = RagManifest.build(const <Contact>[]);
  var _isLoading = true;

  List<Contact> get contacts => List.unmodifiable(_contacts);
  List<ContactGroup> get groups => List.unmodifiable(_groups);
  RagManifest get manifest => _manifest;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final dataset = await _repository.load();
    _contacts = dataset.contacts;
    _groups = dataset.groups;
    _manifest = dataset.manifest;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> upsertContact(Contact contact) async {
    final contacts = List<Contact>.from(_contacts);
    final index = contacts.indexWhere((item) => item.id == contact.id);
    final value = contact.copyWith(updatedAt: DateTime.now().toUtc());
    if (index >= 0) {
      contacts[index] = value;
    } else {
      contacts.add(value);
    }
    final dataset = await _repository.saveContacts(contacts);
    _contacts = dataset.contacts;
    _groups = dataset.groups;
    _manifest = dataset.manifest;
    notifyListeners();
  }

  Future<void> deleteContact(String contactId) async {
    final contacts = _contacts.where((item) => item.id != contactId).toList();
    final dataset = await _repository.saveContacts(contacts);
    _contacts = dataset.contacts;
    _groups = dataset.groups;
    _manifest = dataset.manifest;
    notifyListeners();
  }

  Future<void> addContactFromParsedCard(ParsedBusinessCard parsed) async {
    final contact = parsed.toContact(
      id: newLocalId('scan'),
      createdAt: DateTime.now().toUtc(),
    );
    await upsertContact(contact);
  }

  Future<void> resetToSamples() async {
    final dataset = await _repository.resetToSamples();
    _contacts = dataset.contacts;
    _groups = dataset.groups;
    _manifest = dataset.manifest;
    notifyListeners();
  }

  LocalRecommendation recommend(String query) {
    return _recommender.recommend(query, _contacts);
  }
}

