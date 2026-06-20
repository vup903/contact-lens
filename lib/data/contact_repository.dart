import '../domain/domain.dart';

class ContactDataset {
  const ContactDataset({
    required this.contacts,
    required this.groups,
    required this.manifest,
  });

  final List<Contact> contacts;
  final List<ContactGroup> groups;
  final RagManifest manifest;

  ContactDataset copyWith({
    List<Contact>? contacts,
    List<ContactGroup>? groups,
    RagManifest? manifest,
  }) {
    return ContactDataset(
      contacts: contacts ?? this.contacts,
      groups: groups ?? this.groups,
      manifest: manifest ?? this.manifest,
    );
  }
}

abstract class ContactRepository {
  Future<ContactDataset> load();

  Future<ContactDataset> saveContacts(List<Contact> contacts);

  Future<ContactDataset> saveGroups(List<ContactGroup> groups);

  Future<ContactDataset> resetToSamples();
}

