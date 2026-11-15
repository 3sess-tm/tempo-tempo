import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempo_tempo/app_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempo_tempo/main.dart';
import 'package:tempo_tempo/wheel_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile wheel controls, dragging, and city layout work', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'drehscheibe-intro-tempo, tempo – fit in Formen': '1',
    });
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

    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pump();
    final narrowLayoutError = tester.takeException();
    expect(narrowLayoutError, isNull);

    final collapse = find.text('Scheibe einklappen');
    await tester.ensureVisible(collapse);
    await tester.tap(collapse);
    await tester.pumpAndSettle();
    expect(find.text('Drehscheibe eingeklappt'), findsOneWidget);

    final restore = find.text('Anzeigen');
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    final wheelFinder = find.byKey(const ValueKey('wheel-widget'));
    expect(wheelFinder, findsOneWidget);

    final snapChip = find.widgetWithText(FilterChip, 'Einrasten');
    await tester.ensureVisible(snapChip);
    await tester.tap(snapChip);
    await tester.pump();
    await tester.ensureVisible(wheelFinder);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final startOffset = scrollable.position.pixels;
    final wheel = tester.getRect(wheelFinder);
    final rotationBefore = _wheelPainter(tester).rotationA;
    await tester.dragFrom(
      Offset(wheel.center.dx + wheel.width * .42, wheel.center.dy),
      const Offset(0, 40),
    );
    await tester.pump();

    expect(_wheelPainter(tester).rotationA, isNot(rotationBefore));
    expect(scrollable.position.pixels, startOffset);

    final state = tester.widget<TempoHome>(find.byType(TempoHome)).state;
    state.activeTab = 'rome';
    state.cityState = const CityState(progress: 0, currency: 12, sites: {});
    state.notifyListeners();
    await tester.pump();

    expect(find.text('Dein Rom'), findsOneWidget);
    expect(find.text('Stadtplan'), findsOneWidget);
    expect(find.text('Vicus Tiber'), findsOneWidget);
    expect(find.text('Forum Romanum'), findsOneWidget);
    final layoutError = tester.takeException();
    expect(layoutError, isNull);
  });
}

WheelPainter _wheelPainter(WidgetTester tester) {
  final customPaints = tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byKey(const ValueKey('wheel-widget')),
      matching: find.byType(CustomPaint),
    ),
  );
  return customPaints
      .map((customPaint) => customPaint.painter)
      .whereType<WheelPainter>()
      .single;
}
