import '../domain/domain.dart';
import 'tokenizer.dart';

RagDocument contactToRagDocument(Contact contact) {
  final fields = <String, String>{
    'name': normalizeSearchText(contact.name),
    'company': normalizeSearchText(contact.company),
    'jobTitle': normalizeSearchText(contact.jobTitle),
    'groups': normalizeSearchText(contact.groups.join(' ')),
    'other': normalizeSearchText(contact.other),
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

