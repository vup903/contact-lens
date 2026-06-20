import 'package:contact_lens/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest rebuilds when contact content changes', () {
    final contacts = <Contact>[
      Contact(
        id: '1',
        createdAt: DateTime.utc(2026),
        name: 'Alex Chen',
        company: 'Nexora AI',
      ),
    ];
    final manifest = RagManifest.build(contacts);
    final changed = contacts.first.copyWith(company: 'Nexora Labs');

    expect(manifest.needsRebuild(<Contact>[changed]), isTrue);
  });

  test('manifest rebuilds when pipeline fingerprint changes', () {
    final contacts = <Contact>[
      Contact(id: '1', createdAt: DateTime.utc(2026), name: 'Alex Chen'),
    ];
    final manifest = RagManifest.build(contacts);

    expect(
      manifest.needsRebuild(
        contacts,
        fingerprint: const RagPipelineFingerprint(weightsVersion: 'new-weights'),
      ),
      isTrue,
    );
  });
}

