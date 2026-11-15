import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'platform_storage_stub.dart'
    if (dart.library.js_interop) 'platform_storage_web.dart'
    as browser;

class LocalStore {
  LocalStore(this._preferences);

  final SharedPreferences _preferences;

  static const legacyKeys = [
    'drehscheibe-asse',
    'drehscheibe-verdient',
    'drehscheibe-ton',
    'drehscheibe-vorlesen',
    'drehscheibe-klang',
    'drehscheibe-stimmname',
    'drehscheibe-rangliste',
    'drehscheibe-meineverben',
    'drehscheibe-stats',
    'drehscheibe-tempora',
    'drehscheibe-kasus',
    'tempo-shop-stand-v1',
    'drehscheibe-intro-tempo, tempo – fit in Formen',
  ];

  static Future<LocalStore> load() async {
    final preferences = await SharedPreferences.getInstance();
    final store = LocalStore(preferences);
    for (final key in legacyKeys) {
      if (preferences.containsKey(key)) continue;
      try {
        final value = browser.readLegacyValue(key);
        if (value != null) await preferences.setString(key, value);
      } on Object {
        // Browser storage can be disabled; the app can still use defaults.
      }
    }
    return store;
  }

  String? read(String key) => _preferences.getString(key);

  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
    try {
      browser.writeLegacyValue(key, value);
    } on Object {
      // Preferences remain the authoritative fallback when browser storage is unavailable.
    }
  }

  Future<void> remove(String key) async {
    await _preferences.remove(key);
    try {
      browser.removeLegacyValue(key);
    } on Object {
      // Removing the platform-specific copy must not hide a successful preference update.
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LeaderboardEntry {
  const LeaderboardEntry(this.name, this.score);

  final String name;
  final int score;
}

class LeaderboardAccount {
  const LeaderboardAccount(this.id, this.name, this.score);

  final String id;
  final String name;
  final int score;
}

class LeaderboardClient {
  LeaderboardClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<LeaderboardEntry>> load(String board) async {
    final data = await _request(
      Uri(path: '/api/lb', queryParameters: {'board': board}),
    );
    final rows = data['rows'];
    if (rows is! List) {
      throw const ApiException('Ungültige Ranglisten-Antwort.');
    }
    return rows.map((row) {
      if (row is! Map<String, dynamic> ||
          row['name'] is! String ||
          row['score'] is! int) {
        throw const ApiException('Ungültiger Ranglisteneintrag.');
      }
      return LeaderboardEntry(row['name'] as String, row['score'] as int);
    }).toList();
  }

  Future<LeaderboardAccount?> findAccount(String board, String name) async {
    final data = await _request(
      Uri(path: '/api/lb', queryParameters: {'board': board, 'name': name}),
    );
    final account = data['account'];
    if (account == null) return null;
    if (account is! Map<String, dynamic> ||
        account['id'] is! String ||
        account['name'] is! String ||
        account['score'] is! int) {
      throw const ApiException('Ungültige Kontodaten.');
    }
    return LeaderboardAccount(
      account['id'] as String,
      account['name'] as String,
      account['score'] as int,
    );
  }

  Future<void> saveScore({
    required String board,
    required String id,
    required String name,
    required int score,
  }) async {
    await _request(
      Uri(path: '/api/lb'),
      method: 'POST',
      body: {'board': board, 'id': id, 'name': name, 'score': score},
    );
  }

  Future<Map<String, Object?>> _request(
    Uri uri, {
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    final http.Response response;
    try {
      response = method == 'POST'
          ? await _client.post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
          : await _client.get(uri);
    } on http.ClientException catch (error) {
      throw ApiException(
        'Die Rangliste ist nicht erreichbar: ${error.message}',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ApiException(
        'Der Server hat keine gültige JSON-Antwort gesendet.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const ApiException(
        'Der Server hat eine ungültige Antwort gesendet.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_leaderboardError(decoded['error']));
    }
    return decoded;
  }

  String _leaderboardError(Object? error) => switch (error) {
    'board' => 'Der Klassencode ist ungültig.',
    'name' => 'Der Spitzname ist ungültig.',
    'invalid' => 'Die Kontodaten sind ungültig.',
    _ => 'Die Rangliste ist gerade nicht erreichbar.',
  };
}

class CityState {
  const CityState({
    required this.progress,
    required this.currency,
    required this.sites,
  });

  final int progress;
  final int currency;
  final Map<String, int> sites;

  factory CityState.fromJson(Map<String, dynamic> json) {
    if (json['progress'] is! int ||
        json['currency'] is! int ||
        json['sites'] is! Map<String, dynamic>) {
      throw const ApiException('Ungültige Stadtdaten.');
    }
    final sites = <String, int>{};
    for (final entry in (json['sites'] as Map<String, dynamic>).entries) {
      if (entry.value is! int || (entry.value as int) < 0) {
        throw const ApiException('Ungültiger Baufortschritt.');
      }
      sites[entry.key] = entry.value as int;
    }
    return CityState(
      progress: json['progress'] as int,
      currency: json['currency'] as int,
      sites: sites,
    );
  }
}

class CityClient {
  CityClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const housingSites = [
    'insula-1',
    'insula-2',
    'insula-3',
    'insula-4',
    'insula-5',
  ];
  static const buildings = {
    'forum': (name: 'Forum Romanum', houses: 5, materials: 100),
    'thermae': (name: 'Thermen', houses: 15, materials: 200),
    'colosseum': (name: 'Kolosseum', houses: 30, materials: 300),
    'circus': (name: 'Circus Maximus', houses: 50, materials: 400),
    'pantheon': (name: 'Pantheon', houses: 80, materials: 500),
  };
  static const housingNames = {
    'insula-1': 'Vicus Tiber',
    'insula-2': 'Subura',
    'insula-3': 'Esquilin',
    'insula-4': 'Aventin',
    'insula-5': 'Palatin',
  };

  Future<CityState> load(String board, String id) async {
    final data = await _request(
      Uri(path: '/api/city', queryParameters: {'board': board, 'id': id}),
    );
    return CityState.fromJson(data);
  }

  Future<CityState> invest({
    required String board,
    required String id,
    required String site,
    required int materials,
  }) async {
    final data = await _request(
      Uri(path: '/api/city', queryParameters: {'board': board, 'id': id}),
      method: 'POST',
      body: {'action': 'invest', 'site': site, 'materials': materials},
    );
    return CityState.fromJson(data);
  }

  Future<Map<String, dynamic>> _request(
    Uri uri, {
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    final http.Response response;
    try {
      response = method == 'POST'
          ? await _client.post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
          : await _client.get(uri);
    } on http.ClientException catch (error) {
      throw ApiException('Die Stadt ist nicht erreichbar: ${error.message}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ApiException(
        'Die Stadt-API hat eine ungültige Antwort gesendet.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        'Die Stadt-API hat eine ungültige Antwort gesendet.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_cityError(decoded['error']));
    }
    return decoded;
  }

  String _cityError(Object? error) => switch (error) {
    'account' => 'Das Konto wurde nicht gefunden.',
    'locked' => 'Dieser Bauplatz ist noch gesperrt.',
    'gloria' => 'Für dieses besondere Gebäude benötigst du 5 Gloria.',
    'balance' =>
      'Dein Ranglistenstand ist noch nicht aktuell. Bitte warte kurz.',
    'investment' => 'Die Materialmenge ist ungültig.',
    'conflict' => 'Der Kontostand wurde gerade geändert. Bitte erneut laden.',
    _ => 'Der Stadtstand konnte nicht gespeichert werden.',
  };
}

String createAccountId() {
  final random = Random.secure();
  return List.generate(
    12,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
