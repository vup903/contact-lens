import 'parsed_business_card.dart';

final _emailRegex = RegExp(
  r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
  caseSensitive: false,
);
final _urlRegex = RegExp(
  r'((https?:\/\/)?(www\.)?[a-z0-9-]+\.[a-z]{2,}(\/[^\s]*)?)',
  caseSensitive: false,
);
final _phoneRegex = RegExp(r'(\+?\d[\d\s().\-（）]{6,}\d)');
final _extRegex = RegExp(r'(ext\.?|x|#|轉|分機)\s*[:：]?\s*(\d{1,6})', caseSensitive: false);

ParsedBusinessCard parseBusinessCardText(String rawText) {
  final text = rawText.replaceAll('\r\n', '\n').trim();
  final lines = text
      .split('\n')
      .map(_normalizeLine)
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  final email = _extractFirstMatch(_emailRegex, text);
  var phone = '';
  var mobilePhone = '';
  var fax = '';

  final allPhones = _extractAllMatches(_phoneRegex, text).map(_cleanPhone).where((phone) => phone.isNotEmpty).toList();
  for (final line in lines) {
    final localPhones = _extractAllMatches(_phoneRegex, line).map(_cleanPhone).where((phone) => phone.isNotEmpty).toList();
    if (localPhones.isEmpty) {
      continue;
    }

    final hasFaxHint = RegExp(r'(fax|傳真)', caseSensitive: false).hasMatch(line);
    if (hasFaxHint && fax.isEmpty) {
      fax = _withExtension(line, localPhones.first);
      continue;
    }

    final hasMobileHint = RegExp(r'(mobile|cell|m:|手機|行動|行動電話)', caseSensitive: false).hasMatch(line);
    if (hasMobileHint && mobilePhone.isEmpty) {
      final candidate = _withExtension(line, localPhones.first);
      if (candidate.startsWith('09')) {
        mobilePhone = candidate;
        continue;
      }
      if (phone.isEmpty) {
        phone = candidate;
      }
      continue;
    }

    final hasPhoneHint = RegExp(r'(tel|phone|電話|總機)', caseSensitive: false).hasMatch(line);
    if (hasPhoneHint && phone.isEmpty) {
      phone = _withExtension(line, localPhones.first);
      continue;
    }

    if (phone.isEmpty) {
      phone = _withExtension(line, localPhones.first);
    }
  }

  if (phone.isEmpty && allPhones.isNotEmpty) {
    phone = allPhones.first;
  }
  if (mobilePhone.isEmpty) {
    mobilePhone = allPhones.firstWhere(
      (candidate) => candidate.startsWith('09'),
      orElse: () => '',
    );
  }

  final orgLines = lines.where(_looksLikeOrganization).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final companyLine = orgLines.isNotEmpty
      ? orgLines.first
      : lines.firstWhere(_looksLikeCompany, orElse: () => '');
  final jobTitleLine = _normalizeJobTitle(
    lines.firstWhere(
      (line) => _looksLikeJobTitle(line) || line.contains('襄里'),
      orElse: () => '',
    ),
  );

  final candidateLines = lines.where((line) => !_isNoiseLine(line)).toList();
  var nameLine = lines.firstWhere(_looksLikeName, orElse: () => '');
  if (nameLine.isEmpty) {
    final nameCandidates = candidateLines.where(_isLikelyChinesePersonName).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    nameLine = nameCandidates.isNotEmpty
        ? nameCandidates.first
        : candidateLines.firstWhere(
            (line) => !_looksLikeOrganization(line) && !_looksLikeJobTitle(line) && !_looksLikeAddress(line),
            orElse: () => '',
          );
  }

  var finalCompany = companyLine;
  if (finalCompany.isEmpty) {
    final nameIndex = candidateLines.indexWhere((line) => line == nameLine);
    final afterName = nameIndex >= 0 ? candidateLines.skip(nameIndex + 1).toList() : candidateLines;
    finalCompany = afterName.firstWhere(
      _looksLikeOrganization,
      orElse: () => afterName.firstWhere(
        _looksLikeCompany,
        orElse: () => afterName.firstWhere(
          (line) => !_looksLikeJobTitle(line) && !_looksLikeAddress(line),
          orElse: () => candidateLines.length > 1 ? candidateLines[1] : '',
        ),
      ),
    );
  }

  var addressLine = lines.firstWhere(_looksLikeAddress, orElse: () => '');
  if (addressLine.isEmpty) {
    addressLine = candidateLines.firstWhere(
      (line) =>
          RegExp(r'\d').hasMatch(line) &&
          RegExp(
            r'(號|樓|St\.|Street|Ave\.|Avenue|Rd\.|Road|Blvd\.|Boulevard|Suite)',
            caseSensitive: false,
          ).hasMatch(line),
      orElse: () => '',
    );
  }

  return ParsedBusinessCard(
    rawText: text,
    name: nameLine,
    company: finalCompany,
    jobTitle: jobTitleLine,
    phone: phone,
    mobilePhone: mobilePhone,
    email: email,
    website: '',
    address: _stripAddressPrefix(addressLine),
    fax: fax,
  );
}

String _normalizeLine(String line) {
  return line.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _extractFirstMatch(RegExp regex, String text) {
  return regex.firstMatch(text)?.group(0)?.trim() ?? '';
}

List<String> _extractAllMatches(RegExp regex, String text) {
  return regex.allMatches(text).map((match) => match.group(0)?.trim() ?? '').where((item) => item.isNotEmpty).toList();
}

String _cleanPhone(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final plus = trimmed.startsWith('+') ? '+' : '';
  final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
  return '$plus$digits';
}

String _withExtension(String originalLine, String phone) {
  if (phone.isEmpty) {
    return '';
  }
  final ext = _extRegex.firstMatch(originalLine)?.group(2) ?? '';
  if (ext.isEmpty) {
    return phone;
  }
  return '$phone#$ext';
}

bool _looksLikeOrganization(String line) {
  return RegExp(r'(銀行|中央銀行|外匯局|局|處|部|室|組|科|中心|基金會|協會|學會|公司|股份有限公司|有限公司)').hasMatch(line);
}

bool _looksLikeCompany(String line) {
  return RegExp(
    r'(inc\.?|ltd\.?|llc|co\.|corp\.|company|股份有限公司|有限公司|公司|企業|集團)',
    caseSensitive: false,
  ).hasMatch(line);
}

bool _looksLikeJobTitle(String line) {
  return RegExp(
    r'(ceo|cto|cfo|coo|founder|director|manager|engineer|consultant|sales|marketing|product|designer|president|vp|vice president|經理|襄理|副理|助理|主任|專員|科長|組長|總監|工程師|顧問|業務|行銷|產品|設計|董事長|總經理|副總)',
    caseSensitive: false,
  ).hasMatch(line);
}

bool _looksLikeAddress(String line) {
  return RegExp(
    r'(路|街|巷|弄|號|樓|市|區|縣|鄉|鎮|村|里|大道|段|St\.|Street|Ave\.|Avenue|Rd\.|Road|Blvd\.|Boulevard|Suite|Floor|Zip|Postal)',
    caseSensitive: false,
  ).hasMatch(line);
}

String _stripAddressPrefix(String line) {
  return line.replaceFirst(RegExp(r'^(行址|地址|住址|Add\.?|Address)\s*[:：]\s*', caseSensitive: false), '').trim();
}

String _normalizeJobTitle(String line) {
  return line.replaceAll('襄里', '襄理').trim();
}

bool _isLikelyChinesePersonName(String line) {
  final trimmed = line.trim();
  if (!RegExp(r'^[\u4e00-\u9fff]{2,3}$').hasMatch(trimmed)) {
    return false;
  }
  return !_looksLikeOrganization(trimmed) && !_looksLikeJobTitle(trimmed) && !_looksLikeAddress(trimmed);
}

bool _looksLikeName(String line) {
  if (line.isEmpty || RegExp(r'\d').hasMatch(line) || line.contains('@') || RegExp(r'https?:\/\/', caseSensitive: false).hasMatch(line)) {
    return false;
  }
  if (_looksLikeCompany(line) || _looksLikeOrganization(line) || _looksLikeJobTitle(line) || _looksLikeAddress(line)) {
    return false;
  }
  if (RegExp(r'^[\u4e00-\u9fff]{2,3}$').hasMatch(line)) {
    return true;
  }
  return RegExp(r"^[A-Za-z][A-Za-z'.-]*(\s+[A-Za-z][A-Za-z'.-]*)+$").hasMatch(line);
}

bool _isNoiseLine(String line) {
  if (line.isEmpty) {
    return true;
  }
  if (_emailRegex.hasMatch(line) || _urlRegex.hasMatch(line) || _phoneRegex.hasMatch(line)) {
    return true;
  }
  return RegExp(r'^(tel|phone|mobile|fax|email|www|web|地址|電話|手機|傳真)[:：]?\s*$', caseSensitive: false).hasMatch(line);
}

