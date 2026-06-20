import 'parsed_business_card.dart';

final _emailRegex = RegExp(
  '[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}',
  caseSensitive: false,
);
final _urlRegex = RegExp(
  '((https?:\\/\\/)?(www\\.)?[a-z0-9-]+\\.[a-z]{2,}(\\/[^\\s]*)?)',
  caseSensitive: false,
);
final _phoneRegex = RegExp('(\\+?\\d[\\d\\s().\\-\uFF08\uFF09]{6,}\\d)');
final _extRegex = RegExp(
  '(ext\\.?|x|#|\u8f49|\u5206\u6a5f)\\s*[:\uFF1A]?\\s*(\\d{1,6})',
  caseSensitive: false,
);
final _faxHintRegex = RegExp('(fax|\u50b3\u771f)', caseSensitive: false);
final _mobileHintRegex = RegExp(
  '(mobile|cell|m:|\u624b\u6a5f|\u884c\u52d5|\u884c\u52d5\u96fb\u8a71)',
  caseSensitive: false,
);
final _phoneHintRegex = RegExp(
  '(tel|phone|\u96fb\u8a71|\u7e3d\u6a5f)',
  caseSensitive: false,
);
final _addressHintRegex = RegExp(
  '(add\\.?|address|\u5730\u5740|\u4f4f\u5740)',
  caseSensitive: false,
);
final _addressTokenRegex = RegExp(
  '(\u5e02|\u5340|\u7e23|\u9109|\u93ae|\u6751|\u8def|\u8857|\u5df7|\u5f04|\u865f|\u6a13|\u5927\u9053|\u6bb5|'
  'St\\.|Street|Ave\\.|Avenue|Rd\\.|Road|Blvd\\.|Boulevard|Suite|Floor|Zip|Postal)',
  caseSensitive: false,
);
final _organizationRegex = RegExp(
  '(inc\\.?|ltd\\.?|llc|co\\.|corp\\.|company|studio|'
  '\u4e2d\u592e\u9280\u884c|\u9280\u884c|\u5916\u532f\u5c40|\u516c\u53f8|\u6709\u9650|\u80a1\u4efd|'
  '\u4f01\u696d|\u96c6\u5718|\u91ab\u9662|\u5927\u5b78|\u5b78\u9662|\u57fa\u91d1\u6703|\u5354\u6703|\u5c40)',
  caseSensitive: false,
);
final _companyRegex = RegExp(
  '(inc\\.?|ltd\\.?|llc|co\\.|corp\\.|company|studio|'
  '\u516c\u53f8|\u6709\u9650|\u80a1\u4efd|\u4f01\u696d|\u96c6\u5718|\u9280\u884c|\u5c40)',
  caseSensitive: false,
);
final _chineseJobTitleRegex = RegExp(
  '(\u8463\u4e8b\u9577|\u7e3d\u7d93\u7406|\u7522\u54c1\u7d93\u7406|\u57f7\u884c\u9577|\u5275\u8fa6\u4eba|'
  '\u7e3d\u76e3|\u526f\u7e3d|\u7e3d\u88c1|\u5354\u7406|\u526f\u7406|\u8944\u7406|\u7d93\u7406|'
  '\u8ca0\u8cac\u4eba|\u4e3b\u4efb|\u5c08\u54e1|\u52a9\u7406|\u9867\u554f|\u5de5\u7a0b\u5e2b|'
  '\u8a2d\u8a08\u5e2b|\u696d\u52d9)',
);
final _englishJobTitleRegex = RegExp(
  '(ceo|cto|cfo|coo|founder|director|manager|engineer|consultant|sales|marketing|product|designer|president|vp|vice president)',
  caseSensitive: false,
);

const _wrongAssistantManagerTitle = '\u8944\u91cc';
const _assistantManagerTitle = '\u8944\u7406';

ParsedBusinessCard parseBusinessCardText(String rawText) {
  final text = rawText.replaceAll('\r\n', '\n').trim();
  final lines = text
      .split('\n')
      .map(_normalizeLine)
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  final email = _extractFirstMatch(_emailRegex, text);
  final phonesByLine = <String, List<String>>{};
  final allPhones = <String>[];
  var phone = '';
  var mobilePhone = '';
  var fax = '';

  for (final line in lines) {
    final localPhones = _extractAllMatches(_phoneRegex, line)
        .map(_cleanPhone)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (localPhones.isEmpty) {
      continue;
    }

    phonesByLine[line] = localPhones;
    allPhones.addAll(localPhones);

    if (_faxHintRegex.hasMatch(line) && fax.isEmpty) {
      fax = _withExtension(line, localPhones.first);
      continue;
    }

    if (_mobileHintRegex.hasMatch(line) && mobilePhone.isEmpty) {
      final candidate = localPhones.firstWhere(
        _isTaiwanMobilePhone,
        orElse: () => localPhones.first,
      );
      if (_isTaiwanMobilePhone(candidate)) {
        mobilePhone = candidate;
        continue;
      }
      if (phone.isEmpty) {
        phone = _withExtension(line, candidate);
      }
      continue;
    }

    if (_phoneHintRegex.hasMatch(line) && phone.isEmpty) {
      phone = _withExtension(line, localPhones.first);
      continue;
    }

    if (phone.isEmpty && !_isTaiwanMobilePhone(localPhones.first)) {
      phone = _withExtension(line, localPhones.first);
    }
  }

  if (mobilePhone.isEmpty) {
    mobilePhone = allPhones.firstWhere(_isTaiwanMobilePhone, orElse: () => '');
  }
  if (phone.isEmpty) {
    phone = allPhones.firstWhere(
      (candidate) => !_isTaiwanMobilePhone(candidate),
      orElse: () => allPhones.isNotEmpty ? allPhones.first : '',
    );
  }

  final jobTitleLine = _extractJobTitle(lines);
  final candidateLines = lines
      .where((line) => !_isNoiseLine(line, phonesByLine))
      .toList();
  final nameLine = _extractName(lines, candidateLines);
  final companyLine = _extractCompany(lines, candidateLines, nameLine);
  final addressLine = lines.firstWhere(_looksLikeAddress, orElse: () => '');

  return ParsedBusinessCard(
    rawText: text,
    name: nameLine,
    company: companyLine,
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
  return line.replaceAll(RegExp('\\s+'), ' ').trim();
}

String _extractFirstMatch(RegExp regex, String text) {
  return regex.firstMatch(text)?.group(0)?.trim() ?? '';
}

List<String> _extractAllMatches(RegExp regex, String text) {
  return regex
      .allMatches(text)
      .map((match) => match.group(0)?.trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

String _cleanPhone(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final plus = trimmed.startsWith('+') ? '+' : '';
  final digits = trimmed.replaceAll(RegExp('[^\\d]'), '');
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

bool _isTaiwanMobilePhone(String phone) {
  return phone.startsWith('09') && phone.length == 10;
}

String _extractJobTitle(List<String> lines) {
  for (final line in lines) {
    final normalized = _normalizeJobTitle(line);
    final chineseTitle = _chineseJobTitleRegex.firstMatch(normalized)?.group(0);
    if (chineseTitle != null && chineseTitle.isNotEmpty) {
      return chineseTitle;
    }
    if (_englishJobTitleRegex.hasMatch(normalized) &&
        !_looksLikeOrganization(normalized)) {
      return normalized;
    }
  }
  return '';
}

String _extractName(List<String> lines, List<String> candidateLines) {
  for (final line in lines) {
    final withoutTitle = _removeChineseJobTitle(line);
    if (_looksLikeName(withoutTitle)) {
      return withoutTitle;
    }
  }

  final nameCandidates =
      candidateLines
          .map(_removeChineseJobTitle)
          .where(_isLikelyChinesePersonName)
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  if (nameCandidates.isNotEmpty) {
    return nameCandidates.first;
  }

  return candidateLines.firstWhere(
    (line) =>
        !_looksLikeOrganization(line) &&
        !_looksLikeJobTitle(line) &&
        !_looksLikeAddress(line),
    orElse: () => '',
  );
}

String _extractCompany(
  List<String> lines,
  List<String> candidateLines,
  String nameLine,
) {
  final searchableLines = candidateLines.isNotEmpty ? candidateLines : lines;
  final orgLines = searchableLines.where(_looksLikeOrganization).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (orgLines.isNotEmpty) {
    return orgLines.first;
  }

  final companyLine = searchableLines.firstWhere(
    _looksLikeCompany,
    orElse: () => '',
  );
  if (companyLine.isNotEmpty) {
    return companyLine;
  }

  final nameIndex = candidateLines.indexWhere(
    (line) => _removeChineseJobTitle(line) == nameLine,
  );
  final afterName = nameIndex >= 0
      ? candidateLines.skip(nameIndex + 1).toList()
      : candidateLines;
  return afterName.firstWhere(
    (line) => !_looksLikeJobTitle(line) && !_looksLikeAddress(line),
    orElse: () => candidateLines.length > 1 ? candidateLines[1] : '',
  );
}

bool _looksLikeOrganization(String line) {
  return _organizationRegex.hasMatch(line);
}

bool _looksLikeCompany(String line) {
  return _companyRegex.hasMatch(line);
}

bool _looksLikeJobTitle(String line) {
  final normalized = _normalizeJobTitle(line);
  return _chineseJobTitleRegex.hasMatch(normalized) ||
      _englishJobTitleRegex.hasMatch(normalized);
}

bool _looksLikeAddress(String line) {
  if (_addressHintRegex.hasMatch(line)) {
    return true;
  }
  return RegExp('\\d').hasMatch(line) && _addressTokenRegex.hasMatch(line);
}

String _stripAddressPrefix(String line) {
  return line
      .replaceFirst(
        RegExp(
          '^(\u5730\u5740|\u4f4f\u5740|Add\\.?|Address)\\s*[:\uFF1A]?\\s*',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
}

String _normalizeJobTitle(String line) {
  return line
      .replaceAll(_wrongAssistantManagerTitle, _assistantManagerTitle)
      .trim();
}

String _removeChineseJobTitle(String line) {
  final normalized = _normalizeJobTitle(line);
  return normalized
      .replaceAll(_chineseJobTitleRegex, '')
      .replaceAll(RegExp('[,\uFF0C/\\-\\s]+'), ' ')
      .trim();
}

bool _isLikelyChinesePersonName(String line) {
  final trimmed = line.trim();
  if (!RegExp(r'^[\u4e00-\u9fff]{2,4}$').hasMatch(trimmed)) {
    return false;
  }
  return !_looksLikeOrganization(trimmed) &&
      !_looksLikeJobTitle(trimmed) &&
      !_looksLikeAddress(trimmed);
}

bool _looksLikeName(String line) {
  if (line.isEmpty ||
      RegExp('\\d').hasMatch(line) ||
      line.contains('@') ||
      RegExp('https?:\\/\\/', caseSensitive: false).hasMatch(line)) {
    return false;
  }
  if (_looksLikeCompany(line) ||
      _looksLikeOrganization(line) ||
      _looksLikeJobTitle(line) ||
      _looksLikeAddress(line)) {
    return false;
  }
  if (RegExp(r'^[\u4e00-\u9fff]{2,4}$').hasMatch(line)) {
    return true;
  }
  return RegExp(
    '^[A-Za-z][A-Za-z\'.-]*(\\s+[A-Za-z][A-Za-z\'.-]*)+\$',
  ).hasMatch(line);
}

bool _isNoiseLine(String line, Map<String, List<String>> phonesByLine) {
  if (line.isEmpty) {
    return true;
  }
  if (_emailRegex.hasMatch(line) ||
      _urlRegex.hasMatch(line) ||
      phonesByLine.containsKey(line)) {
    return true;
  }
  return RegExp(
    '^(tel|phone|mobile|fax|email|www|web|\u5730\u5740|\u96fb\u8a71|\u624b\u6a5f|\u50b3\u771f)[:\uFF1A]?\\s*\$',
    caseSensitive: false,
  ).hasMatch(line);
}
