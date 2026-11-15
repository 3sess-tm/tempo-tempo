import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempo_tempo/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens the practice and identification screens', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TempoApp());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('tempo, tempo'), findsOneWidget);
    expect(find.text('Deutsch → Latein'), findsOneWidget);
    await tester.ensureVisible(find.text('Bestimmen'));
    await tester.tap(find.text('Bestimmen'));
    await tester.pump();
    expect(find.text('Form bestimmen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
