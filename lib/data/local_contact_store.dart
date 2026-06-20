import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/domain.dart';
import 'contact_repository.dart';
import 'sample_data.dart';

class SharedPreferencesContactRepository implements ContactRepository {
  const SharedPreferencesContactRepository();

  static const _contactsKey = 'contact_lens.contacts.v1';
  static const _groupsKey = 'contact_lens.groups.v1';
  static const _manifestKey = 'contact_lens.rag_manifest.v1';
  static const _seededKey = 'contact_lens.seeded.v1';

  @override
  Future<ContactDataset> load() async {
    final prefs = await SharedPreferences.getInstance();
    final seeded = prefs.getBool(_seededKey) ?? false;
    if (!seeded) {
      return resetToSamples();
    }

    final contacts = _decodeList(
      prefs.getString(_contactsKey),
      Contact.fromJson,
    );
    final groups = _decodeList(
      prefs.getString(_groupsKey),
      ContactGroup.fromJson,
    );
    final manifest = _decodeManifest(prefs.getString(_manifestKey), contacts);

    if (manifest.needsRebuild(contacts)) {
      final rebuilt = RagManifest.build(contacts);
      await prefs.setString(_manifestKey, jsonEncode(rebuilt.toJson()));
      return ContactDataset(contacts: contacts, groups: groups, manifest: rebuilt);
    }

    return ContactDataset(contacts: contacts, groups: groups, manifest: manifest);
  }

  @override
  Future<ContactDataset> saveContacts(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final manifest = RagManifest.build(contacts);
    await prefs.setString(
      _contactsKey,
      jsonEncode(contacts.map((contact) => contact.toJson()).toList()),
    );
    await prefs.setString(_manifestKey, jsonEncode(manifest.toJson()));
    await prefs.setBool(_seededKey, true);
    final groups = _decodeList(prefs.getString(_groupsKey), ContactGroup.fromJson);
    return ContactDataset(contacts: contacts, groups: groups, manifest: manifest);
  }

  @override
  Future<ContactDataset> saveGroups(List<ContactGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _groupsKey,
      jsonEncode(groups.map((group) => group.toJson()).toList()),
    );
    await prefs.setBool(_seededKey, true);
    final contacts = _decodeList(prefs.getString(_contactsKey), Contact.fromJson);
    final manifest = _decodeManifest(prefs.getString(_manifestKey), contacts);
    return ContactDataset(contacts: contacts, groups: groups, manifest: manifest);
  }

  @override
  Future<ContactDataset> resetToSamples() async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = List<Contact>.from(sampleContacts);
    final groups = List<ContactGroup>.from(sampleGroups);
    final manifest = RagManifest.build(contacts);

    await prefs.setString(
      _contactsKey,
      jsonEncode(contacts.map((contact) => contact.toJson()).toList()),
    );
    await prefs.setString(
      _groupsKey,
      jsonEncode(groups.map((group) => group.toJson()).toList()),
    );
    await prefs.setString(_manifestKey, jsonEncode(manifest.toJson()));
    await prefs.setBool(_seededKey, true);

    return ContactDataset(contacts: contacts, groups: groups, manifest: manifest);
  }
}

List<T> _decodeList<T>(
  String? raw,
  T Function(Map<String, Object?> json) decode,
) {
  if (raw == null || raw.trim().isEmpty) {
    return <T>[];
  }
  try {
    final parsed = jsonDecode(raw);
    if (parsed is! List) {
      return <T>[];
    }
    return parsed
        .whereType<Map>()
        .map((item) => decode(item.cast<String, Object?>()))
        .toList(growable: false);
  } catch (_) {
    return <T>[];
  }
}

RagManifest _decodeManifest(String? raw, List<Contact> contacts) {
  if (raw == null || raw.trim().isEmpty) {
    return RagManifest.build(contacts);
  }
  try {
    final parsed = jsonDecode(raw);
    if (parsed is! Map) {
      return RagManifest.build(contacts);
    }
    return RagManifest.fromJson(parsed.cast<String, Object?>());
  } catch (_) {
    return RagManifest.build(contacts);
  }
}

