import 'dart:math' as math;

import '../domain/domain.dart';
import '../llm/llm_adapter.dart';
import 'tokenizer.dart';

/// An inclusive UTC time window. A `null` bound is open on that side, so
/// `TimeRange(start: x)` means "x or later" and an all-`null` range matches
/// everything ([isOpen]). All comparisons are done in UTC so callers can pass
/// either local or UTC instants safely (C5 — deterministic, injectable time).
class TimeRange {
  const TimeRange({this.start, this.end});

  /// Inclusive lower bound; `null` = open (no lower bound).
  final DateTime? start;

  /// Inclusive upper bound; `null` = open (no upper bound).
  final DateTime? end;

  /// Whether [t] falls within the (inclusive) window.
  bool contains(DateTime t) {
    final at = t.toUtc();
    if (start != null && at.isBefore(start!.toUtc())) {
      return false;
    }
    if (end != null && at.isAfter(end!.toUtc())) {
      return false;
    }
    return true;
  }

  /// True when both bounds are open — the range constrains nothing.
  bool get isOpen => start == null && end == null;

  @override
  String toString() => 'TimeRange(start: $start, end: $end)';
}

/// A place constraint. An encounter matches when its [Encounter.placeLabel]
/// contains [placeText] (case-insensitive substring) **or** its
/// [Encounter.geo] falls within [radiusKm] of [center]. Either criterion alone
/// is enough — the heuristic parser usually supplies only [placeText], while a
/// GPS-aware query can add a [center]/[radiusKm] proximity test.
class GeoFilter {
  const GeoFilter({this.placeText = '', this.center, this.radiusKm});

  /// Human place text, e.g. "san francisco"; matched as a substring.
  final String placeText;

  /// Optional coordinate for a proximity test.
  final GeoPoint? center;

  /// Optional radius (km) paired with [center].
  final double? radiusKm;

  bool get _hasPlaceText => placeText.trim().isNotEmpty;
  bool get _hasProximity => center != null && radiusKm != null;

  /// Whether this filter expresses any constraint at all.
  bool get isEmpty => !_hasPlaceText && !_hasProximity;

  /// True when [e] satisfies the place constraint (substring OR proximity).
  bool matchesEncounter(Encounter e) {
    if (isEmpty) {
      return true;
    }
    if (_hasPlaceText) {
      final label = normalizeSearchText(e.placeLabel);
      final needle = normalizeSearchText(placeText);
      if (needle.isNotEmpty && label.contains(needle)) {
        return true;
      }
    }
    if (_hasProximity && e.geo != null) {
      if (_haversineKm(center!, e.geo!) <= radiusKm!) {
        return true;
      }
    }
    return false;
  }

  @override
  String toString() =>
      'GeoFilter(placeText: "$placeText", center: $center, radiusKm: $radiusKm)';
}

/// A natural-language search resolved into a meaning component plus optional
/// time/place metadata constraints. Built from a [ParsedQuery] via
/// [ContextualQuery.fromParsedQuery] and consumed by `ContextualRetriever`.
class ContextualQuery {
  const ContextualQuery({
    required this.semanticText,
    this.timeRange,
    this.geo,
    this.rawQuery = '',
  });

  /// Residual meaning to rank by, e.g. "machine learning engineer".
  final String semanticText;

  /// Optional time constraint over [Encounter.occurredAt].
  final TimeRange? timeRange;

  /// Optional place constraint over [Encounter.placeLabel]/[Encounter.geo].
  final GeoFilter? geo;

  /// The original question, kept for display/debugging.
  final String rawQuery;

  /// True when there is at least one metadata constraint to filter on. A
  /// closed-but-open [timeRange] or empty [geo] is treated as no constraint.
  bool get hasConstraints =>
      (timeRange != null && !timeRange!.isOpen) ||
      (geo != null && !geo!.isEmpty);

  /// Maps the LLM/heuristic [ParsedQuery] into a [ContextualQuery]: time bounds
  /// become a [TimeRange], any place text becomes a [GeoFilter], and the
  /// residual meaning is carried through verbatim (C3 — pure Dart, no IO).
  factory ContextualQuery.fromParsedQuery(
    ParsedQuery parsed, {
    String rawQuery = '',
  }) {
    final hasTime = parsed.startUtc != null || parsed.endUtc != null;
    final timeRange =
        hasTime ? TimeRange(start: parsed.startUtc, end: parsed.endUtc) : null;

    final place = parsed.locationText.trim();
    final geo = place.isEmpty ? null : GeoFilter(placeText: place);

    return ContextualQuery(
      semanticText: parsed.semanticText,
      timeRange: timeRange,
      geo: geo,
      rawQuery: rawQuery,
    );
  }

  @override
  String toString() => 'ContextualQuery(semanticText: "$semanticText", '
      'timeRange: $timeRange, geo: $geo)';
}

/// Great-circle distance between two points, in kilometers.
double _haversineKm(GeoPoint a, GeoPoint b) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRadians(b.latitude - a.latitude);
  final dLon = _toRadians(b.longitude - a.longitude);
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
}

double _toRadians(double degrees) => degrees * math.pi / 180.0;
