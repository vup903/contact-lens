import 'package:contact_lens/rag/rag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tokenizeQuery supports latin, numbers, and CJK tokens', () {
    final tokens = tokenizeQuery('AI fundraising 台灣人脈 2026');

    expect(tokens, containsAll(<String>['ai', 'fundraising', '2026']));
    expect(tokens, containsAll(<String>['台', '灣', '人', '脈']));
    expect(tokens, containsAll(<String>['台灣', '人脈']));
    expect(tokens, contains('台灣人脈'));
  });

  test('normalizeSearchText collapses whitespace and lowercases', () {
    expect(normalizeSearchText('  Nexora   AI  '), 'nexora ai');
  });
}

