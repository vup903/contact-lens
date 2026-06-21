import 'eval_runner.dart';

/// Labeled evaluation queries over the shared [sampleContacts] corpus.
///
/// Graded gains: 3 = the contact this query is really about, 2 = a strong
/// secondary match, 1 = loosely related. Omitted ids are irrelevant (gain 0).
/// The set mixes English, Chinese, and code-switched queries and includes one
/// deliberate no-match case so the scorecard reflects realistic retrieval —
/// including where the lexical tier is weak (synonyms, cross-language intent).
///
/// Reference contact ids: `sample-alex-chen`, `sample-mia-lin`,
/// `sample-jordan-lee`, `sample-wu-kuei-hua`, `sample-priya-shah`.
const evalCases = <EvalCase>[
  EvalCase(
    query: 'vector search and on-premise data privacy review',
    note: 'EN · enterprise AI',
    relevance: <String, double>{'sample-alex-chen': 3},
  ),
  EvalCase(
    query: 'enterprise AI solutions architect',
    note: 'EN · role + domain',
    relevance: <String, double>{'sample-alex-chen': 3, 'sample-priya-shah': 1},
  ),
  EvalCase(
    query: 'seed-stage fundraising for a B2B SaaS product',
    note: 'EN · investment',
    relevance: <String, double>{'sample-mia-lin': 3},
  ),
  EvalCase(
    query: 'product designer for mobile onboarding and CRM workflows',
    note: 'EN · design',
    relevance: <String, double>{'sample-jordan-lee': 3},
  ),
  EvalCase(
    query: 'introduce me to AI founders, cloud partners and developer advocates',
    note: 'EN · partnerships',
    relevance: <String, double>{'sample-priya-shah': 3, 'sample-alex-chen': 1},
  ),
  EvalCase(
    query: 'App Store screenshots and a visual design system',
    note: 'EN · design craft',
    relevance: <String, double>{'sample-jordan-lee': 3},
  ),
  EvalCase(
    query: '中央銀行外匯局的公部門金融窗口',
    note: 'ZH · public-sector finance',
    relevance: <String, double>{'sample-wu-kuei-hua': 3, 'sample-mia-lin': 1},
  ),
  EvalCase(
    query: '幫我找做 B2B SaaS 投資的人',
    note: 'ZH/EN · investment intent',
    relevance: <String, double>{'sample-mia-lin': 3},
  ),
  EvalCase(
    query: '認識 AI 生態圈、能介紹創辦人的夥伴',
    note: 'ZH/EN · AI ecosystem intent',
    relevance: <String, double>{'sample-priya-shah': 3, 'sample-alex-chen': 1},
  ),
  // --- Hard cases: semantic intent with little/no lexical overlap. The lexical
  // tier misses or mis-ranks these; they exist to show where the semantic tier
  // earns its cost (and to keep us honest when it does not).
  EvalCase(
    query: '需要懂資料落地與企業內部署的資安顧問',
    note: 'ZH · data-residency / on-prem (→ Alex, no token overlap)',
    relevance: <String, double>{'sample-alex-chen': 3},
  ),
  EvalCase(
    query: 'who can craft a first-time signup experience for a smartphone app',
    note: 'EN paraphrase · onboarding (→ Jordan, low overlap)',
    relevance: <String, double>{'sample-jordan-lee': 3},
  ),
  EvalCase(
    query: '想找會投早期新創的創投人脈',
    note: 'ZH · early-stage VC (→ Mia, no token overlap)',
    relevance: <String, double>{'sample-mia-lin': 3},
  ),
  EvalCase(
    query: 'a well-connected person who can broker introductions to startup CEOs',
    note: 'EN synonym · connector (→ Priya, low overlap)',
    relevance: <String, double>{'sample-priya-shah': 3, 'sample-alex-chen': 1},
  ),
  EvalCase(
    query: 'find a marine biologist who studies coral reefs in Antarctica',
    note: 'EN · deliberate no-match',
    relevance: <String, double>{},
  ),
];
