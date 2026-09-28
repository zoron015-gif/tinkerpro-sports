import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

Future<LatLng?> geocodeVenueAddress(
  String address, {
  http.Client? client,
}) async {
  final query = address.trim();
  if (query.isEmpty) return null;

  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query,
    'format': 'jsonv2',
    'limit': '1',
  });
  final response = await (client == null
          ? http.get(uri, headers: const {'User-Agent': 'myapp/1.0'})
          : client.get(uri, headers: const {'User-Agent': 'myapp/1.0'}))
      .timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) {
    throw Exception(
      'Address lookup failed with status ${response.statusCode}.',
    );
  }

  final results = jsonDecode(response.body);
  if (results is! List) {
    throw const FormatException('Address lookup returned invalid results.');
  }
  if (results.isEmpty) return null;

  final first = results.first;
  if (first is! Map) {
    throw const FormatException('Address lookup returned an invalid location.');
  }
  final latitude = double.tryParse('${first['lat'] ?? ''}');
  final longitude = double.tryParse('${first['lon'] ?? ''}');
  if (latitude == null ||
      longitude == null ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    throw const FormatException('Address lookup returned invalid coordinates.');
  }
  return LatLng(latitude, longitude);
}
