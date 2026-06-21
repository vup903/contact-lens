import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

import '../domain/domain.dart';
import 'geo_location_service.dart';

/// Native [GeoLocationService] backed by `geolocator` (one-shot fix) and
/// `geocoding` (best-effort reverse geocode). Every plugin call is wrapped so a
/// denied permission, disabled location services, or a timeout collapses to
/// `false` / `null` instead of throwing (SSD C2).
class MobileGeoLocationService implements GeoLocationService {
  const MobileGeoLocationService();

  @override
  Future<bool> ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<GeoReading?> currentLocation() async {
    try {
      if (!await ensurePermission()) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10));
      final point = GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
      return GeoReading(
        point: point,
        placeLabel: await _reverseGeocode(position.latitude, position.longitude),
      );
    } catch (_) {
      return null;
    }
  }

  /// Reverse geocodes to a "City, Region" label. Returns an empty string on any
  /// failure so a missing label never blocks capture.
  Future<String> _reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks =
          await geocoding.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return '';
      }
      final placemark = placemarks.first;
      final city = placemark.locality ?? '';
      final region = placemark.administrativeArea ?? '';
      return [city, region].where((part) => part.isNotEmpty).join(', ');
    } catch (_) {
      return '';
    }
  }
}

/// Factory selected by the conditional import in `geo_location_service.dart`.
GeoLocationService createPlatformGeoLocationService() =>
    const MobileGeoLocationService();
