import 'package:flutter/material.dart';

import '../../domain/domain.dart';

/// Read-only timeline of a contact's [Encounter]s, newest first: each row shows
/// the time, place, structured tags, and the one-line summary (SSD §4.6 step 5).
class EncounterTimeline extends StatelessWidget {
  const EncounterTimeline({required this.encounters, super.key});

  final List<Encounter> encounters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (encounters.isEmpty) {
      return Text(
        'No encounters captured yet.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      );
    }

    final ordered = List<Encounter>.from(encounters)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final encounter in ordered) _EncounterTile(encounter: encounter),
      ],
    );
  }
}

class _EncounterTile extends StatelessWidget {
  const _EncounterTile({required this.encounter});

  final Encounter encounter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = encounter.placeLabel.trim();
    final note = encounter.displayNote;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Text(_formatDate(encounter.occurredAt),
                    style: theme.textTheme.labelLarge),
                if (place.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.place_outlined,
                      size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(place,
                        style: theme.textTheme.labelLarge,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(note),
            ],
            if (encounter.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in encounter.tags)
                    Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `yyyy-MM-dd` in UTC, matching the encounter-hash and explanation formatting.
String _formatDate(DateTime t) {
  final u = t.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}-${two(u.month)}-${two(u.day)}';
}
