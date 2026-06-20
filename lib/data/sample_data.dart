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
  ),
];

