import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tempo_tempo/app_services.dart';

void main() {
  test('desktop leaderboard requests use the published backend URL', () async {
    Uri? requestedUri;
    final client = LeaderboardClient(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({'account': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.findAccount('class-a', 'Livia');

    expect(requestedUri?.scheme, 'https');
    expect(requestedUri?.host, 'tempo-tempo.cozmo-city.com');
    expect(requestedUri?.path, '/api/lb');
    expect(requestedUri?.queryParameters, {
      'board': 'class-a',
      'name': 'Livia',
    });
  });
}
