import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_services.dart';
import 'app_state.dart';
import 'browser_navigation_stub.dart'
    if (dart.library.js_interop) 'browser_navigation_web.dart'
    as browser;
import 'game_data.dart';
import 'verb_builder.dart';
import 'wheel_widget.dart';

void main() {
  runApp(const TempoApp());
}

class TempoApp extends StatefulWidget {
  const TempoApp({super.key});

  @override
  State<TempoApp> createState() => _TempoAppState();
}

class _TempoAppState extends State<TempoApp> with WidgetsBindingObserver {
  late final AppState _state = AppState(
    leaderboard: LeaderboardClient(),
    city: CityClient(),
  );
  StreamSubscription<String>? _routeSubscription;
  StreamSubscription<bool>? _visibilitySubscription;
  Timer? _taxTimer;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routeSubscription = browser.routeChanges.listen((route) {
      if (route.isNotEmpty) _state.updateTab(route);
    });
    final initialRoute = browser.currentRoute();
    if (initialRoute.isNotEmpty) _state.updateTab(initialRoute);
    _isVisible = browser.isDocumentVisible;
    _visibilitySubscription = browser.visibilityChanges.listen((visible) {
      _isVisible = visible;
      _state.tickCity(visible);
    });
    _taxTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _state.tickCity(_isVisible && browser.isDocumentVisible),
    );
    unawaited(_state.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isVisible = state == AppLifecycleState.resumed;
    _state.tickCity(_isVisible && browser.isDocumentVisible);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeSubscription?.cancel();
    _visibilitySubscription?.cancel();
    _taxTimer?.cancel();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'tempo, tempo – fit in Formen',
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: ThemeMode.system,
    home: AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        if (!_state.initialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_state.loadError != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_state.loadError!),
              ),
            ),
          );
        }
        return TempoHome(state: _state);
      },
    ),
  );

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9E3F2E),
      brightness: brightness,
      surface: brightness == Brightness.light
          ? const Color(0xFFF6EFE1)
          : const Color(0xFF211D19),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFEFE6D3)
          : const Color(0xFF211D19),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.primary,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

class TempoHome extends StatefulWidget {
  const TempoHome({required this.state, super.key});

  final AppState state;

  @override
  State<TempoHome> createState() => _TempoHomeState();
}

class _TempoHomeState extends State<TempoHome> {
  bool _wheelCollapsed = false;
  bool _introScheduled = false;

  static const _routes = [
    ('practice', 'Üben', Icons.edit_note),
    ('identify', 'Bestimmen', Icons.manage_search),
    ('my-verbs', 'Meine Verben', Icons.add_circle_outline),
    ('shop', 'Shop', Icons.storefront),
    ('rome', 'Rom', Icons.account_balance),
    ('leaderboard', 'Rangliste', Icons.leaderboard),
    ('help', 'Hilfe', Icons.help_outline),
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.state.introSeen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_introScheduled) {
          _introScheduled = true;
          _showIntroductionAgain(markSeen: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'tempo, tempo',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
        actions: [
          if (compact)
            PopupMenuButton<String>(
              tooltip: 'Menü',
              onSelected: (action) async {
                if (action == 'sound') {
                  state.setSound(!state.soundEnabled);
                } else if (action == 'intro') {
                  await _showIntroductionAgain();
                } else if (action == 'fullscreen') {
                  await browser.toggleFullscreen();
                } else {
                  browser.printPage();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'sound', child: Text('Ton umschalten')),
                PopupMenuItem(value: 'intro', child: Text('Einführung')),
                PopupMenuItem(value: 'fullscreen', child: Text('Vollbild')),
                PopupMenuItem(value: 'print', child: Text('Drucken')),
              ],
            )
          else ...[
            IconButton(
              tooltip: state.soundEnabled
                  ? 'Ton ausschalten'
                  : 'Ton einschalten',
              onPressed: () => state.setSound(!state.soundEnabled),
              icon: Icon(
                state.soundEnabled ? Icons.volume_up : Icons.volume_off,
              ),
            ),
            IconButton(
              tooltip: 'Einführung anzeigen',
              onPressed: _showIntroductionAgain,
              icon: const Icon(Icons.menu_book_outlined),
            ),
            IconButton(
              tooltip: 'Vollbild umschalten',
              onPressed: () async {
                await browser.toggleFullscreen();
              },
              icon: const Icon(Icons.fullscreen),
            ),
            IconButton(
              tooltip: 'Drucken',
              onPressed: browser.printPage,
              icon: const Icon(Icons.print_outlined),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1050;
                final wheel = _wheelSection();
                final content = _contentSection();
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 480, child: wheel),
                            const SizedBox(width: 18),
                            Expanded(child: content),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [wheel, content],
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _wheelSection() {
    final state = widget.state;
    final size = MediaQuery.sizeOf(context).width.clamp(280, 480).toDouble();
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (_wheelCollapsed)
                  Row(
                    children: [
                      Icon(
                        Icons.toys_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Drehscheibe eingeklappt')),
                      FilledButton.tonalIcon(
                        onPressed: () => setState(() {
                          _wheelCollapsed = false;
                        }),
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Anzeigen'),
                      ),
                    ],
                  )
                else ...[
                  AnimatedBuilder(
                    animation: state.wheelChanges,
                    builder: (context, _) => Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          state.itemLabel,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '· ${state.data.tenses[state.selectedTense]}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: size),
                    child: WheelWidget(
                      key: const ValueKey('wheel-widget'),
                      state: state,
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        selected: state.snapEnabled,
                        label: const Text('Einrasten'),
                        onSelected: (value) => setState(() {
                          state.snapEnabled = value;
                        }),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _wheelCollapsed = true;
                        }),
                        icon: const Icon(Icons.expand_less),
                        label: const Text('Scheibe einklappen'),
                      ),
                    ],
                  ),
                  Text(
                    'Mittlerer Ring: Wort · äußerer Ring: Tempus oder Kasus',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _contentSection() {
    final state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WalletCard(state: state),
        const SizedBox(height: 12),
        _navigation(),
        const SizedBox(height: 12),
        if (state.notice != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(state.notice!),
              trailing: IconButton(
                tooltip: 'Schließen',
                onPressed: () => setState(() => state.notice = null),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        _activePanel(),
      ],
    );
  }

  Widget _navigation() {
    final state = widget.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _routes.map((route) {
              final active = state.activeTab == route.$1;
              if (route.$1 == 'my-verbs' && state.isNounMode) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  selected: active,
                  avatar: Icon(route.$3, size: 18),
                  label: Text(route.$2),
                  onSelected: (_) {
                    if (route.$1 == 'my-verbs') {
                      unawaited(state.activateWheel('my-verbs'));
                    }
                    state.updateTab(route.$1);
                    browser.pushRoute(route.$1);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _activePanel() {
    final state = widget.state;
    return switch (state.activeTab) {
      'identify' => _IdentifyPanel(state: state),
      'my-verbs' => _CustomVerbsPanel(state: state),
      'shop' => _ShopPanel(state: state),
      'rome' => _RomePanel(state: state),
      'leaderboard' => _LeaderboardPanel(state: state),
      'help' => _HelpPanel(state: state),
      _ => _PracticePanel(state: state),
    };
  }

  Future<void> _showIntroductionAgain({bool markSeen = false}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Willkommen bei tempo, tempo'),
        content: const Text(
          'Drehe den mittleren Ring für das Wort und den äußeren Ring für '
          'Tempus oder Kasus. Formen lassen sich eintippen oder auf der '
          'Scheibe aufdecken. Im Shop findest du weitere Räder und Skins; '
          'in Rom baust du mit erspielten Assen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
    if (markSeen) await widget.state.markIntroSeen();
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    var remainder = state.purse;
    final aurei = remainder ~/ 1600;
    remainder %= 1600;
    final denarii = remainder ~/ 16;
    remainder %= 16;
    final sestertii = remainder ~/ 4;
    final asses = remainder % 4;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Münzkasse',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${state.purse} ${state.purse == 1 ? 'As' : 'Asse'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _CoinCount(
                  symbol: 'I',
                  color: const Color(0xFFD5A943),
                  count: aurei,
                  label: 'Aurei',
                ),
                _CoinCount(
                  symbol: 'XVI',
                  color: const Color(0xFFA8B0B5),
                  count: denarii,
                  label: 'Denare',
                ),
                _CoinCount(
                  symbol: 'IV',
                  color: const Color(0xFFB87343),
                  count: sestertii,
                  label: 'Sesterzen',
                ),
                _CoinCount(
                  symbol: 'I',
                  color: const Color(0xFF80614D),
                  count: asses,
                  label: 'Asse',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Gesamtwert: ${state.purse} ${state.purse == 1 ? 'As' : 'Asse'} · '
              'verdient: ${state.earned}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: state.purse == 0
                    ? null
                    : () => _confirmEmpty(context),
                child: const Text('Kasse leeren'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEmpty(BuildContext context) async {
    final empty = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kasse leeren?'),
        content: const Text('Deine verfügbaren Asse werden auf 0 gesetzt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leeren'),
          ),
        ],
      ),
    );
    if (empty == true) await state.emptyPurse();
  }
}

class _CoinCount extends StatelessWidget {
  const _CoinCount({
    required this.symbol,
    required this.color,
    required this.count,
    required this.label,
  });

  final String symbol;
  final Color color;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: .5), color],
          ),
          border: Border.all(color: color.withValues(alpha: .8), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          symbol,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: symbol.length > 2 ? 8 : 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 7),
      Text('$count $label'),
    ],
  );
}

class _PracticePanel extends StatefulWidget {
  const _PracticePanel({required this.state});

  final AppState state;

  @override
  State<_PracticePanel> createState() => _PracticePanelState();
}

class _PracticePanelState extends State<_PracticePanel> {
  final TextEditingController _answer = TextEditingController();

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final data = state.data;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModePicker(state: state),
            const SizedBox(height: 12),
            _TenseFilter(state: state),
            const SizedBox(height: 14),
            Text(
              'Deutsch → Latein',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              state.practiceForm == null
                  ? 'Aufgabe wird geladen …'
                  : data.isNoun
                  ? '${state.practiceForm!.german} — '
                        '${data.tenses[state.practiceForm!.tense]}, '
                        '${data.persons[state.practiceForm!.person]}'
                  : state.practiceForm!.german,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _answer,
              enabled: !state.practiceDone,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'Lateinische Form',
                hintText: 'z. B. rogābāmus',
              ),
              onChanged: state.setInput,
              onSubmitted: (_) => state.submitPractice(),
            ),
            const SizedBox(height: 6),
            _MacronButtons(onInsert: _insertMacron),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton(
                  onPressed: state.practiceDone ? null : state.submitPractice,
                  child: const Text('Prüfen'),
                ),
                OutlinedButton(
                  onPressed: () {
                    _answer.clear();
                    state.newPractice();
                  },
                  child: const Text('Neue Aufgabe'),
                ),
                OutlinedButton(
                  onPressed: state.practiceDone
                      ? null
                      : state.showPracticeSolution,
                  child: const Text('Lösung zeigen'),
                ),
              ],
            ),
            if (state.practiceMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MessageBox(text: state.practiceMessage),
            ],
            const SizedBox(height: 10),
            _TrainingStats(state: state),
          ],
        ),
      ),
    );
  }

  void _insertMacron(String value) {
    final selection = _answer.selection;
    final start = selection.isValid ? selection.start : _answer.text.length;
    final end = selection.isValid ? selection.end : start;
    final text = _answer.text.replaceRange(start, end, value);
    _answer.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    widget.state.setInput(text);
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      ChoiceChip(
        selected: !state.isNounMode,
        label: const Text('Verben'),
        onSelected: (_) => state.setMode(false),
      ),
      ChoiceChip(
        selected: state.isNounMode,
        label: const Text('Substantive'),
        onSelected: (_) => state.setMode(true),
      ),
    ],
  );
}

class _MacronButtons extends StatelessWidget {
  const _MacronButtons({required this.onInsert});

  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    children: ['ā', 'ē', 'ī', 'ō', 'ū'].map((letter) {
      return TextButton(onPressed: () => onInsert(letter), child: Text(letter));
    }).toList(),
  );
}

class _TenseFilter extends StatelessWidget {
  const _TenseFilter({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 3,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Text('Üben:'),
      ...List.generate(state.data.tenses.length, (index) {
        return FilterChip(
          selected: state.selectedTenses.contains(index),
          label: Text(state.data.tenses[index]),
          onSelected: (_) => state.toggleTense(index),
        );
      }),
      if (state.selectedTenses.isEmpty)
        const Text('alle', style: TextStyle(fontSize: 12)),
    ],
  );
}

class _TrainingStats extends StatelessWidget {
  const _TrainingStats({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          Text('🔥 Serie ${state.streak} (Rekord ${state.bestStreak})'),
          Text(
            '🎯 Tagesziel ${math.min(state.dailyCount, 10)}/10'
            '${state.dailyGoalReached ? ' ✓' : ''}',
          ),
          Text('${state.correctCount} von ${state.attemptCount} richtig'),
          if (state.weakForms.isNotEmpty)
            Text('🧩 ${state.weakForms.length} Wackelformen'),
        ],
      ),
      const SizedBox(height: 5),
      LinearProgressIndicator(
        value: math.min(state.dailyCount / 10, 1),
        minHeight: 5,
      ),
    ],
  );
}

class _IdentifyPanel extends StatelessWidget {
  const _IdentifyPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final form = state.identificationForm;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModePicker(state: state),
            const SizedBox(height: 12),
            _TenseFilter(state: state),
            const SizedBox(height: 16),
            Text(
              'Form bestimmen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              form?.form ?? '–',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: 'serif',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.isNounMode
                  ? 'Stelle Substantiv und Kasus ein; wähle Singular oder Plural in der passenden Zeile.'
                  : 'Stelle Verb und Tempus auf der Scheibe ein und prüfe.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: state.checkIdentification,
                  child: const Text('Prüfen'),
                ),
                OutlinedButton(
                  onPressed: state.newIdentification,
                  child: const Text('Neue Form'),
                ),
                OutlinedButton(
                  onPressed: state.identificationDone
                      ? null
                      : state.showIdentificationSolution,
                  child: const Text('Lösung'),
                ),
              ],
            ),
            if (state.identifyMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MessageBox(text: state.identifyMessage),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: SelectableText(text),
  );
}

class _ShopPanel extends StatelessWidget {
  const _ShopPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Shop', style: Theme.of(context).textTheme.titleLarge),
          Text('${state.purse} Asse verfügbar'),
          if (state.shopStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(state.shopStatus),
            ),
          const SizedBox(height: 8),
          Text('Verb-Räder', style: Theme.of(context).textTheme.titleMedium),
          ...state.catalog!.wheels.map((wheel) {
            final owned = state.ownedWheels.contains(wheel.id);
            final active = state.activeWheelId == wheel.id;
            return Card(
              child: ListTile(
                title: Text(wheel.name),
                subtitle: Text(
                  '${wheel.description}\n'
                  '${owned ? (active ? 'Ausgerüstet' : 'Im Besitz') : '${wheel.price} Asse · nur auf diesem Gerät'}',
                ),
                isThreeLine: true,
                trailing: FilledButton.tonal(
                  onPressed: active ? null : () => state.buyWheel(wheel.id),
                  child: Text(
                    active
                        ? 'Aktiv'
                        : owned
                        ? 'Ausrüsten'
                        : 'Kaufen',
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Text('Skins', style: Theme.of(context).textTheme.titleMedium),
          ...state.catalog!.skins.map((skin) {
            final owned = state.ownedSkins.contains(skin.id);
            final active = state.activeSkinId == skin.id;
            return Card(
              child: ListTile(
                leading: _SkinSwatch(palette: skin.palette),
                title: Text(skin.name),
                subtitle: Text(
                  '${skin.description} · '
                  '${owned ? (active ? 'Ausgerüstet' : 'Im Besitz') : '${skin.price} Asse'}',
                ),
                trailing: FilledButton.tonal(
                  onPressed: active ? null : () => state.buySkin(skin.id),
                  child: Text(
                    active
                        ? 'Aktiv'
                        : owned
                        ? 'Ausrüsten'
                        : 'Kaufen',
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

class _SkinSwatch extends StatelessWidget {
  const _SkinSwatch({required this.palette});

  final Map<String, String> palette;

  @override
  Widget build(BuildContext context) {
    Color shade(String key, Color fallback) {
      final value = palette[key];
      if (value == null) return fallback;
      return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
    }

    return CircleAvatar(
      backgroundColor: shade('present', Colors.green.shade100),
      child: CircleAvatar(
        radius: 11,
        backgroundColor: shade('perfect', Colors.red.shade100),
      ),
    );
  }
}

class _CustomVerbsPanel extends StatefulWidget {
  const _CustomVerbsPanel({required this.state});

  final AppState state;

  @override
  State<_CustomVerbsPanel> createState() => _CustomVerbsPanelState();
}

class _CustomVerbsPanelState extends State<_CustomVerbsPanel> {
  final _line = TextEditingController();
  final _third = TextEditingController();
  final _past = TextEditingController();
  final _participle = TextEditingController();
  final _code = TextEditingController();
  final _message = ValueNotifier<String>('');
  String _previousMeaning = '';
  String _auxiliary = 'haben';
  CustomVerb? _preview;

  @override
  void dispose() {
    _line.dispose();
    _third.dispose();
    _past.dispose();
    _participle.dispose();
    _code.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Meine Verben', style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${state.customVerbs.length} von 8 Verben auf der eigenen Scheibe. '
              'Regelmäßige a-, e-, i- und konsonantische Verben werden erzeugt.',
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < state.customVerbs.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${state.customVerbs[index].infinitive}, '
                  '${state.customVerbs[index].present}, '
                  '${state.customVerbs[index].perfect}',
                ),
                subtitle: Text(
                  '${state.customVerbs[index].meaning} · '
                  '${_conjugationFor(index, state)}',
                ),
                trailing: IconButton(
                  tooltip: 'Verb entfernen',
                  onPressed: () => state.removeCustomVerb(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            const Divider(),
            Text('Neues Verb', style: Theme.of(context).textTheme.titleMedium),
            TextField(
              controller: _line,
              decoration: const InputDecoration(
                labelText: 'Stammformen – Bedeutung',
                hintText: 'mittere, mittō, mīsī – schicken',
              ),
              onChanged: (_) => _updatePreview(),
            ),
            const SizedBox(height: 5),
            _MacronButtons(onInsert: _insertMacron),
            Text(
              'Infinitiv, 1. Sg. Präsens, 1. Sg. Perfekt und deutsche Bedeutung. '
              'Längenstriche sind optional.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Deutsche Formen anpassen'),
              children: [
                TextField(
                  controller: _third,
                  decoration: const InputDecoration(labelText: 'er/sie/es …'),
                  onChanged: (_) => _updatePreview(keepOverrides: true),
                ),
                TextField(
                  controller: _past,
                  decoration: const InputDecoration(
                    labelText: 'ich … (Präteritum)',
                  ),
                  onChanged: (_) => _updatePreview(keepOverrides: true),
                ),
                TextField(
                  controller: _participle,
                  decoration: const InputDecoration(labelText: 'Partizip II'),
                  onChanged: (_) => _updatePreview(keepOverrides: true),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _auxiliary,
                  decoration: const InputDecoration(labelText: 'Perfekt mit'),
                  items: const [
                    DropdownMenuItem(value: 'haben', child: Text('haben')),
                    DropdownMenuItem(value: 'sein', child: Text('sein')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _auxiliary = value;
                      _updatePreview(keepOverrides: true);
                    }
                  },
                ),
              ],
            ),
            if (_preview != null) _previewTable(_preview!),
            ValueListenableBuilder<String>(
              valueListenable: _message,
              builder: (context, message, _) => message.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(message),
                    ),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _addVerb,
                  icon: const Icon(Icons.add),
                  label: const Text('Auf die Scheibe'),
                ),
                OutlinedButton.icon(
                  onPressed: _copyList,
                  icon: const Icon(Icons.copy),
                  label: const Text('Teilen-Code kopieren'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Teilen-Code laden'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: _loadList,
                child: const Text('Verbliste laden'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _conjugationFor(int index, AppState state) {
    try {
      return GameData.fromCustomVerbs(state.customVerbs).conjugations[index];
    } on FormatException {
      return '';
    }
  }

  Widget _previewTable(CustomVerb verb) {
    final data = GameData.fromCustomVerbs([verb]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${verb.infinitive}, ${verb.present}, ${verb.perfect} · '
            '${data.conjugations.first} · ${data.perfectNotes.first}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Person')),
                ...data.tenses.map((tense) => DataColumn(label: Text(tense))),
              ],
              rows: List.generate(
                6,
                (person) => DataRow(
                  cells: [
                    DataCell(Text(data.persons[person])),
                    ...List.generate(6, (tense) {
                      final form = data.forms.firstWhere(
                        (item) => item.person == person && item.tense == tense,
                      );
                      return DataCell(Text(form.form));
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updatePreview({bool keepOverrides = false}) {
    try {
      final parsed = VerbBuilder.parse(_line.text).entry;
      if (!keepOverrides && parsed.meaning != _previousMeaning) {
        _third.text = parsed.thirdPerson;
        _past.text = parsed.past;
        _participle.text = parsed.participle;
        _auxiliary = parsed.auxiliary;
        _previousMeaning = parsed.meaning;
      }
      final verb = CustomVerb(
        infinitive: parsed.infinitive,
        present: parsed.present,
        perfect: parsed.perfect,
        meaning: parsed.meaning,
        thirdPerson: _third.text.isEmpty ? parsed.thirdPerson : _third.text,
        past: _past.text.isEmpty ? parsed.past : _past.text,
        participle: _participle.text.isEmpty
            ? parsed.participle
            : _participle.text,
        auxiliary: _auxiliary,
        noMacrons: parsed.noMacrons,
      );
      GameData.fromCustomVerbs([verb]);
      setState(() => _preview = verb);
      _message.value = '';
    } on FormatException catch (error) {
      setState(() => _preview = null);
      _message.value = error.message;
    }
  }

  Future<void> _addVerb() async {
    _updatePreview();
    final preview = _preview;
    if (preview == null) return;
    try {
      await widget.state.saveCustomVerb(preview);
      _line.clear();
      _third.clear();
      _past.clear();
      _participle.clear();
      _previousMeaning = '';
      setState(() => _preview = null);
      _message.value = widget.state.customStatus;
    } on FormatException catch (error) {
      _message.value = error.message;
    }
  }

  Future<void> _copyList() async {
    final code = widget.state.exportCustomVerbs();
    await Clipboard.setData(ClipboardData(text: code));
    _message.value = 'Teilen-Code kopiert.';
  }

  Future<void> _loadList() async {
    try {
      await widget.state.importCustomVerbs(_code.text);
      _message.value = widget.state.customStatus;
    } on FormatException catch (error) {
      _message.value = error.message;
    }
  }

  void _insertMacron(String letter) {
    final current = _line.value;
    final start = current.selection.isValid
        ? current.selection.start
        : current.text.length;
    final end = current.selection.isValid ? current.selection.end : start;
    _line.value = TextEditingValue(
      text: current.text.replaceRange(start, end, letter),
      selection: TextSelection.collapsed(offset: start + letter.length),
    );
    _updatePreview();
  }
}

class _RomePanel extends StatefulWidget {
  const _RomePanel({required this.state});

  final AppState state;

  @override
  State<_RomePanel> createState() => _RomePanelState();
}

class _RomePanelState extends State<_RomePanel> {
  final _materials = TextEditingController(text: '1');

  @override
  void dispose() {
    _materials.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final city = state.cityState;
    final sites = [...CityClient.housingSites, ...CityClient.buildings.keys];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cityTitle = Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: scheme.onPrimary.withValues(alpha: .14),
            shape: BoxShape.circle,
            border: Border.all(color: scheme.onPrimary.withValues(alpha: .35)),
          ),
          child: Icon(Icons.account_balance, color: scheme.onPrimary, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dein Rom',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                state.activeAccountName.isEmpty
                    ? 'Eine Stadt, die mit deinen Übungen wächst.'
                    : 'Gespeichert für ${state.activeAccountName}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimary.withValues(alpha: .88),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.tertiary],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final badge = _GloriaBadge(amount: city?.currency ?? 0);
              if (constraints.maxWidth < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [cityTitle, const SizedBox(height: 12), badge],
                );
              }
              return Row(
                children: [
                  Expanded(child: cityTitle),
                  const SizedBox(width: 8),
                  badge,
                ],
              );
            },
          ),
        ),
        if (state.cityStatus.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.cityStatus)),
                ],
              ),
            ),
          ),
        ],
        if (city == null)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    state.activeAccountName.isEmpty
                        ? Icons.lock_outline
                        : Icons.location_city_outlined,
                    size: 40,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.activeAccountName.isEmpty
                        ? 'Melde dich zuerst über die Rangliste an, um dein Rom anzulegen.'
                        : 'Dein Stadtplan wartet darauf, geladen zu werden.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: state.cityLoading ? null : state.loadCity,
                    icon: state.cityLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.map_outlined),
                    label: Text(
                      state.cityLoading ? 'Wird geladen …' : 'Stadtplan öffnen',
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CityMetric(
                icon: Icons.home_work_outlined,
                value: '${state.houses}',
                label: 'Häuser',
              ),
              _CityMetric(
                icon: Icons.construction_outlined,
                value: '${city.progress}',
                label: 'Material gesamt',
              ),
              _CityMetric(
                icon: Icons.trending_up,
                value: '${state.houses}',
                label: 'Asse pro Stunde',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stadtplan',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: state.cityLoading ? null : state.loadCity,
                icon: const Icon(Icons.refresh),
                label: const Text('Aktualisieren'),
              ),
            ],
          ),
          Text(
            'Wähle einen Bauplatz und investiere Material, um Rom wachsen zu lassen.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760
                    ? 3
                    : constraints.maxWidth >= 500
                    ? 2
                    : 1;
                final gap = 10.0;
                final tileWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final site in sites)
                      SizedBox(
                        width: tileWidth,
                        child: _citySiteCard(site, city, state),
                      ),
                  ],
                );
              },
            ),
          ),
          if (state.selectedSite.isNotEmpty)
            _selectedSiteCard(state.selectedSite, city, state),
        ],
      ],
    );
  }

  Widget _citySiteCard(String site, CityState city, AppState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final residential = CityClient.housingSites.contains(site);
    final progress = city.sites[site] ?? 0;
    final building = CityClient.buildings[site];
    final locked = building != null && state.houses < building.houses;
    final complete = building != null && progress >= building.materials;
    final buildingHouses = building?.houses ?? 0;
    final buildingMaterials = building?.materials ?? 1;
    final name = residential ? CityClient.housingNames[site]! : building!.name;
    final selected = state.selectedSite == site;
    final invested = residential ? progress % 20 : progress;
    final goal = residential ? 20 : buildingMaterials;
    final ratio = (invested / goal).clamp(0.0, 1.0).toDouble();
    final subtitle = residential
        ? '${progress ~/ 20} ${progress ~/ 20 == 1 ? 'Haus' : 'Häuser'}'
        : complete
        ? 'Errichtet'
        : locked
        ? 'Ab $buildingHouses Häusern'
        : '$progress/$buildingMaterials Material';
    final icon = residential
        ? Icons.location_city_outlined
        : switch (site) {
            'forum' => Icons.account_balance_outlined,
            'thermae' => Icons.bathtub_outlined,
            'colosseum' => Icons.stadium_outlined,
            'circus' => Icons.flag_outlined,
            'pantheon' => Icons.temple_buddhist_outlined,
            _ => Icons.foundation_outlined,
          };
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: locked || complete ? null : () => state.chooseSite(site),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary.withValues(alpha: .12)
                          : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      locked
                          ? Icons.lock_outline
                          : complete
                          ? Icons.check_circle_outline
                          : icon,
                      color: selected ? scheme.primary : scheme.secondary,
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.radio_button_checked, color: scheme.primary)
                  else if (complete)
                    Icon(Icons.check_circle, color: scheme.tertiary)
                  else if (locked)
                    Icon(Icons.lock, color: scheme.outline, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: complete ? 1 : ratio,
                borderRadius: BorderRadius.circular(4),
                color: complete ? scheme.tertiary : scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedSiteCard(String site, CityState city, AppState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = city.sites[site] ?? 0;
    final residential = CityClient.housingSites.contains(site);
    final building = CityClient.buildings[site];
    final goal = residential ? 20 : building!.materials;
    final invested = residential ? progress % 20 : progress;
    final name = residential ? CityClient.housingNames[site]! : building!.name;
    final details = residential
        ? '$progress Materialien insgesamt · ${progress ~/ 20} Häuser fertig · '
              '${goal - invested} bis zum nächsten Haus'
        : '$progress/$goal Materialien · freigeschaltet ab '
              '${building!.houses} Häusern · Fertigstellung kostet zusätzlich 5 Gloria';
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.construction_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$invested/$goal',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (invested / goal).clamp(0.0, 1.0).toDouble(),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Text(details, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _materials,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Material',
                      hintText: '1–100',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _invest,
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Einsetzen'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ein Material kostet 4 Asse.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _invest() async {
    final value = int.tryParse(_materials.text);
    if (value == null) {
      setState(() {
        widget.state.cityStatus =
            'Wähle eine ganze Materialzahl von 1 bis 100.';
      });
      return;
    }
    try {
      await widget.state.investInCity(value);
    } on ApiException catch (error) {
      widget.state.cityStatus = error.message;
    }
  }
}

class _GloriaBadge extends StatelessWidget {
  const _GloriaBadge({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: onPrimary.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: onPrimary, size: 18),
          const SizedBox(width: 6),
          Text(
            '$amount Gloria',
            style: TextStyle(color: onPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CityMetric extends StatelessWidget {
  const _CityMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardPanel extends StatefulWidget {
  const _LeaderboardPanel({required this.state});

  final AppState state;

  @override
  State<_LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<_LeaderboardPanel> {
  late final TextEditingController _name = TextEditingController(
    text: widget.state.activeAccountName,
  );
  late final TextEditingController _board = TextEditingController(
    text: widget.state.activeBoard,
  );

  @override
  void dispose() {
    _name.dispose();
    _board.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rangliste', style: Theme.of(context).textTheme.titleLarge),
            const Text(
              'Verwende einen Spitznamen (keinen echten Namen!) und den '
              'Klassencode deiner Lehrkraft. Derselbe Code meldet dich auf '
              'anderen Geräten wieder an.',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              maxLength: 16,
              decoration: const InputDecoration(labelText: 'Spitzname'),
              textCapitalization: TextCapitalization.none,
            ),
            TextField(
              controller: _board,
              maxLength: 24,
              decoration: const InputDecoration(labelText: 'Klassencode'),
              textCapitalization: TextCapitalization.none,
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: state.leaderboardLoading ? null : _join,
                  child: const Text('Mitmachen'),
                ),
                OutlinedButton(
                  onPressed: state.leaderboardLoading
                      ? null
                      : state.loadLeaderboard,
                  child: const Text('Aktualisieren'),
                ),
              ],
            ),
            if (state.leaderboardLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
            if (state.leaderboardStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(state.leaderboardStatus),
              ),
            const SizedBox(height: 8),
            ...state.leaderboardRows.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final row = entry.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank.',
                ),
                title: Text(row.name),
                trailing: Text('${row.score} Asse'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _join() async {
    try {
      await widget.state.submitNameAndBoard(_name.text, _board.text);
    } on ApiException catch (error) {
      widget.state.leaderboardStatus = error.message;
      if (mounted) setState(() {});
    }
  }
}

class _HelpPanel extends StatelessWidget {
  const _HelpPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hilfe', style: Theme.of(context).textTheme.titleLarge),
          const _HelpSection(
            title: 'Die Drehscheibe',
            text:
                'Der mittlere Ring wählt ein Verb oder Substantiv, der '
                'äußere Ring Tempus oder Kasus. Die Zeilen im Fenster '
                'stehen für Personen beziehungsweise Numeri. Tippe auf '
                'eine Zeile, um die Form aufzudecken; ein zweiter Tipp '
                'verdeckt sie wieder.',
          ),
          const _HelpSection(
            title: 'Übungen und Münzen',
            text:
                'Gib bei „Deutsch → Latein“ die Form ein oder stelle '
                'sie auf der Scheibe ein und tippe die passende Zeile. '
                'Drei Fehlversuche geben Hinweise, beim vierten wird die '
                'Lösung gezeigt und es werden bis zu 4 Asse abgezogen. '
                'Mit allen Längenstrichen aus dem Kopf gibt es 4 Asse; '
                'sonst meist 2. „Form bestimmen“ bringt 2 Asse. Eine '
                'Serie von fünf richtigen Antworten gibt 2 Bonusasse, '
                'das Tagesziel 5.',
          ),
          const _HelpSection(
            title: 'Verbformen',
            text:
                'Präsens und Perfekt haben unterschiedliche '
                'Personalendungen. Imperfekt und Plusquamperfekt '
                'bezeichnen Vergangenheit; Futur I und II die Zukunft. '
                'Die farbigen Segmente unterscheiden Stamm, Bindevokal, '
                'Tempuszeichen und Endung.',
          ),
          const _HelpSection(
            title: 'Substantive',
            text:
                'Wähle oben die Wortart „Substantive“. Der Genitiv '
                'Singular hilft, Deklination und Stamm zu erkennen. '
                'Neutra haben im Nominativ, Akkusativ und Vokativ die '
                'gleiche Form; vollständige Formen stehen im Katalog.',
          ),
          const _HelpSection(
            title: 'Eigene Verben und Shop',
            text:
                'Eigene Verben benötigen Infinitiv, 1. Person Singular '
                'Präsens, 1. Person Singular Perfekt und eine deutsche '
                'Bedeutung. Prüfe die Vorschau und passe deutsche Formen '
                'bei Bedarf an. Teilen-Codes enthalten die Verbliste. '
                'Shop-Käufe bleiben lokal in diesem Browser.',
          ),
          const _HelpSection(
            title: 'Rom und Rangliste',
            text:
                'Mit einem Spitznamen und Klassencode speicherst du '
                'Ranglistenstand und Stadt. 20 Materialien ergeben ein '
                'Haus und 1 Gloria; besondere Gebäude benötigen Häuser, '
                'Material und 5 Gloria. Häuser erzeugen je 1 As Steuer '
                'pro Stunde, solange die Seite sichtbar geöffnet ist.',
          ),
          const _VoiceSettings(),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _requestDeletion(context),
            icon: const Icon(Icons.mail_outline),
            label: const Text('Datenlöschung per E-Mail anfragen'),
          ),
        ],
      ),
    ),
  );

  Future<void> _requestDeletion(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(
        text:
            'mailto:latin@cozmo-city.com?subject=Anfrage zur Löschung meines Spielkontos',
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'E-Mail-Adresse kopiert: latin@cozmo-city.com. '
            'Bitte sende deine Löschanfrage mit Klassencode und Spitzname.',
          ),
        ),
      );
    }
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(title),
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(alignment: Alignment.centerLeft, child: Text(text)),
      ),
    ],
  );
}

class _VoiceSettings extends StatelessWidget {
  const _VoiceSettings();

  @override
  Widget build(BuildContext context) {
    final app = context
        .findAncestorStateOfType<_TempoHomeState>()
        ?.widget
        .state;
    if (app == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vorlesen', style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 6,
          children: [
            for (final (value, label) in [
              ('off', 'aus'),
              ('f', 'weiblich'),
              ('m', 'männlich'),
            ])
              ChoiceChip(
                selected: app.voiceGender == value,
                label: Text(label),
                onSelected: (_) => app.setVoiceGender(value),
              ),
          ],
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final (value, label) in [
              ('heiter', 'heiter & jung'),
              ('ruhig', 'ruhig'),
            ])
              ChoiceChip(
                selected: app.voiceStyle == value,
                label: Text(label),
                onSelected: (_) => app.setVoiceStyle(value),
              ),
          ],
        ),
        if (app.availableVoices.isNotEmpty)
          DropdownButton<String>(
            value:
                app.selectedVoice.isEmpty ||
                    !app.availableVoices.contains(app.selectedVoice)
                ? ''
                : app.selectedVoice,
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Automatisch passende Stimme'),
              ),
              ...app.availableVoices.map(
                (voice) => DropdownMenuItem(value: voice, child: Text(voice)),
              ),
            ],
            onChanged: (value) {
              if (value != null) app.setVoice(value);
            },
          ),
        Text(
          'Klassische Aussprache: c wie k, v wie w. '
          'Das Vorlesen nutzt die deutschen Stimmen des Browsers.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
