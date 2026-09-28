import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/venue_address_geocoder.dart';

void main() {
  test('geocodes a venue address into map coordinates', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'nominatim.openstreetmap.org');
      expect(request.url.queryParameters['q'], 'Cebu City Sports Center');
      expect(request.headers['User-Agent'], 'myapp/1.0');
      return http.Response(
        jsonEncode([
          {'lat': '10.3157', 'lon': '123.8854'},
        ]),
        200,
      );
    });

    final location = await geocodeVenueAddress(
      ' Cebu City Sports Center ',
      client: client,
    );

    expect(location?.latitude, 10.3157);
    expect(location?.longitude, 123.8854);
  });

  test('empty or unmatched venue addresses have no automatic pin', () async {
    var requestCount = 0;
    final client = MockClient((_) async {
      requestCount++;
      return http.Response('[]', 200);
    });

    expect(await geocodeVenueAddress('  ', client: client), isNull);
    expect(
      await geocodeVenueAddress('No matching address', client: client),
      isNull,
    );
    expect(requestCount, 1);
  });
}
