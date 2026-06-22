/// A single geographic sample attached to an [Encounter]. Captured once, at
/// exchange time, with consent — never tracked continuously.
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  GeoPoint copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) {
    return GeoPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
    };
  }

  factory GeoPoint.fromJson(Map<String, Object?> json) {
    return GeoPoint(
      latitude: _parseDouble(json['latitude']) ?? 0,
      longitude: _parseDouble(json['longitude']) ?? 0,
      accuracyMeters: _parseDouble(json['accuracyMeters']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GeoPoint &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.accuracyMeters == accuracyMeters;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyMeters);
}

/// How an [Encounter] entered the system.
enum EncounterSource { scan, manual, imported }

/// One meeting with a contact. A contact can be met multiple times, so this is a
/// list element on [Contact] rather than a flat field. Immutable value object,
/// same house style as the rest of `domain/`.
class Encounter {
  const Encounter({
    required this.id,
    required this.occurredAt,
    this.geo,
    this.placeLabel = '',
    this.note = '',
    this.transcript = '',
    this.audioPath,
    this.summary = '',
    this.tags = const <String>[],
    this.source = EncounterSource.manual,
  });

  /// Stable identifier; encounters are sorted by it for deterministic hashing.
  final String id;

  /// UTC instant the exchange happened.
  final DateTime occurredAt;

  /// Where it happened; null when unavailable or location consent was denied.
  final GeoPoint? geo;

  /// Human, editable place label, e.g. "San Francisco, CA".
  final String placeLabel;

  /// Raw text the user typed.
  final String note;

  /// Speech-to-text output (may duplicate [note]).
  final String transcript;

  /// Local audio file path; mobile only, null elsewhere.
  final String? audioPath;

  /// One-line LLM/heuristic summary of the note.
  final String summary;

  /// Structured tags, lowercase and deduped.
  final List<String> tags;

  /// How this encounter was captured.
  final EncounterSource source;

  /// Best human-readable description of what was discussed: prefer the
  /// [summary], then fall back to the raw [note] or [transcript].
  String get displayNote {
    if (summary.trim().isNotEmpty) {
      return summary.trim();
    }
    if (note.trim().isNotEmpty) {
      return note.trim();
    }
    return transcript.trim();
  }

  Encounter copyWith({
    String? id,
    DateTime? occurredAt,
    GeoPoint? geo,
    String? placeLabel,
    String? note,
    String? transcript,
    String? audioPath,
    String? summary,
    List<String>? tags,
    EncounterSource? source,
  }) {
    return Encounter(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      geo: geo ?? this.geo,
      placeLabel: placeLabel ?? this.placeLabel,
      note: note ?? this.note,
      transcript: transcript ?? this.transcript,
      audioPath: audioPath ?? this.audioPath,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      source: source ?? this.source,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'occurredAt': occurredAt.toIso8601String(),
      'geo': geo?.toJson(),
      'placeLabel': placeLabel,
      'note': note,
      'transcript': transcript,
      'audioPath': audioPath,
      'summary': summary,
      'tags': tags,
      'source': source.name,
    };
  }

  factory Encounter.fromJson(Map<String, Object?> json) {
    return Encounter(
      id: (json['id'] as String?) ?? '',
      occurredAt: _parseDate(json['occurredAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      geo: (json['geo'] is Map)
          ? GeoPoint.fromJson((json['geo'] as Map).cast<String, Object?>())
          : null,
      placeLabel: (json['placeLabel'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
      transcript: (json['transcript'] as String?) ?? '',
      audioPath: json['audioPath'] as String?,
      summary: (json['summary'] as String?) ?? '',
      tags: ((json['tags'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      source: _parseSource(json['source']),
    );
  }

  /// Deterministic projection folded into the contact content hash so that
  /// changing any searchable encounter field rebuilds the RAG manifest (C5).
  /// [occurredAt] is rounded to the day and [tags] sorted for stability.
  Map<String, Object?> toIndexJson() {
    final day = occurredAt.toUtc();
    return <String, Object?>{
      'id': id,
      'occurredAt': DateTime.utc(day.year, day.month, day.day)
          .toIso8601String(),
      'geo': geo?.toJson(),
      'placeLabel': placeLabel,
      'note': note,
      'transcript': transcript,
      'summary': summary,
      'tags': List<String>.from(tags)..sort(),
    };
  }
}

/// Pre-persistence capture payload assembled by the UI before LLM enrichment.
/// Same fields as [Encounter] minus the derived [Encounter.id],
/// [Encounter.summary], and [Encounter.tags].
class EncounterDraft {
  const EncounterDraft({
    required this.occurredAt,
    this.geo,
    this.placeLabel = '',
    this.note = '',
    this.transcript = '',
    this.audioPath,
    this.source = EncounterSource.manual,
  });

  final DateTime occurredAt;
  final GeoPoint? geo;
  final String placeLabel;
  final String note;
  final String transcript;
  final String? audioPath;
  final EncounterSource source;

  EncounterDraft copyWith({
    DateTime? occurredAt,
    GeoPoint? geo,
    String? placeLabel,
    String? note,
    String? transcript,
    String? audioPath,
    EncounterSource? source,
  }) {
    return EncounterDraft(
      occurredAt: occurredAt ?? this.occurredAt,
      geo: geo ?? this.geo,
      placeLabel: placeLabel ?? this.placeLabel,
      note: note ?? this.note,
      transcript: transcript ?? this.transcript,
      audioPath: audioPath ?? this.audioPath,
      source: source ?? this.source,
    );
  }
}

EncounterSource _parseSource(Object? value) {
  if (value is String) {
    for (final source in EncounterSource.values) {
      if (source.name == value) {
        return source;
      }
    }
  }
  return EncounterSource.manual;
}

double? _parseDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String && value.trim().isNotEmpty) {
    return double.tryParse(value.trim());
  }
  return null;
}

DateTime? _parseDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
