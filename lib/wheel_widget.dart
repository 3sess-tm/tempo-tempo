import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'game_data.dart';

class WheelWidget extends StatefulWidget {
  const WheelWidget({required this.state, super.key});

  final AppState state;

  @override
  State<WheelWidget> createState() => _WheelWidgetState();
}

class _WheelWidgetState extends State<WheelWidget> {
  String? _draggedRing;
  double? _lastAngle;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final data = state.data;
    final colors = state.activePalette;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide;
          final textScale = size / 380;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              final point = details.localPosition;
              final center = Offset(size / 2, size / 2);
              final distance = (point - center).distance / size * 200;
              if (distance < 58 || distance > 102) return;
              _draggedRing = distance > 78 ? 'A' : 'B';
              _lastAngle = _angle(point, center);
            },
            onPanUpdate: (details) {
              final ring = _draggedRing;
              final last = _lastAngle;
              if (ring == null || last == null) return;
              final angle = _angle(
                details.localPosition,
                Offset(size / 2, size / 2),
              );
              var delta = angle - last;
              if (delta > 180) delta -= 360;
              if (delta < -180) delta += 360;
              _lastAngle = angle;
              state.rotateRing(ring, delta);
            },
            onPanEnd: (_) {
              final ring = _draggedRing;
              _draggedRing = null;
              _lastAngle = null;
              if (ring != null) state.finishRotation(ring);
            },
            onPanCancel: () {
              final ring = _draggedRing;
              _draggedRing = null;
              _lastAngle = null;
              if (ring != null) state.finishRotation(ring);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(size, size),
                  painter: WheelPainter(
                    data: data,
                    selectedVerb: state.selectedVerb,
                    selectedTense: state.selectedTense,
                    rotationA: state.outerRotation,
                    rotationB: state.innerRotation,
                    colors: colors,
                    textScale: textScale,
                  ),
                ),
                SizedBox(
                  width: size * .56,
                  height: size * .56,
                  child: _WheelCenter(state: state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _angle(Offset point, Offset center) =>
      math.atan2(point.dx - center.dx, center.dy - point.dy) * 180 / math.pi;
}

class _WheelCenter extends StatelessWidget {
  const _WheelCenter({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final data = state.data;
    final rows = data.forms
        .where(
          (form) =>
              form.verb == state.selectedVerb &&
              form.tense == state.selectedTense,
        )
        .toList();
    final noun = data.isNoun ? data.nouns[state.selectedVerb] : null;
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
      shape: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 220,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.itemLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  data.tenses[state.selectedTense],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (noun != null)
                  Text(
                    '${noun.meaning} · ${noun.gender}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                const Divider(height: 8),
                ...rows.map((form) => _FormRow(state: state, form: form)),
                const SizedBox(height: 2),
                Text(
                  rows.any((form) => state.revealed.contains(form.person))
                      ? 'Antippen zum Verdecken'
                      : 'Zeile antippen = aufdecken',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({required this.state, required this.form});

  final AppState state;
  final VerbForm form;

  @override
  Widget build(BuildContext context) {
    final revealed = state.revealed.contains(form.person);
    final color = state.rightForm == form
        ? Theme.of(context).colorScheme.tertiaryContainer
        : state.selectedPerson == form.person
        ? Theme.of(context).colorScheme.primaryContainer
        : Colors.transparent;
    return Semantics(
      button: true,
      label:
          '${state.data.persons[form.person]}, '
          '${revealed ? form.form : 'verdeckt'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => state.toggleReveal(form.person),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 43,
                child: Text(
                  state.data.persons[form.person],
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  revealed ? form.form : '••••••',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (state.rightForm == form)
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(Icons.check, size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  const WheelPainter({
    required this.data,
    required this.selectedVerb,
    required this.selectedTense,
    required this.rotationA,
    required this.rotationB,
    required this.colors,
    required this.textScale,
  });

  final GameData data;
  final int selectedVerb;
  final int selectedTense;
  final double rotationA;
  final double rotationB;
  final Map<String, String> colors;
  final double textScale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.width / 200;
    final paper = _color('paper', const Color(0xFFF6EFE1));
    final rim = _color('rim', const Color(0xFFC9B386));
    final a = _color('present', const Color(0xFFD9E4CC));
    final b = _color('perfect', const Color(0xFFEFD3C9));
    _ring(canvas, center, 78 * unit, 99 * unit, paper);
    _ring(canvas, center, 57 * unit, 78 * unit, paper);
    canvas.drawCircle(center, 99 * unit, Paint()..color = rim);
    canvas.drawCircle(center, 56.4 * unit, Paint()..color = rim);
    canvas.drawCircle(center, 55.8 * unit, Paint()..color = paper);

    final outerStep = 360 / data.tenses.length;
    for (var index = 0; index < data.tenses.length; index++) {
      final selected = _mod(index - selectedTense, data.tenses.length);
      final start = index * outerStep + rotationA - outerStep / 2;
      final fill = data.isNoun || index < 3 ? a : b;
      _sector(canvas, center, 78 * unit, 99 * unit, start, outerStep, fill);
      final angle = index * outerStep + rotationA;
      _drawLabel(
        canvas,
        center,
        data.tenses[index],
        88.5 * unit,
        angle,
        size: (data.tenses[index].length > 12 ? 7 : 8) * textScale,
        color: selected == 0
            ? _color('presentInk', const Color(0xFF3D5A35))
            : _ink,
        bold: selected == 0,
      );
    }

    final step = 360 / data.verbs.length;
    for (var index = 0; index < data.verbs.length; index++) {
      final angle = index * step + rotationB;
      final start = angle - step / 2;
      final color = index.isEven
          ? _color('ringEven', const Color(0xFFF1E4C3))
          : _color('ringOdd', const Color(0xFFECDCB5));
      _sector(canvas, center, 57 * unit, 78 * unit, start, step, color);
      final label = data.isNoun
          ? data.nouns[index].nominative
          : data.verbs[index].split(' ').first;
      final meaning = data.isNoun
          ? data.nouns[index].meaning
          : data.verbs[index].split('(').last.replaceAll(')', '');
      _drawLabel(
        canvas,
        center,
        label,
        70.0 * unit,
        angle,
        size: (label.length > 10 ? 5.4 : 7) * textScale,
        color: _color('ringText', const Color(0xFF3B2E22)),
        bold: index == selectedVerb,
      );
      _drawLabel(
        canvas,
        center,
        meaning,
        64.5 * unit,
        angle,
        size: (meaning.length > 16 ? 3.2 : 4.1) * textScale,
        color: _color('ringSub', const Color(0xFF7A6040)),
      );
    }

    final pointer = Path()
      ..moveTo(center.dx, center.dy - 56 * unit)
      ..lineTo(center.dx - 5 * unit, center.dy - 64 * unit)
      ..lineTo(center.dx + 5 * unit, center.dy - 64 * unit)
      ..close();
    canvas.drawPath(pointer, Paint()..color = _color('inner', _ink));
  }

  void _ring(
    Canvas canvas,
    Offset center,
    double inner,
    double outer,
    Color color,
  ) {
    canvas.drawCircle(center, outer, Paint()..color = color);
    canvas.drawCircle(center, inner, Paint()..color = _color('paper', color));
  }

  void _sector(
    Canvas canvas,
    Offset center,
    double inner,
    double outer,
    double startDegrees,
    double sweepDegrees,
    Color color,
  ) {
    final path = Path()
      ..arcTo(
        Rect.fromCircle(center: center, radius: outer),
        _radians(startDegrees - 90),
        _radians(sweepDegrees),
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: inner),
        _radians(startDegrees + sweepDegrees - 90),
        -_radians(sweepDegrees),
        false,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = _color('paper', const Color(0xFFF6EFE1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    String text,
    double radius,
    double angle, {
    required double size,
    required Color color,
    bool bold = false,
  }) {
    final radians = _radians(angle);
    final point = Offset(
      center.dx + radius * math.sin(radians),
      center.dy - radius * math.cos(radians),
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size.clamp(5, 14),
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: radius * .9);
    var rotation = radians + math.pi / 2;
    if (angle % 360 > 90 && angle % 360 < 270) rotation += math.pi;
    canvas
      ..save()
      ..translate(point.dx, point.dy)
      ..rotate(rotation);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  Color _color(String key, Color fallback) {
    final value = colors[key];
    if (value == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return fallback;
    }
    return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
  }

  static const _ink = Color(0xFF3B2E22);

  static int _mod(int number, int modulus) =>
      (number % modulus + modulus) % modulus;

  static double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant WheelPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.selectedVerb != selectedVerb ||
      oldDelegate.selectedTense != selectedTense ||
      oldDelegate.rotationA != rotationA ||
      oldDelegate.rotationB != rotationB ||
      oldDelegate.colors != colors;
}
