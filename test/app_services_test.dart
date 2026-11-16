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

  test(
    'leaderboard account and score sync include the wallet balance',
    () async {
      Map<String, Object?>? submitted;
      final client = LeaderboardClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            submitted = jsonDecode(request.body) as Map<String, Object?>;
            return http.Response('{"ok":true}', 200);
          }
          return http.Response(
            jsonEncode({
              'account': {
                'id': 'Account123',
                'name': 'Livia',
                'score': 1000,
                'balance': 600,
                'city_progress': 100,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final account = await client.findAccount('class-a', 'Livia');
      expect(account?.score, 1000);
      expect(account?.balance, 600);
      expect(account?.cityProgress, 100);

      await client.saveScore(
        board: 'class-a',
        id: 'Account123',
        name: 'Livia',
        score: 1000,
        balance: 600,
      );
      expect(submitted?['score'], 1000);
      expect(submitted?['balance'], 600);
    },
  );
}
