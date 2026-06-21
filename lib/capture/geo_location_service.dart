import '../domain/domain.dart';

// Selects the platform implementation the same way `scan/ocr_adapter.dart`
// does: the stub (no plugins) everywhere except native builds, where the
// `dart.library.io` implementation pulls in `geolocator`/`geocoding`.
import 'geo_location_service_stub.dart'
    if (dart.library.io) 'geo_location_service_mobile.dart' as platform;

/// One-shot location sample, ready to fold into an [Encounter].
class GeoReading {
  const GeoReading({required this.point, this.placeLabel = ''});

  /// Latitude/longitude (plus optional accuracy) captured at exchange time.
  final GeoPoint point;

  /// Best-effort reverse-geocoded label, e.g. "San Francisco, CA". Empty when
  /// reverse geocoding is unavailable; the user can still edit it in the UI.
  final String placeLabel;
}

/// Samples the device location exactly once, at capture time, with consent.
///
/// Never tracks continuously (SSD C1). Every method degrades gracefully
/// (SSD C2): a denied permission or an unsupported platform yields
/// `false` / `null` rather than an exception, so the capture flow can proceed
/// without a location instead of crashing or blocking the UI.
abstract class GeoLocationService {
  /// Requests location permission if needed. Returns whether it is granted.
  Future<bool> ensurePermission();

  /// Returns a single location sample, or `null` when permission is denied,
  /// the platform has no location services, or sampling fails.
  Future<GeoReading?> currentLocation();
}

/// Builds the right [GeoLocationService] for the current platform: a real
/// `geolocator`-backed service on mobile, the denying fallback elsewhere.
GeoLocationService createGeoLocationService() =>
    platform.createPlatformGeoLocationService();

/// In-memory [GeoLocationService] for tests and for web/desktop builds where
/// the location plugins are absent. Defaults to "permission denied", matching
/// the C2 degradation path; tests inject a [reading] to exercise the happy path.
class FakeGeoLocationService implements GeoLocationService {
  const FakeGeoLocationService({this.permitted = false, this.reading});

  /// Whether [ensurePermission] grants access and [currentLocation] resolves.
  final bool permitted;

  /// The reading returned when [permitted]; `null` models a granted permission
  /// that still failed to produce a fix.
  final GeoReading? reading;

  @override
  Future<bool> ensurePermission() async => permitted;

  @override
  Future<GeoReading?> currentLocation() async => permitted ? reading : null;
}
