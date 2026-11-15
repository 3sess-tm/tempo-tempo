import 'package:flutter_test/flutter_test.dart';
import 'package:tempo_tempo/app_services.dart';
import 'package:tempo_tempo/app_state.dart';
import 'package:tempo_tempo/game_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'wheel dragging avoids notifying the whole app on each update',
    () async {
      final state = AppState(
        leaderboard: LeaderboardClient(),
        city: CityClient(),
      );
      addTearDown(state.dispose);
      state.catalog = await GameCatalog.load();

      var appNotifications = 0;
      var wheelNotifications = 0;
      state.addListener(() => appNotifications++);
      state.wheelChanges.addListener(() => wheelNotifications++);

      state.rotateRing('A', 1);
      expect(wheelNotifications, 1);
      expect(appNotifications, 0);

      state.finishRotation('A');
      expect(appNotifications, 1);
    },
  );
}
