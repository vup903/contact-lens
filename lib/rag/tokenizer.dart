final _cjkPattern = RegExp(r'[\u3400-\u9fff]');
final _latinPattern = RegExp(r'[a-z0-9]+');
final _spacePattern = RegExp(r'\s+');

String normalizeSearchText(String value) {
  return value
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u200b', '')
      .replaceAll(_spacePattern, ' ')
      .trim()
      .toLowerCase();
}

List<String> tokenizeQuery(String query) {
  final normalized = normalizeSearchText(query);
  if (normalized.isEmpty) {
    return const <String>[];
  }

  final tokens = <String>[];
  final seen = <String>{};
  final latinBuffer = StringBuffer();
  final cjkBuffer = StringBuffer();

  void addToken(String token) {
    final clean = token.trim();
    if (clean.isEmpty || seen.contains(clean)) {
      return;
    }
    seen.add(clean);
    tokens.add(clean);
  }

  void flushLatin() {
    final text = latinBuffer.toString();
    latinBuffer.clear();
    for (final match in _latinPattern.allMatches(text)) {
      addToken(match.group(0)!);
    }
  }

  void flushCjk() {
    final run = cjkBuffer.toString();
    cjkBuffer.clear();
    if (run.isEmpty) {
      return;
    }
    for (final rune in run.runes) {
      addToken(String.fromCharCode(rune));
    }
    if (run.runes.length > 1) {
      final chars = run.runes.map(String.fromCharCode).toList();
      for (var i = 0; i < chars.length - 1; i += 1) {
        addToken('${chars[i]}${chars[i + 1]}');
      }
    }
    addToken(run);
  }

  for (final rune in normalized.runes) {
    final char = String.fromCharCode(rune);
    if (_cjkPattern.hasMatch(char)) {
      flushLatin();
      cjkBuffer.write(char);
      continue;
    }
    flushCjk();
    latinBuffer.write(char);
  }
  flushLatin();
  flushCjk();

  return tokens;
}

int countOccurrences(String haystack, String needle) {
  if (needle.isEmpty || haystack.isEmpty) {
    return 0;
  }
  var count = 0;
  var index = 0;
  while (true) {
    final next = haystack.indexOf(needle, index);
    if (next == -1) {
      return count;
    }
    count += 1;
    index = next + needle.length;
  }
}

