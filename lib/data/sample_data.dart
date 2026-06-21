import '../domain/domain.dart';

final sampleGroups = <ContactGroup>[
  ContactGroup(
    id: 'group-ai',
    name: 'AI ecosystem',
    createdAt: DateTime.utc(2026, 1, 1),
  ),
  ContactGroup(
    id: 'group-finance',
    name: 'Finance',
    createdAt: DateTime.utc(2026, 1, 1),
  ),
  ContactGroup(
    id: 'group-design',
    name: 'Design partners',
    createdAt: DateTime.utc(2026, 1, 1),
  ),
  ContactGroup(
    id: 'group-taiwan',
    name: 'Taiwan network',
    createdAt: DateTime.utc(2026, 1, 1),
  ),
];

final sampleContacts = <Contact>[
  Contact(
    id: 'sample-alex-chen',
    createdAt: DateTime.utc(2026, 1, 5),
    name: 'Alex Chen',
    company: 'Nexora AI',
    jobTitle: 'Solutions Architect',
    email: 'alex.chen@example.com',
    mobilePhone: '0912345678',
    groups: const <String>['AI ecosystem', 'Taiwan network'],
    other:
        'Knows enterprise AI deployment, vector search, and on-premise data privacy reviews.',
    encounters: <Encounter>[
      Encounter(
        id: 'enc-alex-chen-1',
        occurredAt: DateTime.utc(2026, 4, 15, 10),
        placeLabel: 'Taipei, Taiwan',
        geo: const GeoPoint(latitude: 25.0330, longitude: 121.5654),
        note:
            'Met at an enterprise data-governance summit. Talked through on-prem '
            'deployment and data-residency reviews for regulated customers.',
        summary:
            'Enterprise data-governance summit; on-prem deployment and data residency.',
        tags: const <String>[
          'enterprise security',
          'data residency',
          'on-prem deployment',
        ],
      ),
    ],
  ),
  Contact(
    id: 'sample-mia-lin',
    createdAt: DateTime.utc(2026, 1, 8),
    name: '林美雅',
    company: 'Blue Peak Capital',
    jobTitle: 'Investment Manager',
    email: 'mia.lin@example.com',
    groups: const <String>['Finance', 'Taiwan network'],
    other: 'Focuses on B2B SaaS, productivity tools, and seed-stage fundraising.',
    encounters: <Encounter>[
      Encounter(
        id: 'enc-mia-lin-1',
        occurredAt: DateTime.utc(2026, 6, 15, 9),
        placeLabel: 'Taipei, Taiwan',
        geo: const GeoPoint(latitude: 25.0330, longitude: 121.5654),
        note: 'Coffee in Taipei about a seed-stage B2B SaaS round she is advising.',
        summary: 'Seed-stage B2B SaaS fundraising conversation in Taipei.',
        tags: const <String>['fundraising', 'venture capital', 'b2b saas'],
      ),
    ],
  ),
  Contact(
    id: 'sample-jordan-lee',
    createdAt: DateTime.utc(2026, 1, 12),
    name: 'Jordan Lee',
    company: 'Studio Northstar',
    jobTitle: 'Product Designer',
    groups: const <String>['Design partners'],
    other:
        'Strong at mobile onboarding, CRM workflows, visual systems, and App Store screenshots.',
    encounters: <Encounter>[
      Encounter(
        id: 'enc-jordan-lee-1',
        occurredAt: DateTime.utc(2026, 5, 20, 14),
        placeLabel: 'New York, NY',
        geo: const GeoPoint(latitude: 40.7128, longitude: -74.0060),
        note:
            'Design conference in New York. Reviewed mobile onboarding flows and a '
            'CRM redesign together.',
        summary: 'Design conference in New York; mobile onboarding and CRM redesign.',
        tags: const <String>['product design', 'mobile onboarding'],
      ),
    ],
  ),
  Contact(
    id: 'sample-wu-kuei-hua',
    createdAt: DateTime.utc(2026, 1, 18),
    name: '吳桂華',
    company: '中央銀行外匯局',
    jobTitle: '襄理',
    phone: '0223571234#321',
    groups: const <String>['Finance', 'Taiwan network'],
    other: 'Public-sector finance contact. Notes came from scanned business card OCR.',
    encounters: <Encounter>[
      Encounter(
        id: 'enc-wu-kuei-hua-1',
        occurredAt: DateTime.utc(2026, 3, 10, 11),
        placeLabel: 'Taipei, Taiwan',
        geo: const GeoPoint(latitude: 25.0330, longitude: 121.5654),
        note: 'Introduced at a central-bank fintech regulation forum in Taipei.',
        summary: 'Central-bank fintech regulation forum in Taipei.',
        tags: const <String>['public finance', 'fintech regulation'],
        source: EncounterSource.scan,
      ),
    ],
  ),
  Contact(
    id: 'sample-priya-shah',
    createdAt: DateTime.utc(2026, 2, 2),
    name: 'Priya Shah',
    company: 'Orbit Events',
    jobTitle: 'Partnerships Lead',
    groups: const <String>['AI ecosystem'],
    other:
        'Organizes AI meetups and can introduce founders, cloud partners, and developer advocates.',
    encounters: <Encounter>[
      Encounter(
        id: 'enc-priya-shah-1',
        occurredAt: DateTime.utc(2026, 6, 10, 18),
        placeLabel: 'San Francisco, CA',
        geo: const GeoPoint(latitude: 37.7749, longitude: -122.4194),
        note:
            'She hosted an AI meetup in San Francisco and introduced two founders '
            'and a cloud developer advocate.',
        summary: 'Hosted an AI meetup in San Francisco; founder and DevRel intros.',
        tags: const <String>['ai community', 'partnerships', 'developer relations'],
      ),
    ],
  ),
  // Headline demo contact: an ML engineer met "last month" (relative to the
  // 2026-06-21 demo clock) in San Francisco. Drives the flagship contextual
  // query 「上個月在舊金山見面、做機器學習那個工程師叫什麼？」.
  Contact(
    id: 'sample-daniel-rivera',
    createdAt: DateTime.utc(2026, 5, 18),
    name: 'Daniel Rivera',
    company: 'Loomwork AI',
    jobTitle: 'Machine Learning Engineer',
    email: 'daniel.rivera@example.com',
    groups: const <String>['AI ecosystem'],
    other:
        'Builds large-scale recommendation models and retrieval-augmented pipelines.',
    encounters: <Encounter>[
      Encounter(
        id: 'enc-daniel-rivera-1',
        occurredAt: DateTime.utc(2026, 5, 18, 19),
        placeLabel: 'San Francisco, CA',
        geo: const GeoPoint(latitude: 37.7749, longitude: -122.4194),
        note:
            'Met at a machine learning conference in San Francisco. He works on '
            'recommendation systems and RAG infrastructure.',
        summary:
            'ML conference in San Francisco; works on recommendation systems and RAG.',
        tags: const <String>[
          'machine learning',
          'recommendation systems',
          'rag',
          'conference',
        ],
        source: EncounterSource.scan,
      ),
    ],
  ),
];

