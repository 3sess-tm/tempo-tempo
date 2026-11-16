import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'platform_storage_stub.dart'
    if (dart.library.js_interop) 'platform_storage_web.dart'
    as browser;

const _apiRequestTimeout = Duration(seconds: 15);

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
      browser.apiUri('/api/lb', queryParameters: {'board': board}),
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
      browser.apiUri(
        '/api/lb',
        queryParameters: {'board': board, 'name': name},
      ),
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
      browser.apiUri('/api/lb'),
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
          ? await _client
                .post(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(body),
                )
                .timeout(_apiRequestTimeout)
          : await _client.get(uri).timeout(_apiRequestTimeout);
    } on http.ClientException catch (error) {
      throw ApiException(
        'Die Rangliste ist nicht erreichbar: ${error.message}',
      );
    } on TimeoutException {
      throw const ApiException(
        'Die Rangliste antwortet nicht. Bitte später erneut versuchen.',
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
    required this.currency,
    required this.cities,
    required this.unlockedCities,
  });

  final int currency;
  final Map<String, CityProgress> cities;
  final List<String> unlockedCities;

  CityProgress? city(String id) => cities[id];

  int houses(String id) {
    final progress = city(id);
    final definition = CityClient.definitions[id];
    if (progress == null || definition == null) return 0;
    return definition.housingSites.fold<int>(
      0,
      (sum, site) => sum + ((progress.sites[site] ?? 0) ~/ 20),
    );
  }

  int get totalHouses =>
      cities.keys.fold(0, (total, cityId) => total + houses(cityId));

  factory CityState.fromJson(Map<String, dynamic> json) {
    if (json['currency'] is! int || json['currency'] < 0) {
      throw const ApiException('Ungültige Stadtdaten.');
    }
    final rawCities = json['cities'];
    final cities = <String, CityProgress>{};
    if (rawCities is Map<String, dynamic>) {
      for (final entry in rawCities.entries) {
        if (!CityClient.definitions.containsKey(entry.key) ||
            entry.value is! Map<String, dynamic>) {
          throw const ApiException('Ungültiger Stadtstand.');
        }
        cities[entry.key] = CityProgress.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    } else {
      final legacySites = json['sites'];
      if (legacySites is! Map<String, dynamic>) {
        throw const ApiException('Ungültige Stadtdaten.');
      }
      cities['rome'] = CityProgress.fromJson({
        'sites': legacySites,
        'progress': json['progress'] ?? 0,
        'complete': false,
      });
    }
    if (!cities.containsKey('rome')) {
      throw const ApiException('Der römische Stadtstand fehlt.');
    }
    final rawUnlocked = json['unlockedCities'];
    final unlocked = rawUnlocked is List
        ? rawUnlocked.whereType<String>().toList()
        : <String>['rome'];
    if (unlocked.isEmpty ||
        unlocked.first != 'rome' ||
        unlocked.length > CityClient.cityOrder.length ||
        unlocked.asMap().entries.any(
          (entry) => entry.value != CityClient.cityOrder[entry.key],
        )) {
      throw const ApiException('Ungültiger Freischaltstand der Städte.');
    }
    return CityState(
      currency: json['currency'] as int,
      cities: cities,
      unlockedCities: unlocked,
    );
  }
}

class CityProgress {
  const CityProgress({
    required this.progress,
    required this.sites,
    required this.complete,
  });

  final int progress;
  final Map<String, int> sites;
  final bool complete;

  factory CityProgress.fromJson(Map<String, dynamic> json) {
    if (json['progress'] is! int ||
        json['progress'] < 0 ||
        json['sites'] is! Map<String, dynamic> ||
        json['complete'] is! bool) {
      throw const ApiException('Ungültiger Baufortschritt.');
    }
    final sites = <String, int>{};
    for (final entry in (json['sites'] as Map<String, dynamic>).entries) {
      if (entry.value is! int || (entry.value as int) < 0) {
        throw const ApiException('Ungültiger Baufortschritt.');
      }
      sites[entry.key] = entry.value as int;
    }
    return CityProgress(
      progress: json['progress'] as int,
      sites: sites,
      complete: json['complete'] as bool,
    );
  }
}

class CityDefinition {
  const CityDefinition({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.latinName,
    required this.housingSites,
    required this.housingNames,
    required this.buildings,
  });

  final String id;
  final String name;
  final String subtitle;
  final String latinName;
  final List<String> housingSites;
  final Map<String, String> housingNames;
  final Map<String, CityBuilding> buildings;
}

class CityBuilding {
  const CityBuilding({
    required this.name,
    required this.houses,
    required this.materials,
  });

  final String name;
  final int houses;
  final int materials;
}

class CityClient {
  CityClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const cityOrder = ['rome', 'trier', 'verona'];
  static const definitions = {
    'rome': CityDefinition(
      id: 'rome',
      name: 'Rom',
      subtitle: 'Die Ewige Stadt',
      latinName: 'Roma Aeterna',
      housingSites: [
        'insula-1',
        'insula-2',
        'insula-3',
        'insula-4',
        'insula-5',
      ],
      housingNames: {
        'insula-1': 'Vicus Tiber',
        'insula-2': 'Subura',
        'insula-3': 'Esquilin',
        'insula-4': 'Aventin',
        'insula-5': 'Palatin',
      },
      buildings: {
        'forum': CityBuilding(name: 'Forum Romanum', houses: 5, materials: 100),
        'thermae': CityBuilding(name: 'Thermen', houses: 15, materials: 200),
        'colosseum': CityBuilding(
          name: 'Kolosseum',
          houses: 30,
          materials: 300,
        ),
        'circus': CityBuilding(
          name: 'Circus Maximus',
          houses: 50,
          materials: 400,
        ),
        'pantheon': CityBuilding(name: 'Pantheon', houses: 80, materials: 500),
      },
    ),
    'trier': CityDefinition(
      id: 'trier',
      name: 'Trier',
      subtitle: 'Augusta Treverorum',
      latinName: 'Augusta Treverorum',
      housingSites: ['vicus-1', 'vicus-2', 'vicus-3', 'vicus-4', 'vicus-5'],
      housingNames: {
        'vicus-1': 'Moselviertel',
        'vicus-2': 'Altbachtal',
        'vicus-3': 'Petrisberg',
        'vicus-4': 'Marktviertel',
        'vicus-5': 'Barbarathermen',
      },
      buildings: {
        'porta-nigra': CityBuilding(
          name: 'Porta Nigra',
          houses: 5,
          materials: 100,
        ),
        'thermae-trier': CityBuilding(
          name: 'Kaiserthermen',
          houses: 15,
          materials: 200,
        ),
        'amphitheater': CityBuilding(
          name: 'Amphitheater',
          houses: 30,
          materials: 300,
        ),
        'basilica': CityBuilding(
          name: 'Konstantinbasilika',
          houses: 50,
          materials: 400,
        ),
        'roemerbruecke': CityBuilding(
          name: 'Römerbrücke',
          houses: 80,
          materials: 500,
        ),
      },
    ),
    'verona': CityDefinition(
      id: 'verona',
      name: 'Verona',
      subtitle: 'Die Stadt an der Etsch',
      latinName: 'Verona Augusta',
      housingSites: ['borgo-1', 'borgo-2', 'borgo-3', 'borgo-4', 'borgo-5'],
      housingNames: {
        'borgo-1': 'Borgo Trento',
        'borgo-2': 'San Zeno',
        'borgo-3': 'Ponte Pietra',
        'borgo-4': 'Veronetta',
        'borgo-5': 'Porta Borsari',
      },
      buildings: {
        'arena': CityBuilding(
          name: 'Arena di Verona',
          houses: 5,
          materials: 100,
        ),
        'porta-borsari': CityBuilding(
          name: 'Porta Borsari',
          houses: 15,
          materials: 200,
        ),
        'teatro-romano': CityBuilding(
          name: 'Teatro Romano',
          houses: 30,
          materials: 300,
        ),
        'ponte-pietra': CityBuilding(
          name: 'Ponte Pietra',
          houses: 50,
          materials: 400,
        ),
        'arco-gavi': CityBuilding(
          name: 'Arco dei Gavi',
          houses: 80,
          materials: 500,
        ),
      },
    ),
  };

  Future<CityState> load(String board, String id) async {
    final data = await _request(
      browser.apiUri('/api/city', queryParameters: {'board': board, 'id': id}),
    );
    return CityState.fromJson(data);
  }

  Future<CityState> invest({
    required String board,
    required String id,
    required String city,
    required String site,
    required int materials,
  }) async {
    final data = await _request(
      browser.apiUri('/api/city', queryParameters: {'board': board, 'id': id}),
      method: 'POST',
      body: {
        'action': 'invest',
        'city': city,
        'site': site,
        'materials': materials,
      },
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
          ? await _client
                .post(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(body),
                )
                .timeout(_apiRequestTimeout)
          : await _client.get(uri).timeout(_apiRequestTimeout);
    } on http.ClientException catch (error) {
      throw ApiException('Die Stadt ist nicht erreichbar: ${error.message}');
    } on TimeoutException {
      throw const ApiException(
        'Die Stadt antwortet nicht. Bitte später erneut versuchen.',
      );
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
    'city' => 'Diese Stadt ist unbekannt.',
    'city_locked' => 'Diese Stadt ist noch nicht freigeschaltet.',
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
