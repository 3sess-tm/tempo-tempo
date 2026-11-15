import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'app_services.dart';
import 'game_data.dart';

class AppState extends ChangeNotifier {
  static const _coinKey = 'drehscheibe-asse';
  static const _earnedKey = 'drehscheibe-verdient';
  static const _shopKey = 'tempo-shop-stand-v1';
  static const _customKey = 'drehscheibe-meineverben';
  static const _statsKey = 'drehscheibe-stats';
  static const _leaderboardKey = 'drehscheibe-rangliste';
  static const _introKey = 'drehscheibe-intro-tempo, tempo – fit in Formen';
  static const _goal = 10;
  static const _maxTries = 4;

  AppState({required LeaderboardClient leaderboard, required CityClient city})
    : _leaderboard = leaderboard,
      _city = city;

  final LeaderboardClient _leaderboard;
  final CityClient _city;
  final Random _random = Random();
  final FlutterTts _tts = FlutterTts();

  LocalStore? _store;
  GameCatalog? catalog;
  String? loadError;
  String? notice;
  bool initialized = false;
  bool isNounMode = false;
  bool snapEnabled = true;
  bool soundEnabled = true;
  bool introSeen = false;
  String voiceGender = 'off';
  String voiceStyle = 'heiter';
  String selectedVoice = '';
  List<String> availableVoices = [];
  String activeTab = 'practice';
  String activeWheelId = 'starter';
  String activeSkinId = 'pergament';
  String selectedSite = '';

  List<String> ownedWheels = ['starter'];
  List<String> ownedSkins = ['pergament'];
  List<CustomVerb> customVerbs = [];
  final Set<int> revealed = {};
  final Set<int> selectedTenses = {};
  final Map<String, int> weakForms = {};
  List<LeaderboardEntry> leaderboardRows = [];
  CityState? cityState;
  DateTime? lastCityTick;
  int cityTaxRemainderMilliseconds = 0;
  bool cityLoading = false;
  bool leaderboardLoading = false;
  String leaderboardStatus = '';
  String cityStatus = '';
  String shopStatus = '';
  String practiceMessage = '';
  String identifyMessage = '';
  String inputValue = '';
  String activeAccountName = '';
  String activeBoard = '';
  String accountId = '';
  String shareCode = '';
  String customStatus = '';
  String selectedName = '';
  String selectedBoard = '';
  int purse = 0;
  int earned = 0;
  int streak = 0;
  int bestStreak = 0;
  int dailyCount = 0;
  bool dailyGoalReached = false;
  String statsDay = '';
  int correctCount = 0;
  int attemptCount = 0;
  int wrongAttempts = 0;
  int wheelWrongAttempts = 0;
  int identificationAttempts = 0;
  bool practiceDone = false;
  bool practicePeeked = false;
  bool identificationDone = false;
  int? selectedPerson;
  VerbForm? practiceForm;
  VerbForm? identificationForm;
  VerbForm? rightForm;
  double outerRotation = 0;
  double innerRotation = 0;
  Timer? _scoreTimer;
  int _cityRequestId = 0;
  bool _cityTimerVisible = false;

  GameData get data {
    final loadedCatalog = catalog;
    if (loadedCatalog == null) {
      throw StateError('The game catalog is not loaded.');
    }
    if (isNounMode) return loadedCatalog.nounData;
    if (activeWheelId == 'my-verbs') {
      return GameData.fromCustomVerbs(customVerbs);
    }
    if (activeWheelId == 'starter') return loadedCatalog.starter;
    return loadedCatalog.wheels
        .firstWhere((wheel) => wheel.id == activeWheelId)
        .data;
  }

  int get selectedTense =>
      _mod((-outerRotation / 60).round(), data.tenses.length);
  int get selectedVerb => _mod(
    (-innerRotation / (360 / data.verbs.length)).round(),
    data.verbs.length,
  );
  bool get wheelAligned =>
      _distance(outerRotation, -60.0 * selectedTense) < 4 &&
      _distance(innerRotation, -360 / data.verbs.length * selectedVerb) < 4;
  int get houses => CityClient.housingSites.fold<int>(
    0,
    (sum, site) => sum + ((cityState?.sites[site] ?? 0) ~/ 20),
  );
  String get itemLabel {
    if (isNounMode) {
      final noun = data.nouns[selectedVerb];
      return '${noun.nominative}, ${noun.genitive} (${noun.gender})';
    }
    return data.verbs[selectedVerb];
  }

  String get selectedWheelName {
    if (activeWheelId == 'starter') return 'Grundrad';
    if (activeWheelId == 'my-verbs') return 'Meine Verben';
    return catalog!.wheels
        .firstWhere((wheel) => wheel.id == activeWheelId)
        .name;
  }

  Map<String, String> get activePalette =>
      catalog!.skins.firstWhere((skin) => skin.id == activeSkinId).palette;

  Future<void> initialize() async {
    try {
      catalog = await GameCatalog.load();
      _store = await LocalStore.load();
      await _loadSavedState();
      await _refreshTenseFilter();
      _refreshForm();
      _newIdentification();
      initialized = true;
      notifyListeners();
      unawaited(_loadVoices());
      if (accountId.isNotEmpty && activeBoard.isNotEmpty) {
        unawaited(loadCity());
      }
      if (activeTab == 'leaderboard') unawaited(loadLeaderboard());
    } on Object catch (error, stackTrace) {
      loadError = 'Die Spieldaten konnten nicht geladen werden: $error';
      debugPrintStack(stackTrace: stackTrace);
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadSavedState() async {
    final store = _store!;
    purse = _readInt(store.read(_coinKey));
    earned = max(_readInt(store.read(_earnedKey)), purse);

    final shop = _readJsonMap(store.read(_shopKey));
    final knownWheels = [
      'starter',
      ...catalog!.wheels.map((wheel) => wheel.id),
    ];
    final knownSkins = catalog!.skins.map((skin) => skin.id).toList();
    ownedWheels = _readStringList(
      shop['ownedWheels'],
    ).where(knownWheels.contains).toSet().toList();
    ownedSkins = _readStringList(
      shop['ownedSkins'],
    ).where(knownSkins.contains).toSet().toList();
    if (!ownedWheels.contains('starter')) ownedWheels.add('starter');
    if (!ownedSkins.contains('pergament')) ownedSkins.add('pergament');
    final savedWheel = shop['activeWheel'];
    if (savedWheel is String && ownedWheels.contains(savedWheel)) {
      activeWheelId = savedWheel;
    }
    final savedSkin = shop['activeSkin'];
    if (savedSkin is String && ownedSkins.contains(savedSkin)) {
      activeSkinId = savedSkin;
    }

    final savedVerbs = _readJsonList(store.read(_customKey));
    if (savedVerbs != null && savedVerbs.isNotEmpty) {
      customVerbs = savedVerbs
          .whereType<Map<String, dynamic>>()
          .map(CustomVerb.fromJson)
          .toList();
      try {
        GameData.fromCustomVerbs(customVerbs);
      } on FormatException catch (error) {
        customVerbs = _defaultCustomVerbs();
        customStatus = 'Gespeicherte Verben waren ungültig: ${error.message}';
      }
    } else {
      customVerbs = _defaultCustomVerbs();
    }

    final savedStats = _readJsonMap(store.read(_statsKey));
    streak = _readInt(savedStats['streak']);
    bestStreak = _readInt(savedStats['best']);
    statsDay = savedStats['day'] as String? ?? '';
    dailyCount = _readInt(savedStats['count']);
    dailyGoalReached = savedStats['goal'] == true;
    final savedWeak = savedStats['weak'];
    if (savedWeak is Map<String, dynamic>) {
      for (final entry in savedWeak.entries) {
        if (entry.value is int && (entry.value as int) > 0) {
          weakForms[entry.key] = entry.value as int;
        }
      }
    }
    _rollDay();

    soundEnabled = store.read('drehscheibe-ton') != 'aus';
    voiceGender = _only(store.read('drehscheibe-vorlesen'), const {
      'off',
      'f',
      'm',
    }, 'off');
    voiceStyle = _only(store.read('drehscheibe-klang'), const {
      'heiter',
      'ruhig',
    }, 'heiter');
    selectedVoice = store.read('drehscheibe-stimmname') ?? '';
    introSeen = store.read(_introKey) == '1';

    final boardConfig = _readJsonMap(store.read(_leaderboardKey));
    activeAccountName = boardConfig['name'] as String? ?? '';
    activeBoard = boardConfig['board'] as String? ?? '';
    accountId = boardConfig['id'] as String? ?? '';
    if (accountId.isEmpty) {
      accountId = createAccountId();
      await _saveLeaderboardConfig();
    }
    selectedName = activeAccountName;
    selectedBoard = activeBoard;

    try {
      final remainder = double.tryParse(
        store.read('tempo-city-tax-$accountId') ?? '',
      );
      if (remainder != null && remainder >= 0) {
        cityTaxRemainderMilliseconds = remainder.floor() % 3600000;
      }
    } on FormatException {
      cityTaxRemainderMilliseconds = 0;
    }

    final initialRoute = Uri.base.fragment;
    if (_validRoute(initialRoute)) activeTab = initialRoute;
  }

  static List<CustomVerb> _defaultCustomVerbs() => const [
    CustomVerb(
      infinitive: 'laudāre',
      present: 'laudō',
      perfect: 'laudāvī',
      meaning: 'loben',
      thirdPerson: 'lobt',
      past: 'lobte',
      participle: 'gelobt',
      auxiliary: 'haben',
    ),
    CustomVerb(
      infinitive: 'dūcere',
      present: 'dūcō',
      perfect: 'dūxī',
      meaning: 'führen',
      thirdPerson: 'führt',
      past: 'führte',
      participle: 'geführt',
      auxiliary: 'haben',
    ),
  ];

  Future<void> _save(String key, Object value) async =>
      _store!.write(key, value is String ? value : jsonEncode(value));

  Future<void> _saveShop() => _save(_shopKey, {
    'ownedWheels': ownedWheels,
    'ownedSkins': ownedSkins,
    'activeWheel': activeWheelId == 'my-verbs' ? 'starter' : activeWheelId,
    'activeSkin': activeSkinId,
  });

  Future<void> _saveLeaderboardConfig() => _save(_leaderboardKey, {
    'name': activeAccountName,
    'board': activeBoard,
    'id': accountId,
  });

  Future<void> _saveStats() => _save(_statsKey, {
    'streak': streak,
    'best': bestStreak,
    'day': statsDay,
    'count': dailyCount,
    'goal': dailyGoalReached,
    'weak': weakForms,
  });

  void _rollDay() {
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    if (statsDay == today) return;
    statsDay = today;
    dailyCount = 0;
    dailyGoalReached = false;
    unawaited(_saveStats());
  }

  String _weakKey(VerbForm form) =>
      '${_itemShort(form.verb)}|${form.tense}|${form.person}';

  void newPractice() {
    _refreshForm();
    notifyListeners();
  }

  void _refreshForm() {
    final allForms = data.forms;
    var pool = selectedTenses.isEmpty
        ? allForms
        : allForms
              .where((form) => selectedTenses.contains(form.tense))
              .toList();
    if (pool.isEmpty) pool = allForms;
    final totalWeight = pool.fold<int>(
      0,
      (sum, form) => sum + 1 + 3 * min(weakForms[_weakKey(form)] ?? 0, 3),
    );
    var target = _random.nextInt(totalWeight);
    practiceForm = pool.firstWhere((form) {
      target -= 1 + 3 * min(weakForms[_weakKey(form)] ?? 0, 3);
      return target < 0;
    });
    practiceMessage = '';
    inputValue = '';
    practiceDone = false;
    practicePeeked = false;
    wrongAttempts = 0;
    wheelWrongAttempts = 0;
    selectedPerson = null;
    rightForm = null;
    revealed.clear();
  }

  void _newIdentification() {
    final forms = data.forms;
    identificationForm = forms[_random.nextInt(forms.length)];
    identifyMessage = '';
    identificationAttempts = 0;
    identificationDone = false;
  }

  void newIdentification() {
    _newIdentification();
    notifyListeners();
  }

  void setInput(String value) {
    inputValue = value.replaceAllMapped(
      RegExp(r'([aeiouAEIOU])[-_]'),
      (match) => {
        'a': 'ā',
        'e': 'ē',
        'i': 'ī',
        'o': 'ō',
        'u': 'ū',
        'A': 'Ā',
        'E': 'Ē',
        'I': 'Ī',
        'O': 'Ō',
        'U': 'Ū',
      }[match[1]]!,
    );
  }

  void submitPractice() {
    final task = practiceForm;
    if (task == null) return;
    final answer = _normalize(inputValue);
    if (answer.isEmpty) {
      practiceMessage = 'Bitte eine Form eingeben.';
      notifyListeners();
      return;
    }
    final goals = _taskForms(task);
    if (!practiceDone) attemptCount++;
    final exact = goals.where((form) => _normalize(form.form) == answer);
    final alternative = exact.isEmpty
        ? goals.where(
            (form) => form.alternatives.any(
              (formAlternative) => _normalize(formAlternative) == answer,
            ),
          )
        : <VerbForm>[];
    final hit = exact.firstOrNull ?? alternative.firstOrNull;
    if (hit != null) {
      final isAlternative = exact.isEmpty;
      final preciselyTyped =
          inputValue.trim().toLowerCase() == hit.form ||
          hit.alternatives.contains(inputValue.trim().toLowerCase());
      final rewardValue = isAlternative
          ? (preciselyTyped && !practicePeeked ? 4 : 2)
          : preciselyTyped && !practicePeeked
          ? 4
          : 2;
      _practiceSuccess(
        hit,
        rewardValue,
        isAlternative
            ? 'Nebenform'
            : preciselyTyped && !practicePeeked
            ? 'mit allen Längen'
            : 'getippt',
      );
      setWheel(hit.verb, hit.tense, hit.person);
      notifyListeners();
      return;
    }

    if (practiceDone) return;
    wrongAttempts++;
    _onWrong(task);
    if (wrongAttempts >= _maxTries) {
      final lost = min(_maxTries, purse);
      purse -= lost;
      unawaited(_save(_coinKey, '$purse'));
      _showPracticeSolution(
        goals.first,
        'Auch der $_maxTries. Versuch war falsch. '
        '${lost > 0 ? '−$lost ${_pluralAs(lost)}.' : 'Die Kasse ist leer.'} ',
      );
      notifyListeners();
      return;
    }

    final other = data.forms
        .where((form) => _normalize(form.form) == answer)
        .firstOrNull;
    final hint = _wrongTip(other, goals.first);
    final count = _maxTries - wrongAttempts;
    practiceMessage = [
      'Noch nicht. $hint'.trim(),
      if (wrongAttempts >= 2) _answerHelp(goals.first),
      if (wrongAttempts >= 3) _tenseHint(goals.first),
      count == 1 ? '⚠ Letzter Versuch!' : 'Noch $count Versuche.',
    ].where((part) => part.isNotEmpty).join('\n');
    notifyListeners();
  }

  void showPracticeSolution() {
    final task = practiceForm;
    if (task == null) return;
    _showPracticeSolution(_taskForms(task).first, '');
    notifyListeners();
  }

  void _practiceSuccess(VerbForm form, int baseReward, String reason) {
    if (!practiceDone) {
      correctCount++;
      final bonus = _onCorrect(form);
      _reward(
        baseReward + bonus.$1,
        [reason, if (bonus.$2.isNotEmpty) bonus.$2].join(' · '),
      );
    }
    practiceDone = true;
    practiceMessage = '✓ Richtig! ${form.form} = ${form.german}';
    selectedPerson = form.person;
    rightForm = form;
    revealed.add(form.person);
    unawaited(_speak(form.form));
  }

  void _showPracticeSolution(VerbForm form, String prefix) {
    practiceDone = true;
    rightForm = null;
    setWheel(form.verb, form.tense, form.person);
    revealed.add(form.person);
    practiceMessage =
        '${prefix.isEmpty ? 'Lösung: ' : '$prefix\n'}${form.form} = ${form.german}';
  }

  void toggleReveal(int person) {
    if (!wheelAligned) return;
    if (revealed.contains(person)) {
      revealed.remove(person);
      if (selectedPerson == person) selectedPerson = null;
    } else {
      revealed.add(person);
      selectedPerson = person;
      practicePeeked = true;
      final form = _currentRows
          .where((item) => item.person == person)
          .firstOrNull;
      if (form != null) unawaited(_speak(form.form));
      if (practiceForm != null && !practiceDone) checkWheelAnswer(person);
    }
    notifyListeners();
  }

  void revealAll() {
    if (!wheelAligned) return;
    revealed.addAll(List.generate(data.persons.length, (index) => index));
    practicePeeked = true;
    notifyListeners();
  }

  void hideAll() {
    revealed.clear();
    selectedPerson = null;
    notifyListeners();
  }

  List<VerbForm> get _currentRows => data.forms
      .where((form) => form.verb == selectedVerb && form.tense == selectedTense)
      .toList();

  void checkWheelAnswer(int person) {
    final task = practiceForm;
    if (task == null || practiceDone) return;
    if (!wheelAligned) {
      practiceMessage = 'Erst die Drehscheibe einrasten lassen.';
      notifyListeners();
      return;
    }
    final form = _currentRows
        .where((item) => item.person == person)
        .firstOrNull;
    if (form == null) return;
    final isCorrect = data.isNoun
        ? form.verb == task.verb &&
              form.tense == task.tense &&
              form.person == task.person
        : form.german == task.german;
    if (isCorrect) {
      attemptCount++;
      _practiceSuccess(
        form,
        wheelWrongAttempts == 0 ? 2 : 1,
        wheelWrongAttempts == 0
            ? 'auf der Scheibe gefunden'
            : 'gefunden, nach Probieren',
      );
    } else {
      wheelWrongAttempts++;
      _onWrong(task);
      practiceMessage =
          'Diese Form (${form.form} = ${form.german}) passt noch nicht.\n'
          '${_wrongTip(form, _taskForms(task).first)}\n'
          '${_answerHelp(_taskForms(task).first)}';
    }
    notifyListeners();
  }

  void checkIdentification() {
    final question = identificationForm;
    if (question == null) return;
    if (!wheelAligned) {
      identifyMessage = 'Die Pfeile stehen noch nicht genau.';
      notifyListeners();
      return;
    }
    final matches = data.forms
        .where((form) => form.form == question.form)
        .where(
          (form) => form.verb == selectedVerb && form.tense == selectedTense,
        )
        .toList();
    if (matches.isNotEmpty) {
      final persons = matches
          .map((form) => data.persons[form.person])
          .join(' / ');
      identifyMessage =
          '✓ Richtig! ${data.tenses[selectedTense]}, $persons – ${matches.first.german}';
      if (!identificationDone) {
        correctCount++;
        _reward(2 + _onCorrect(matches.first).$1, 'Form bestimmt');
        identificationDone = true;
        setWheel(matches.first.verb, matches.first.tense, matches.first.person);
        selectedPerson = matches.first.person;
        revealed.add(matches.first.person);
      }
      notifyListeners();
      return;
    }
    if (identificationDone) return;
    identificationAttempts++;
    final hits = data.forms
        .where((form) => form.form == question.form)
        .toList();
    if (identificationAttempts >= _maxTries) {
      final solution = hits.first;
      final lost = min(_maxTries, purse);
      purse -= lost;
      unawaited(_save(_coinKey, '$purse'));
      _onWrong(question);
      identificationDone = true;
      setWheel(solution.verb, solution.tense, solution.person);
      selectedPerson = solution.person;
      revealed.add(solution.person);
      identifyMessage =
          'Auch der $_maxTries. Versuch war falsch. Lösung: ${solution.form} '
          '= ${solution.german}. ${lost > 0 ? '−$lost Asse.' : ''}';
      notifyListeners();
      return;
    }
    _onWrong(question);
    identifyMessage =
        _wrongTip(hits.first, question) +
        (identificationAttempts >= 2 ? '\n${_answerHelp(hits.first)}' : '') +
        (identificationAttempts >= 3 ? '\n${_tenseHint(hits.first)}' : '');
    notifyListeners();
  }

  void showIdentificationSolution() {
    final question = identificationForm;
    if (question == null) return;
    final answer = data.forms.firstWhere((form) => form.form == question.form);
    setWheel(answer.verb, answer.tense, answer.person);
    selectedPerson = answer.person;
    revealed.add(answer.person);
    identificationDone = true;
    identifyMessage =
        'Lösung: ${data.verbs[answer.verb]}, ${data.tenses[answer.tense]}, '
        '${data.persons[answer.person]} – ${answer.german} (ohne Münze).';
    unawaited(_speak(answer.form));
    notifyListeners();
  }

  List<VerbForm> _taskForms(VerbForm target) => data.forms.where((form) {
    if (data.isNoun) {
      return form.verb == target.verb &&
          form.tense == target.tense &&
          form.person == target.person;
    }
    return form.german == target.german;
  }).toList();

  String _wrongTip(VerbForm? other, VerbForm target) {
    if (other == null) return '';
    if (data.isNoun) {
      if (other.verb == target.verb && other.tense == target.tense) {
        return 'Substantiv und Kasus stimmen, aber der Numerus nicht.';
      }
      if (other.verb == target.verb && other.person == target.person) {
        return 'Substantiv und Numerus stimmen, aber der Kasus nicht.';
      }
      if (other.verb == target.verb) {
        return 'Das Substantiv stimmt, prüfe Kasus und Numerus.';
      }
      return 'Das eingestellte Substantiv passt nicht.';
    }
    if (other.verb == target.verb && other.tense == target.tense) {
      return 'Tempus stimmt – aber die Person noch nicht.';
    }
    if (other.verb == target.verb) {
      return 'Das ist ${data.tenses[other.tense]}; gesucht ist ${data.tenses[target.tense]}.';
    }
    return 'Das eingestellte Verb passt nicht.';
  }

  String _answerHelp(VerbForm form) {
    if (data.isNoun) {
      final noun = data.nouns[form.verb];
      return 'Lemma: ${noun.nominative}, ${noun.genitive} (${noun.gender}) · '
          '${noun.declension}. Gesucht: ${data.tenses[form.tense]}, '
          '${data.persons[form.person]}.';
    }
    final stem = data.stems.length > form.verb ? data.stems[form.verb] : '';
    final ending = form.tense == 3
        ? 'Perfektendungen: -ī, -istī, -it, -imus, -istis, -ērunt.'
        : 'Präsensendungen: -ō/-m, -s, -t, -mus, -tis, -nt.';
    return 'Stammformen: $stem. $ending';
  }

  String _tenseHint(VerbForm form) {
    if (data.isNoun) {
      return 'Gesucht ist ${data.tenses[form.tense]} ${data.persons[form.person]}.';
    }
    final markers = form.segments
        .where((segment) => segment.kind == 'T')
        .map((segment) => segment.text)
        .toList();
    if (markers.isNotEmpty) return 'Tempuszeichen: -${markers.join('-')}-';
    return form.tense == 3
        ? 'Im Perfekt gibt es kein Tempuszeichen.'
        : 'Hier gibt es kein Tempuszeichen.';
  }

  void _onWrong(VerbForm form) {
    streak = 0;
    final key = _weakKey(form);
    weakForms[key] = min((weakForms[key] ?? 0) + 1, 3);
    unawaited(_saveStats());
  }

  (int, String) _onCorrect(VerbForm form) {
    _rollDay();
    streak++;
    bestStreak = max(bestStreak, streak);
    dailyCount++;
    final key = _weakKey(form);
    if ((weakForms[key] ?? 0) > 0) {
      weakForms[key] = weakForms[key]! - 1;
      if (weakForms[key] == 0) weakForms.remove(key);
    }
    var bonus = 0;
    final messages = <String>[];
    if (streak % 5 == 0) {
      bonus += 2;
      messages.add('Serie $streak');
    }
    if (!dailyGoalReached && dailyCount >= _goal) {
      dailyGoalReached = true;
      bonus += 5;
      messages.add('Tagesziel!');
    }
    unawaited(_saveStats());
    _markLeaderboardDirty();
    return (bonus, messages.join(' · '));
  }

  Future<void> _reward(int amount, String reason) async {
    purse += amount;
    earned += amount;
    await _save(_coinKey, '$purse');
    await _save(_earnedKey, '$earned');
    _markLeaderboardDirty();
    notice = '+$amount ${_pluralAs(amount)} ($reason)';
    notifyListeners();
  }

  Future<void> emptyPurse() async {
    purse = 0;
    await _save(_coinKey, '0');
    notifyListeners();
  }

  void rotateRing(String ring, double delta) {
    if (ring == 'A') {
      outerRotation += delta;
    } else {
      innerRotation += delta;
    }
    final key = '$selectedVerb-$selectedTense';
    if (key != _displayKey) {
      _displayKey = key;
      revealed.clear();
      selectedPerson = null;
      if (rightForm != null &&
          rightForm!.verb == selectedVerb &&
          rightForm!.tense == selectedTense) {
        revealed.add(rightForm!.person);
        selectedPerson = rightForm!.person;
      }
    }
    notifyListeners();
  }

  void finishRotation(String ring) {
    if (snapEnabled) {
      if (ring == 'A') {
        outerRotation = (outerRotation / 60).round() * 60;
      } else {
        final step = 360 / data.verbs.length;
        innerRotation = (innerRotation / step).round() * step;
      }
    }
    notifyListeners();
  }

  String _displayKey = '';

  void setWheel(int verb, int tense, [int? person]) {
    final step = 360 / data.verbs.length;
    innerRotation = -step * verb;
    outerRotation = -60.0 * tense;
    selectedPerson = person;
    _displayKey = '$verb-$tense';
    if (person != null) revealed.add(person);
  }

  void setMode(bool nouns) {
    if (isNounMode == nouns) return;
    isNounMode = nouns;
    selectedTenses.clear();
    outerRotation = 0;
    innerRotation = 0;
    revealed.clear();
    rightForm = null;
    unawaited(_refreshTenseFilter());
    _refreshForm();
    _newIdentification();
    notifyListeners();
  }

  void toggleTense(int tense) {
    if (!selectedTenses.add(tense)) selectedTenses.remove(tense);
    unawaited(
      _save(
        isNounMode ? 'drehscheibe-kasus' : 'drehscheibe-tempora',
        selectedTenses.toList(),
      ),
    );
    _refreshForm();
    notifyListeners();
  }

  Future<void> activateWheel(String id) async {
    final allowed =
        id == 'starter' && ownedWheels.contains(id) ||
        id == 'my-verbs' ||
        ownedWheels.contains(id);
    if (!allowed) return;
    isNounMode = false;
    activeWheelId = id;
    outerRotation = 0;
    innerRotation = 0;
    revealed.clear();
    selectedTenses.clear();
    rightForm = null;
    await _saveShop();
    await _refreshTenseFilter();
    _refreshForm();
    _newIdentification();
    notifyListeners();
  }

  Future<void> _refreshTenseFilter() async {
    selectedTenses.clear();
    final raw = _store!.read(
      isNounMode ? 'drehscheibe-kasus' : 'drehscheibe-tempora',
    );
    final decoded = _readJsonList(raw);
    if (decoded != null) {
      for (final value in decoded) {
        if (value is int && value >= 0 && value < data.tenses.length) {
          selectedTenses.add(value);
        }
      }
    }
  }

  Future<void> activateSkin(String id) async {
    if (!ownedSkins.contains(id)) return;
    activeSkinId = id;
    await _saveShop();
    notifyListeners();
  }

  Future<void> buyWheel(String id) async {
    final wheel = catalog!.wheels.firstWhere((item) => item.id == id);
    if (ownedWheels.contains(id)) {
      await activateWheel(id);
      return;
    }
    if (purse < wheel.price) {
      shopStatus = 'Dafür fehlen noch ${wheel.price - purse} Asse.';
      notifyListeners();
      return;
    }
    purse -= wheel.price;
    ownedWheels.add(id);
    await _save(_coinKey, '$purse');
    await _saveShop();
    shopStatus = '${wheel.name} freigeschaltet.';
    notifyListeners();
  }

  Future<void> buySkin(String id) async {
    final skin = catalog!.skins.firstWhere((item) => item.id == id);
    if (ownedSkins.contains(id)) {
      await activateSkin(id);
      return;
    }
    if (purse < skin.price) {
      shopStatus = 'Dafür fehlen noch ${skin.price - purse} Asse.';
      notifyListeners();
      return;
    }
    purse -= skin.price;
    ownedSkins.add(id);
    await _save(_coinKey, '$purse');
    await _saveShop();
    shopStatus = '${skin.name} freigeschaltet.';
    notifyListeners();
  }

  Future<void> saveCustomVerb(CustomVerb verb) async {
    if (customVerbs.length >= 8) {
      throw const FormatException('Höchstens 8 Verben können auf die Scheibe.');
    }
    if (customVerbs.any((item) => item.infinitive == verb.infinitive)) {
      throw const FormatException('Dieses Verb ist schon auf der Scheibe.');
    }
    GameData.fromCustomVerbs([...customVerbs, verb]);
    customVerbs = [...customVerbs, verb];
    await _save(_customKey, customVerbs.map((item) => item.toJson()).toList());
    activeWheelId = 'my-verbs';
    isNounMode = false;
    _refreshForm();
    _newIdentification();
    customStatus = '„${verb.infinitive}“ ist jetzt auf der Scheibe.';
    notifyListeners();
  }

  Future<void> removeCustomVerb(int index) async {
    if (customVerbs.length <= 1) {
      customStatus = 'Mindestens ein Verb muss auf der Scheibe bleiben.';
      notifyListeners();
      return;
    }
    customVerbs = [...customVerbs]..removeAt(index);
    await _save(_customKey, customVerbs.map((item) => item.toJson()).toList());
    _refreshForm();
    _newIdentification();
    notifyListeners();
  }

  String exportCustomVerbs() => base64.encode(
    utf8.encode(jsonEncode(customVerbs.map((e) => e.toJson()).toList())),
  );

  Future<void> importCustomVerbs(String code) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(base64.decode(code.trim())));
    } on FormatException {
      throw const FormatException('Der Teilen-Code ist ungültig.');
    }
    if (decoded is! List) {
      throw const FormatException('Der Teilen-Code enthält keine Verbliste.');
    }
    final imported = decoded.take(8).map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException(
          'Der Teilen-Code enthält ein ungültiges Verb.',
        );
      }
      return CustomVerb.fromJson(entry);
    }).toList();
    if (imported.isEmpty) {
      throw const FormatException('Der Teilen-Code enthält keine Verben.');
    }
    GameData.fromCustomVerbs(imported);
    customVerbs = imported;
    await _save(_customKey, customVerbs.map((e) => e.toJson()).toList());
    await activateWheel('my-verbs');
    customStatus = 'Verbliste geladen.';
  }

  Future<void> submitNameAndBoard(String name, String board) async {
    final cleanName = name.trim();
    final cleanBoard = board.trim().toLowerCase();
    if (cleanName.length < 2 || cleanName.length > 16) {
      throw const ApiException(
        'Der Spitzname muss 2 bis 16 Zeichen lang sein.',
      );
    }
    if (!RegExp(r'^[a-z0-9_-]{1,24}$').hasMatch(cleanBoard)) {
      throw const ApiException(
        'Klassencode: nur Buchstaben, Zahlen, - und _ (ohne Leerzeichen).',
      );
    }
    leaderboardLoading = true;
    leaderboardStatus = 'Konto wird gesucht …';
    selectedName = cleanName;
    selectedBoard = cleanBoard;
    notifyListeners();
    try {
      final account = await _leaderboard.findAccount(cleanBoard, cleanName);
      activeAccountName = cleanName;
      activeBoard = cleanBoard;
      if (account != null) {
        accountId = account.id;
        activeAccountName = account.name;
        earned = account.score;
        purse = account.score;
        await _save(_coinKey, '$purse');
        await _save(_earnedKey, '$earned');
        await _saveLeaderboardConfig();
        leaderboardStatus = 'Willkommen zurück! Dein Guthaben wurde geladen.';
      } else {
        accountId = createAccountId();
        await _saveLeaderboardConfig();
        await _leaderboard.saveScore(
          board: activeBoard,
          id: accountId,
          name: activeAccountName,
          score: earned,
        );
        leaderboardStatus = 'Konto angelegt – dein Guthaben wurde gespeichert.';
      }
      await loadLeaderboard();
      await loadCity();
    } finally {
      leaderboardLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLeaderboard() async {
    if (activeBoard.isEmpty) {
      leaderboardRows = [
        LeaderboardEntry(
          activeAccountName.isEmpty ? 'Du' : activeAccountName,
          earned,
        ),
      ];
      leaderboardStatus =
          'Spitzname und Klassencode eintragen, dann „Mitmachen“.';
      notifyListeners();
      return;
    }
    leaderboardLoading = true;
    notifyListeners();
    try {
      await flushScore();
      leaderboardRows = await _leaderboard.load(activeBoard);
      if (leaderboardRows.isEmpty) {
        leaderboardStatus = 'Noch niemand dabei – du bist der Erste!';
      } else {
        leaderboardStatus = '';
      }
    } on ApiException catch (error) {
      leaderboardRows = [
        LeaderboardEntry(
          activeAccountName.isEmpty ? 'Du' : activeAccountName,
          earned,
        ),
      ];
      leaderboardStatus = '${error.message} Angezeigt wird dein eigener Stand.';
    } finally {
      leaderboardLoading = false;
      notifyListeners();
    }
  }

  void _markLeaderboardDirty() {
    if (activeBoard.isEmpty || activeAccountName.isEmpty) return;
    _scoreTimer?.cancel();
    _scoreTimer = Timer(const Duration(seconds: 30), () {
      unawaited(flushScore());
    });
  }

  Future<void> flushScore() async {
    _scoreTimer?.cancel();
    _scoreTimer = null;
    if (activeBoard.isEmpty || activeAccountName.isEmpty || accountId.isEmpty) {
      return;
    }
    try {
      await _leaderboard.saveScore(
        board: activeBoard,
        id: accountId,
        name: activeAccountName,
        score: earned,
      );
    } on ApiException catch (error) {
      leaderboardStatus = error.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadCity() async {
    final requestId = ++_cityRequestId;
    if (activeBoard.isEmpty || accountId.isEmpty) {
      cityState = null;
      cityStatus = 'Melde dich zuerst über die Rangliste an.';
      notifyListeners();
      return;
    }
    cityLoading = true;
    cityStatus = 'Rom wird geladen …';
    notifyListeners();
    try {
      final loaded = await _city.load(activeBoard, accountId);
      if (requestId != _cityRequestId) return;
      cityState = loaded;
      cityStatus = '';
    } on ApiException catch (error) {
      if (requestId != _cityRequestId) return;
      cityStatus = error.message;
    } finally {
      if (requestId == _cityRequestId) {
        cityLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> investInCity(int materials) async {
    final state = cityState;
    if (state == null || selectedSite.isEmpty) {
      throw const ApiException('Wähle zuerst einen Bauplatz auf der Karte.');
    }
    if (materials < 1 || materials > 100) {
      throw const ApiException('Wähle 1 bis 100 Materialien.');
    }
    final cost = materials * 4;
    if (purse < cost) {
      throw ApiException('Dafür fehlen noch ${cost - purse} Asse.');
    }
    try {
      await flushScore();
    } on ApiException {
      throw const ApiException(
        'Dein Kontostand konnte nicht synchronisiert werden. Bitte erneut versuchen.',
      );
    }
    final previousHouses = houses;
    cityStatus = 'Material wird investiert …';
    notifyListeners();
    try {
      cityState = await _city.invest(
        board: activeBoard,
        id: accountId,
        site: selectedSite,
        materials: materials,
      );
      purse -= cost;
      await _save(_coinKey, '$purse');
      final built = houses - previousHouses;
      cityStatus = built > 0
          ? '$built ${built == 1 ? 'Haus ist' : 'Häuser sind'} fertig – Gloria verdient!'
          : '$materials ${materials == 1 ? 'Material wurde' : 'Materialien wurden'} eingelagert.';
    } on ApiException catch (error) {
      cityStatus = error.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  void chooseSite(String site) {
    if (!CityClient.housingSites.contains(site) &&
        !CityClient.buildings.containsKey(site)) {
      return;
    }
    selectedSite = site;
    notifyListeners();
  }

  void tickCity(bool visible) {
    final now = DateTime.now();
    final previous = lastCityTick;
    lastCityTick = now;
    if (!visible || cityState == null || activeBoard.isEmpty) {
      _cityTimerVisible = false;
      return;
    }
    if (!_cityTimerVisible) {
      _cityTimerVisible = true;
      return;
    }
    if (previous == null) return;
    final elapsed = now.difference(previous).inMilliseconds.clamp(0, 15000);
    cityTaxRemainderMilliseconds += elapsed * houses;
    final tax = cityTaxRemainderMilliseconds ~/ 3600000;
    if (tax <= 0) {
      unawaited(
        _store?.write(
          'tempo-city-tax-$accountId',
          '$cityTaxRemainderMilliseconds',
        ),
      );
      return;
    }
    cityTaxRemainderMilliseconds %= 3600000;
    purse += tax;
    earned += tax;
    unawaited(_save(_coinKey, '$purse'));
    unawaited(_save(_earnedKey, '$earned'));
    _markLeaderboardDirty();
    unawaited(
      _store?.write(
        'tempo-city-tax-$accountId',
        '$cityTaxRemainderMilliseconds',
      ),
    );
    notifyListeners();
  }

  Future<void> setVoiceGender(String value) async {
    voiceGender = value;
    await _save('drehscheibe-vorlesen', value);
    notifyListeners();
  }

  Future<void> setVoiceStyle(String value) async {
    voiceStyle = value;
    await _save('drehscheibe-klang', value);
    notifyListeners();
  }

  Future<void> setVoice(String value) async {
    selectedVoice = value;
    await _save('drehscheibe-stimmname', value);
    notifyListeners();
  }

  Future<void> setSound(bool enabled) async {
    soundEnabled = enabled;
    await _save('drehscheibe-ton', enabled ? 'an' : 'aus');
    notifyListeners();
  }

  Future<void> markIntroSeen() async {
    introSeen = true;
    await _save(_introKey, '1');
    notifyListeners();
  }

  Future<void> _speak(String latin) async {
    if (voiceGender == 'off') return;
    var pronunciation = latin
        .toLowerCase()
        .replaceAll(RegExp(r'u([eēiī])'), r'u-$1')
        .replaceAll(RegExp(r'i([eēiī])'), r'i-$1')
        .replaceAll('eu', 'e-u')
        .replaceAll('c', 'k')
        .replaceAll('v', 'w')
        .replaceAll('e', 'ä')
        .replaceAll('ā', 'ah')
        .replaceAll('ē', 'eh')
        .replaceAll('ī', 'ih')
        .replaceAll('ō', 'oh')
        .replaceAll('ū', 'uh');
    try {
      await _tts.setLanguage('de-DE');
      await _tts.setSpeechRate(voiceStyle == 'heiter' ? 0.78 : 0.7);
      await _tts.setPitch(voiceStyle == 'heiter' ? 1.15 : 0.95);
      if (selectedVoice.isNotEmpty) {
        await _tts.setVoice({'name': selectedVoice, 'locale': 'de-DE'});
      }
      await _tts.speak('$pronunciation.');
    } on PlatformException catch (error) {
      notice =
          'Vorlesen wird von diesem Browser nicht unterstützt: ${error.message}';
      notifyListeners();
    } on MissingPluginException {
      notice = 'Vorlesen wird von diesem Browser nicht unterstützt.';
      notifyListeners();
    }
  }

  Future<void> _loadVoices() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;
      availableVoices =
          voices
              .whereType<Map<dynamic, dynamic>>()
              .where(
                (voice) =>
                    '${voice['locale'] ?? ''}'.toLowerCase().startsWith('de'),
              )
              .map((voice) => '${voice['name'] ?? ''}')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (selectedVoice.isNotEmpty &&
          !availableVoices.contains(selectedVoice)) {
        selectedVoice = '';
      }
    } on PlatformException {
      availableVoices = [];
    } on MissingPluginException {
      availableVoices = [];
    }
  }

  void updateTab(String route) {
    if (!_validRoute(route) || activeTab == route) return;
    activeTab = route;
    if (route == 'leaderboard') unawaited(loadLeaderboard());
    if (route == 'rome') unawaited(loadCity());
    notifyListeners();
  }

  static bool _validRoute(String route) => const {
    'practice',
    'identify',
    'my-verbs',
    'shop',
    'rome',
    'leaderboard',
    'help',
  }.contains(route);

  String _itemShort(int index) => data.isNoun
      ? data.nouns[index].nominative
      : data.verbs[index].split(' ').first;

  static String _normalize(String value) {
    const replacements = {
      'ā': 'a',
      'ē': 'e',
      'ī': 'i',
      'ō': 'o',
      'ū': 'u',
      'Ā': 'a',
      'Ē': 'e',
      'Ī': 'i',
      'Ō': 'o',
      'Ū': 'u',
    };
    final plain = value
        .replaceAllMapped(
          RegExp('[āēīōūĀĒĪŌŪ]'),
          (match) => replacements[match[0]]!,
        )
        .toLowerCase();
    return plain.replaceAll(RegExp(r'[^a-z]'), '');
  }

  static int _readInt(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static String _only(String? value, Set<String> allowed, String fallback) =>
      value != null && allowed.contains(value) ? value : fallback;

  static List<String> _readStringList(Object? value) =>
      value is List ? value.whereType<String>().toList() : <String>[];

  static Map<String, dynamic> _readJsonMap(String? value) {
    if (value == null || value.isEmpty) return <String, dynamic>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      return <String, dynamic>{};
    }
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  static List<dynamic>? _readJsonList(String? value) {
    if (value == null || value.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      return null;
    }
    return decoded is List ? decoded : null;
  }

  static int _mod(int value, int divisor) =>
      (value % divisor + divisor) % divisor;

  static double _distance(double a, double b) {
    final difference = ((a - b) % 360).abs();
    return min(difference, 360 - difference);
  }

  static String _pluralAs(int value) => value == 1 ? 'As' : 'Asse';

  @override
  void dispose() {
    _scoreTimer?.cancel();
    super.dispose();
  }
}
