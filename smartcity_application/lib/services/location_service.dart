import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  static Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  static Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkPermission();
      if (!hasPermission) return null;
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      return null;
    }
  }

  /// Reverse geocode using OSM Nominatim — reliable, no API key needed
  static Future<Map<String, String>> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {'User-Agent': 'JanHelpApp/1.0'}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addr = data['address'] as Map<String, dynamic>? ?? {};

        final state = (addr['state'] ?? '').toString().trim();
        final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['district'] ?? addr['county'] ?? '').toString().trim();
        final pincode = (addr['postcode'] ?? '').toString().trim();
        final road = (addr['road'] ?? addr['suburb'] ?? '').toString().trim();
        final neighbourhood = (addr['neighbourhood'] ?? addr['suburb'] ?? '').toString().trim();
        final displayName = (data['display_name'] ?? '').toString().trim();

        // Build a clean short address
        final parts = <String>[];
        if (road.isNotEmpty) parts.add(road);
        if (neighbourhood.isNotEmpty && neighbourhood != road) parts.add(neighbourhood);
        if (city.isNotEmpty) parts.add(city);
        final shortAddress = parts.isNotEmpty ? parts.join(', ') : displayName;

        return {
          'address': shortAddress,
          'city': city,
          'state': state,
          'pincode': pincode,
          'area': neighbourhood,
          'road': road,
          'display_name': displayName,
        };
      }
    } catch (_) {}

    return {
      'address': '',
      'city': '',
      'state': '',
      'pincode': '',
      'area': '',
      'road': '',
      'display_name': '',
    };
  }
}
