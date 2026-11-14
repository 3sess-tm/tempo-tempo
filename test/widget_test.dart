import 'package:flutter_test/flutter_test.dart';
import 'package:tempo_tempo/main.dart';

void main() {
  testWidgets('shows the Flutter migration starting point', (tester) async {
    await tester.pumpWidget(const TempoApp());

    expect(find.text('tempo, tempo'), findsOneWidget);
    expect(find.text('Flutter-Web-Grundgerüst bereit'), findsOneWidget);
    expect(find.text('Übungen und Drehscheibe'), findsOneWidget);
    expect(find.text('Rangliste'), findsOneWidget);
  });
}
