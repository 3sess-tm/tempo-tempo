import 'package:flutter_test/flutter_test.dart';
import 'package:tempo_tempo/app_services.dart';

void main() {
  test('parses city progress, shared currency, and city unlocks', () {
    final rome = <String, int>{
      'insula-1': 400,
      'insula-2': 400,
      'insula-3': 400,
      'insula-4': 400,
      'insula-5': 0,
      'forum': 100,
      'thermae': 200,
      'colosseum': 300,
      'circus': 400,
      'pantheon': 500,
    };
    final city = CityState.fromJson({
      'currency': 55,
      'unlockedCities': ['rome', 'trier'],
      'cities': {
        'rome': {'progress': 3100, 'sites': rome, 'complete': true},
        'trier': {'progress': 0, 'sites': <String, int>{}, 'complete': false},
        'verona': {'progress': 0, 'sites': <String, int>{}, 'complete': false},
      },
    });

    expect(city.currency, 55);
    expect(city.houses('rome'), 80);
    expect(city.totalHouses, 80);
    expect(city.city('rome')?.complete, isTrue);
    expect(city.unlockedCities, ['rome', 'trier']);
  });

  test('reads existing single-city API responses as Rome', () {
    final city = CityState.fromJson({
      'progress': 40,
      'currency': 2,
      'sites': {'insula-1': 40},
    });

    expect(city.city('rome')?.progress, 40);
    expect(city.city('rome')?.sites['insula-1'], 40);
    expect(city.unlockedCities, ['rome']);
  });
}
