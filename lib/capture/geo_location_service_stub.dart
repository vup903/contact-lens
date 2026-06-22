import 'geo_location_service.dart';

/// Web/desktop fallback: no location plugins, so report "denied" and return no
/// fix. The capture flow then proceeds without GPS (SSD C2).
GeoLocationService createPlatformGeoLocationService() =>
    const FakeGeoLocationService();
