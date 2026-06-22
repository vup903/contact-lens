import '../domain/domain.dart';
import 'tokenizer.dart';

RagDocument contactToRagDocument(Contact contact) {
  final encounters = contact.encounters;

  final place = encounters
      .map((e) => e.placeLabel)
      .where((label) => label.trim().isNotEmpty)
      .join(' ');
  final tags = encounters.expand((e) => e.tags).join(' ');
  final encounterNotes = encounters
      .map((e) => e.displayNote)
      .where((note) => note.trim().isNotEmpty)
      .join(' ');

  // The five existing field names are kept unchanged so the eval set and
  // semantic warming stay valid; encounter context is added as new fields.
  final fields = <String, String>{
    'name': normalizeSearchText(contact.name),
    'company': normalizeSearchText(contact.company),
    'jobTitle': normalizeSearchText(contact.jobTitle),
    'groups': normalizeSearchText(contact.groups.join(' ')),
    'other': normalizeSearchText(contact.other),
    'place': normalizeSearchText(place),
    'tags': normalizeSearchText(tags),
    'encounterNotes': normalizeSearchText(encounterNotes),
  };

  final text = fields.entries
      .where((entry) => entry.value.isNotEmpty)
      .map((entry) => '${entry.key}:${entry.value}')
      .join('\n');

  return RagDocument(
    contactId: contact.id,
    title: contact.displayName,
    fields: fields,
    text: text,
  );
}

