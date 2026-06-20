class RagDocument {
  const RagDocument({
    required this.contactId,
    required this.title,
    required this.fields,
    required this.text,
  });

  final String contactId;
  final String title;
  final Map<String, String> fields;
  final String text;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'contactId': contactId,
      'title': title,
      'fields': fields,
      'text': text,
    };
  }
}

