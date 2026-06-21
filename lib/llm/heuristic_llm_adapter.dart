import 'llm_adapter.dart';

/// Pure-Dart, deterministic [LlmAdapter]. No network, no plugins — this is the
/// default adapter and the only one the headless demo and tests use (C1/C3).
///
///  * [summarizeNote] derives a one-line summary (first sentence) and tags via
///    a curated keyword dictionary, falling back to salient note words so the
///    tag list is never empty (C2).
///  * [parseQuery] resolves relative/explicit dates (English + Traditional
///    Chinese) against an injected [now] and extracts a known place, stripping
///    both spans from the residual semantic text.
class HeuristicLlmAdapter implements LlmAdapter {
  const HeuristicLlmAdapter();

  @override
  bool get isRemote => false;

  @override
  Future<NoteInsight> summarizeNote(String text, {DateTime? now}) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      return const NoteInsight.empty();
    }
    return NoteInsight(summary: _firstSentence(clean), tags: _extractTags(clean));
  }

  @override
  Future<ParsedQuery> parseQuery(
    String naturalLanguageQuery, {
    DateTime? now,
  }) async {
    final query = naturalLanguageQuery.trim();
    final reference = (now ?? DateTime.now()).toUtc();

    final spansToStrip = <String>[];

    final time = _parseTimeRange(query, reference, spansToStrip);
    final location = _parsePlace(query, spansToStrip);

    return ParsedQuery(
      semanticText: _stripSpans(query, spansToStrip),
      startUtc: time?.start,
      endUtc: time?.end,
      locationText: location,
    );
  }

  // --- Note summarization -------------------------------------------------

  static final _sentenceBoundary = RegExp(r'[.!?。！？\n]');

  String _firstSentence(String text) {
    final first = text
        .split(_sentenceBoundary)
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => text.trim());
    if (first.length <= 120) {
      return first;
    }
    return '${first.substring(0, 117).trimRight()}…';
  }

  static final _wordPattern = RegExp(r'[a-z][a-z+#0-9]{3,}');

  // Common note filler words excluded from the salient-word fallback.
  static const _noiseWords = <String>{
    'with', 'that', 'this', 'they', 'them', 'were', 'have', 'about', 'their',
    'would', 'could', 'should', 'from', 'into', 'over', 'after', 'before',
    'discussed', 'talked', 'mentioned', 'really', 'great', 'very', 'some',
    'also', 'then', 'when', 'where', 'which', 'while', 'doing', 'working',
    'works', 'work', 'looking', 'interested', 'people', 'person', 'someone',
  };

  List<String> _extractTags(String text) {
    final lower = text.toLowerCase();
    final tags = <String>[];
    final seen = <String>{};

    void add(String tag) {
      if (seen.add(tag)) {
        tags.add(tag);
      }
    }

    for (final rule in _tagRules) {
      if (rule.matches(lower, text)) {
        add(rule.tag);
      }
    }

    if (tags.length < 3) {
      final counts = <String, int>{};
      for (final match in _wordPattern.allMatches(lower)) {
        final word = match.group(0)!;
        if (_noiseWords.contains(word) || seen.contains(word)) {
          continue;
        }
        counts[word] = (counts[word] ?? 0) + 1;
      }
      final ranked = counts.keys.toList()
        ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
      for (final word in ranked) {
        if (tags.length >= 6) {
          break;
        }
        add(word);
      }
    }

    return List<String>.unmodifiable(tags.take(6));
  }

  // --- Query understanding ------------------------------------------------

  static final _isoDate = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');

  ({DateTime start, DateTime end})? _parseTimeRange(
    String query,
    DateTime now,
    List<String> spans,
  ) {
    // Explicit ISO dates win over relative phrases (most specific).
    final isoMatches = _isoDate.allMatches(query).toList();
    if (isoMatches.isNotEmpty) {
      final days = isoMatches
          .map((m) => DateTime.utc(
                int.parse(m.group(1)!),
                int.parse(m.group(2)!),
                int.parse(m.group(3)!),
              ))
          .toList()
        ..sort();
      for (final m in isoMatches) {
        spans.add(m.group(0)!);
      }
      return (start: _dayStart(days.first), end: _dayEnd(days.last));
    }

    final lower = query.toLowerCase();
    for (final rule in _timeRules) {
      for (final trigger in rule.triggers) {
        if (lower.contains(trigger)) {
          spans.add(trigger);
          return rule.range(now);
        }
      }
    }
    return null;
  }

  String _parsePlace(String query, List<String> spans) {
    final lower = query.toLowerCase();
    for (final city in _cities) {
      for (final alias in city.aliases) {
        if (alias.matches(lower)) {
          spans.add(alias.value);
          return city.canonical;
        }
      }
    }
    // Fallback: a capitalized multi-word run that is not a sentence-initial
    // filler word. Conservative — only used when no known city matched.
    for (final match in _capitalized.allMatches(query)) {
      final candidate = match.group(0)!.trim();
      if (!_capitalizedStop.contains(candidate.toLowerCase())) {
        spans.add(candidate);
        return candidate;
      }
    }
    return '';
  }

  static final _capitalized = RegExp(r'[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*');
  static const _capitalizedStop = <String>{
    'i', 'what', 'who', 'where', 'when', 'why', 'how', 'the', 'a', 'an', 'my',
    'find', 'looking', 'show', 'me', 'do', 'does', 'is', 'are', 'name',
  };

  String _stripSpans(String query, List<String> spans) {
    var residual = query;
    for (final span in spans) {
      if (span.isEmpty) {
        continue;
      }
      residual = residual.replaceAll(
        RegExp(RegExp.escape(span), caseSensitive: false),
        ' ',
      );
    }
    return residual.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static DateTime _dayStart(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  static DateTime _dayEnd(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day + 1)
          .subtract(const Duration(milliseconds: 1));
}

// --- Time rules -----------------------------------------------------------

typedef _Range = ({DateTime start, DateTime end});

DateTime _monthStart(int year, int month) => DateTime.utc(year, month, 1);
_Range _month(int year, int month) => (
      start: _monthStart(year, month),
      end: _monthStart(year, month + 1).subtract(const Duration(milliseconds: 1)),
    );

_Range _weekOf(DateTime now, {int weeksAgo = 0}) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final start = monday.subtract(Duration(days: 7 * weeksAgo));
  return (
    start: start,
    end: start
        .add(const Duration(days: 7))
        .subtract(const Duration(milliseconds: 1)),
  );
}

_Range _dayOf(DateTime now, {int daysAgo = 0}) {
  final start = DateTime.utc(now.year, now.month, now.day)
      .subtract(Duration(days: daysAgo));
  return (
    start: start,
    end: start
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1)),
  );
}

class _TimeRule {
  const _TimeRule(this.triggers, this.range);
  final List<String> triggers;
  final _Range Function(DateTime now) range;
}

// Ordered most-specific-first. Triggers are lowercased; CJK is unaffected by
// lowercasing so every trigger is matched against the lowercased query.
final _timeRules = <_TimeRule>[
  _TimeRule(['yesterday', '昨天', '昨日'], (now) => _dayOf(now, daysAgo: 1)),
  _TimeRule(['today', '今天', '今日'], (now) => _dayOf(now)),
  _TimeRule(
    ['last week', 'past week', '上週', '上星期', '上个星期', '上個星期'],
    (now) => _weekOf(now, weeksAgo: 1),
  ),
  _TimeRule(
    ['this week', '這週', '本週', '這星期', '本星期'],
    (now) => _weekOf(now),
  ),
  _TimeRule(
    ['last month', 'past month', '上個月', '上月', '上个月'],
    (now) => _month(now.year, now.month - 1),
  ),
  _TimeRule(
    ['this month', '這個月', '本月', '这个月'],
    (now) => _month(now.year, now.month),
  ),
  _TimeRule(
    ['last year', '去年'],
    (now) => (
      start: DateTime.utc(now.year - 1, 1, 1),
      end: DateTime.utc(now.year, 1, 1)
          .subtract(const Duration(milliseconds: 1)),
    ),
  ),
  _TimeRule(
    ['this year', '今年'],
    (now) => (
      start: DateTime.utc(now.year, 1, 1),
      end: DateTime.utc(now.year + 1, 1, 1)
          .subtract(const Duration(milliseconds: 1)),
    ),
  ),
];

// --- Place rules ----------------------------------------------------------

/// A place alias. ASCII aliases match on word boundaries (so "sf" does not fire
/// inside other words); CJK aliases match as plain substrings.
class _Alias {
  _Alias(this.value)
      : _ascii = RegExp(r'^[ -~]+$').hasMatch(value),
        _word = RegExp(r'^[ -~]+$').hasMatch(value)
            ? RegExp(r'\b' + RegExp.escape(value) + r'\b')
            : null;
  final String value;
  final bool _ascii;
  final RegExp? _word;

  bool matches(String lowerQuery) =>
      _ascii ? _word!.hasMatch(lowerQuery) : lowerQuery.contains(value);
}

class _City {
  _City(this.canonical, List<String> aliases)
      : aliases = aliases.map(_Alias.new).toList();
  final String canonical;
  final List<_Alias> aliases;
}

final _cities = <_City>[
  _City('San Francisco', ['san francisco', 'sf', '舊金山', '三藩市']),
  _City('New York', ['new york', 'nyc', '紐約']),
  _City('Taipei', ['taipei', '台北', '臺北']),
  _City('Tokyo', ['tokyo', '東京']),
  _City('London', ['london', '倫敦']),
  _City('Seattle', ['seattle', '西雅圖']),
  _City('Los Angeles', ['los angeles', '洛杉磯']),
  _City('Boston', ['boston', '波士頓']),
  _City('Beijing', ['beijing', '北京']),
  _City('Shanghai', ['shanghai', '上海']),
  _City('Shenzhen', ['shenzhen', '深圳']),
  _City('Hong Kong', ['hong kong', '香港']),
  _City('Singapore', ['singapore', '新加坡']),
  _City('Seoul', ['seoul', '首爾']),
  _City('Berlin', ['berlin', '柏林']),
  _City('Paris', ['paris', '巴黎']),
];

// --- Tag rules ------------------------------------------------------------

class _TagRule {
  _TagRule(this.pattern, this.tag)
      : _ascii = RegExp(r'^[ -~]+$').hasMatch(pattern),
        _word = RegExp(r'^[ -~]+$').hasMatch(pattern)
            ? RegExp(r'\b' + RegExp.escape(pattern) + r'\b')
            : null;
  final String pattern;
  final String tag;
  final bool _ascii;
  final RegExp? _word;

  bool matches(String lower, String original) =>
      _ascii ? _word!.hasMatch(lower) : original.contains(pattern);
}

// Curated professional-networking vocabulary. Synonyms collapse to a shared
// canonical tag so cross-language and abbreviated notes still match queries.
final _tagRules = <_TagRule>[
  _TagRule('machine learning', 'machine learning'),
  _TagRule('機器學習', 'machine learning'),
  _TagRule('ml', 'machine learning'),
  _TagRule('deep learning', 'deep learning'),
  _TagRule('深度學習', 'deep learning'),
  _TagRule('artificial intelligence', 'ai'),
  _TagRule('人工智慧', 'ai'),
  _TagRule('人工智能', 'ai'),
  _TagRule('ai', 'ai'),
  _TagRule('llm', 'llm'),
  _TagRule('nlp', 'nlp'),
  _TagRule('computer vision', 'computer vision'),
  _TagRule('data science', 'data science'),
  _TagRule('資料科學', 'data science'),
  _TagRule('data', 'data'),
  _TagRule('robotics', 'robotics'),
  _TagRule('機器人', 'robotics'),
  _TagRule('blockchain', 'blockchain'),
  _TagRule('crypto', 'crypto'),
  _TagRule('web3', 'web3'),
  _TagRule('fintech', 'fintech'),
  _TagRule('biotech', 'biotech'),
  _TagRule('healthcare', 'healthcare'),
  _TagRule('security', 'security'),
  _TagRule('cloud', 'cloud'),
  _TagRule('devops', 'devops'),
  _TagRule('frontend', 'frontend'),
  _TagRule('front-end', 'frontend'),
  _TagRule('backend', 'backend'),
  _TagRule('back-end', 'backend'),
  _TagRule('mobile', 'mobile'),
  _TagRule('flutter', 'flutter'),
  _TagRule('python', 'python'),
  _TagRule('rust', 'rust'),
  _TagRule('engineer', 'engineer'),
  _TagRule('engineering', 'engineer'),
  _TagRule('工程師', 'engineer'),
  _TagRule('developer', 'developer'),
  _TagRule('founder', 'founder'),
  _TagRule('co-founder', 'founder'),
  _TagRule('cofounder', 'founder'),
  _TagRule('創辦人', 'founder'),
  _TagRule('創始人', 'founder'),
  _TagRule('ceo', 'ceo'),
  _TagRule('cto', 'cto'),
  _TagRule('cfo', 'cfo'),
  _TagRule('designer', 'design'),
  _TagRule('design', 'design'),
  _TagRule('設計師', 'design'),
  _TagRule('product manager', 'product management'),
  _TagRule('product', 'product'),
  _TagRule('investor', 'investor'),
  _TagRule('investment', 'investor'),
  _TagRule('投資人', 'investor'),
  _TagRule('投資者', 'investor'),
  _TagRule('venture capital', 'venture capital'),
  _TagRule('researcher', 'research'),
  _TagRule('research', 'research'),
  _TagRule('研究員', 'research'),
  _TagRule('startup', 'startup'),
  _TagRule('新創', 'startup'),
  _TagRule('創業', 'startup'),
  _TagRule('fundraising', 'fundraising'),
  _TagRule('fundraise', 'fundraising'),
  _TagRule('hiring', 'hiring'),
  _TagRule('recruiter', 'hiring'),
  _TagRule('recruiting', 'hiring'),
  _TagRule('partnership', 'partnership'),
  _TagRule('partner', 'partnership'),
  _TagRule('collaboration', 'collaboration'),
  _TagRule('mentorship', 'mentorship'),
  _TagRule('mentor', 'mentorship'),
  _TagRule('internship', 'internship'),
  _TagRule('intern', 'internship'),
  _TagRule('demo', 'demo'),
];
