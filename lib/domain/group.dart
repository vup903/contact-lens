class ContactGroup {
  const ContactGroup({
    required this.id,
    required this.name,
    this.createdAt,
  });

  final String id;
  final String name;
  final DateTime? createdAt;

  ContactGroup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return ContactGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory ContactGroup.fromJson(Map<String, Object?> json) {
    return ContactGroup(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      createdAt: _parseDate(json['createdAt']),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

