import 'encounter.dart';

class Contact {
  const Contact({
    required this.id,
    required this.createdAt,
    required this.name,
    this.updatedAt,
    this.company = '',
    this.jobTitle = '',
    this.phone = '',
    this.mobilePhone = '',
    this.email = '',
    this.website = '',
    this.address = '',
    this.socialMedia = '',
    this.other = '',
    this.groups = const <String>[],
    this.images = const <ContactImage>[],
    this.encounters = const <Encounter>[],
  });

  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String name;
  final String company;
  final String jobTitle;
  final String phone;
  final String mobilePhone;
  final String email;
  final String website;
  final String address;
  final String socialMedia;
  final String other;
  final List<String> groups;
  final List<ContactImage> images;
  final List<Encounter> encounters;

  String get displayName => name.trim().isEmpty ? 'Unnamed contact' : name.trim();

  String get subtitle {
    final parts = <String>[
      if (company.trim().isNotEmpty) company.trim(),
      if (jobTitle.trim().isNotEmpty) jobTitle.trim(),
    ];
    return parts.join(' | ');
  }

  Contact copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    String? company,
    String? jobTitle,
    String? phone,
    String? mobilePhone,
    String? email,
    String? website,
    String? address,
    String? socialMedia,
    String? other,
    List<String>? groups,
    List<ContactImage>? images,
    List<Encounter>? encounters,
  }) {
    return Contact(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      company: company ?? this.company,
      jobTitle: jobTitle ?? this.jobTitle,
      phone: phone ?? this.phone,
      mobilePhone: mobilePhone ?? this.mobilePhone,
      email: email ?? this.email,
      website: website ?? this.website,
      address: address ?? this.address,
      socialMedia: socialMedia ?? this.socialMedia,
      other: other ?? this.other,
      groups: groups ?? this.groups,
      images: images ?? this.images,
      encounters: encounters ?? this.encounters,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'name': name,
      'company': company,
      'jobTitle': jobTitle,
      'phone': phone,
      'mobilePhone': mobilePhone,
      'email': email,
      'website': website,
      'address': address,
      'socialMedia': socialMedia,
      'other': other,
      'groups': groups,
      'images': images.map((image) => image.toJson()).toList(),
      'encounters': encounters.map((encounter) => encounter.toJson()).toList(),
    };
  }

  factory Contact.fromJson(Map<String, Object?> json) {
    return Contact(
      id: (json['id'] as String?) ?? '',
      createdAt: _parseDate(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _parseDate(json['updatedAt']),
      name: (json['name'] as String?) ?? '',
      company: (json['company'] as String?) ?? '',
      jobTitle: (json['jobTitle'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      mobilePhone: (json['mobilePhone'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      website: (json['website'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      socialMedia: (json['socialMedia'] as String?) ?? '',
      other: (json['other'] as String?) ?? '',
      groups: ((json['groups'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      images: ((json['images'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => ContactImage.fromJson(item.cast<String, Object?>()))
          .toList(growable: false),
      encounters: ((json['encounters'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => Encounter.fromJson(item.cast<String, Object?>()))
          .toList(growable: false),
    );
  }

  Map<String, Object?> toIndexJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'company': company,
      'jobTitle': jobTitle,
      'other': other,
      'groups': List<String>.from(groups)..sort(),
      'encounters': (encounters.map((e) => e.toIndexJson()).toList()
            ..sort((a, b) =>
                (a['id'] as String).compareTo(b['id'] as String))),
    };
  }
}

class ContactImage {
  const ContactImage({
    required this.url,
    this.alt = '',
  });

  final String url;
  final String alt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'url': url,
      'alt': alt,
    };
  }

  factory ContactImage.fromJson(Map<String, Object?> json) {
    return ContactImage(
      url: (json['url'] as String?) ?? '',
      alt: (json['alt'] as String?) ?? '',
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

