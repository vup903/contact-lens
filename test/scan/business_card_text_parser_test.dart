import 'package:contact_lens/scan/scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Taiwan business card with mobile, extension, and title correction', () {
    final parsed = parseBusinessCardText('''
中央銀行外匯局
吳桂華
襄里
電話：(02)2357-1234 分機 321
手機：0912-345-678
Email: kuei.hua@example.gov.tw
地址：台北市中正區羅斯福路一段2號
''');

    expect(parsed.name, '吳桂華');
    expect(parsed.company, '中央銀行外匯局');
    expect(parsed.jobTitle, '襄理');
    expect(parsed.phone, '0223571234#321');
    expect(parsed.mobilePhone, '0912345678');
    expect(parsed.email, 'kuei.hua@example.gov.tw');
    expect(parsed.address, '台北市中正區羅斯福路一段2號');
  });

  test('parses English business card without auto-filling website', () {
    final parsed = parseBusinessCardText('''
Jordan Lee
Studio Northstar LLC
Product Designer
Mobile +1 (415) 555-0101
jordan@example.com
www.studionorthstar.example
''');

    expect(parsed.name, 'Jordan Lee');
    expect(parsed.company, 'Studio Northstar LLC');
    expect(parsed.jobTitle, 'Product Designer');
    expect(parsed.phone, '+14155550101');
    expect(parsed.email, 'jordan@example.com');
    expect(parsed.website, isEmpty);
  });
}

