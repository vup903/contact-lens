import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'contact.dart';

class RagPipelineFingerprint {
  const RagPipelineFingerprint({
    this.cleaningVersion = 'contact-cleaning-2026-06-19a',
    this.tokenizerVersion = 'contact-tokenizer-2026-06-19a',
    this.weightsVersion = 'contact-weights-2026-06-19a',
    this.projectionVersion = 'privacy-projection-2026-06-19a',
  });

  final String cleaningVersion;
  final String tokenizerVersion;
  final String weightsVersion;
  final String projectionVersion;

  Map<String, String> toJson() {
    return <String, String>{
      'cleaningVersion': cleaningVersion,
      'tokenizerVersion': tokenizerVersion,
      'weightsVersion': weightsVersion,
      'projectionVersion': projectionVersion,
    };
  }

  factory RagPipelineFingerprint.fromJson(Map<String, Object?> json) {
    return RagPipelineFingerprint(
      cleaningVersion: (json['cleaningVersion'] as String?) ?? 'unknown',
      tokenizerVersion: (json['tokenizerVersion'] as String?) ?? 'unknown',
      weightsVersion: (json['weightsVersion'] as String?) ?? 'unknown',
      projectionVersion: (json['projectionVersion'] as String?) ?? 'unknown',
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RagPipelineFingerprint &&
        other.cleaningVersion == cleaningVersion &&
        other.tokenizerVersion == tokenizerVersion &&
        other.weightsVersion == weightsVersion &&
        other.projectionVersion == projectionVersion;
  }

  @override
  int get hashCode => Object.hash(
        cleaningVersion,
        tokenizerVersion,
        weightsVersion,
        projectionVersion,
      );
}

class IndexedContactManifest {
  const IndexedContactManifest({
    required this.contactId,
    required this.contentHash,
  });

  final String contactId;
  final String contentHash;

  Map<String, String> toJson() {
    return <String, String>{
      'contactId': contactId,
      'contentHash': contentHash,
    };
  }

  factory IndexedContactManifest.fromJson(Map<String, Object?> json) {
    return IndexedContactManifest(
      contactId: (json['contactId'] as String?) ?? '',
      contentHash: (json['contentHash'] as String?) ?? '',
    );
  }
}

class RagManifest {
  const RagManifest({
    required this.generatedAt,
    required this.pipelineFingerprint,
    required this.contacts,
  });

  final DateTime generatedAt;
  final RagPipelineFingerprint pipelineFingerprint;
  final List<IndexedContactManifest> contacts;

  bool needsRebuild(
    List<Contact> currentContacts, {
    RagPipelineFingerprint fingerprint = const RagPipelineFingerprint(),
  }) {
    if (pipelineFingerprint != fingerprint) {
      return true;
    }

    final current = RagManifest.build(
      currentContacts,
      generatedAt: generatedAt,
      fingerprint: fingerprint,
    );
    if (current.contacts.length != contacts.length) {
      return true;
    }

    for (var i = 0; i < contacts.length; i += 1) {
      final before = contacts[i];
      final after = current.contacts[i];
      if (before.contactId != after.contactId || before.contentHash != after.contentHash) {
        return true;
      }
    }
    return false;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'generatedAt': generatedAt.toIso8601String(),
      'pipelineFingerprint': pipelineFingerprint.toJson(),
      'contacts': contacts.map((contact) => contact.toJson()).toList(),
    };
  }

  factory RagManifest.fromJson(Map<String, Object?> json) {
    return RagManifest(
      generatedAt: DateTime.tryParse((json['generatedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      pipelineFingerprint: RagPipelineFingerprint.fromJson(
        ((json['pipelineFingerprint'] as Map?) ?? const <String, Object?>{})
            .cast<String, Object?>(),
      ),
      contacts: ((json['contacts'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => IndexedContactManifest.fromJson(item.cast<String, Object?>()))
          .toList(growable: false),
    );
  }

  factory RagManifest.build(
    List<Contact> contacts, {
    DateTime? generatedAt,
    RagPipelineFingerprint fingerprint = const RagPipelineFingerprint(),
  }) {
    final indexed = contacts
        .map(
          (contact) => IndexedContactManifest(
            contactId: contact.id,
            contentHash: contactContentHash(contact),
          ),
        )
        .toList()
      ..sort((a, b) => a.contactId.compareTo(b.contactId));

    return RagManifest(
      generatedAt: generatedAt ?? DateTime.now().toUtc(),
      pipelineFingerprint: fingerprint,
      contacts: indexed,
    );
  }
}

String contactContentHash(Contact contact) {
  final canonical = contact.toIndexJson();
  return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
}

