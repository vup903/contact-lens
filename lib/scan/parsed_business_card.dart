import '../domain/domain.dart';

class ParsedBusinessCard {
  const ParsedBusinessCard({
    required this.rawText,
    this.name = '',
    this.company = '',
    this.jobTitle = '',
    this.phone = '',
    this.mobilePhone = '',
    this.email = '',
    this.website = '',
    this.address = '',
    this.socialMedia = '',
    this.other = '',
    this.fax = '',
  });

  final String rawText;
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
  final String fax;

  Contact toContact({
    required String id,
    required DateTime createdAt,
    List<String> groups = const <String>[],
    String imageUrl = '',
  }) {
    final scanNote = rawText.trim().isEmpty ? '' : 'Original OCR text:\n$rawText';
    return Contact(
      id: id,
      createdAt: createdAt,
      name: name,
      company: company,
      jobTitle: jobTitle,
      phone: phone,
      mobilePhone: mobilePhone,
      email: email,
      website: website,
      address: address,
      socialMedia: socialMedia,
      other: other.trim().isNotEmpty ? other : scanNote,
      groups: groups,
      images: imageUrl.trim().isEmpty
          ? const <ContactImage>[]
          : <ContactImage>[ContactImage(url: imageUrl, alt: 'Business card')],
    );
  }
}

