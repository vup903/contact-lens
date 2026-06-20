import 'package:contact_lens/data/data.dart';
import 'package:contact_lens/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('repository seeds sample data and stores manifest', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const repository = SharedPreferencesContactRepository();

    final dataset = await repository.load();

    expect(dataset.contacts, isNotEmpty);
    expect(dataset.groups, isNotEmpty);
    expect(dataset.manifest.contacts.length, dataset.contacts.length);
  });

  test('repository saves contacts and rebuilds manifest', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const repository = SharedPreferencesContactRepository();
    await repository.load();

    final saved = await repository.saveContacts(<Contact>[
      Contact(
        id: 'manual-1',
        createdAt: DateTime.utc(2026),
        name: 'Manual Contact',
        other: 'Local test note',
      ),
    ]);

    expect(saved.contacts, hasLength(1));
    expect(saved.manifest.contacts.single.contactId, 'manual-1');
  });
}

