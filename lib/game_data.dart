import 'dart:convert';

import 'package:flutter/services.dart';

import 'verb_builder.dart';

class FormSegment {
  const FormSegment(this.text, this.kind);

  final String text;
  final String kind;

  factory FormSegment.fromJson(List<Object?> json) =>
      FormSegment(json[0] as String, json[1] as String);
}

class VerbForm {
  const VerbForm({
    required this.form,
    required this.verb,
    required this.tense,
    required this.person,
    required this.segments,
    required this.german,
    this.alternatives = const [],
    this.futureMnemonic,
  });

  final String form;
  final int verb;
  final int tense;
  final int person;
  final List<FormSegment> segments;
  final String german;
  final List<String> alternatives;
  final String? futureMnemonic;

  factory VerbForm.fromJson(List<Object?> json) => VerbForm(
    form: json[0] as String,
    verb: json[1] as int,
    tense: json[2] as int,
    person: json[3] as int,
    segments: (json[4] as List<Object?>)
        .map((segment) => FormSegment.fromJson(segment as List<Object?>))
        .toList(),
    german: json[5] as String,
    alternatives: json.length > 6 && json[6] is List
        ? (json[6] as List<Object?>).cast<String>()
        : const [],
    futureMnemonic: json.length > 7 ? json[7] as String? : null,
  );
}

class NounEntry {
  const NounEntry({
    required this.nominative,
    required this.genitive,
    required this.gender,
    required this.declension,
    required this.meaning,
    required this.forms,
    required this.german,
  });

  final String nominative;
  final String genitive;
  final String gender;
  final String declension;
  final String meaning;
  final List<List<String>> forms;
  final List<List<String>> german;

  factory NounEntry.fromJson(Map<String, Object?> json) => NounEntry(
    nominative: json['nom'] as String,
    genitive: json['gen'] as String,
    gender: json['gender'] as String,
    declension: json['declension'] as String,
    meaning: json['meaning'] as String,
    forms: (json['forms'] as List<Object?>)
        .map((row) => (row as List<Object?>).cast<String>())
        .toList(),
    german: (json['german'] as List<Object?>)
        .map((row) => (row as List<Object?>).cast<String>())
        .toList(),
  );
}

class GameData {
  const GameData({
    required this.verbs,
    required this.conjugations,
    required this.stems,
    required this.futureMnemonics,
    required this.perfectNotes,
    required this.tenses,
    required this.persons,
    required this.forms,
    this.nouns = const [],
    this.isNoun = false,
    this.isCustom = false,
  });

  final List<String> verbs;
  final List<String> conjugations;
  final List<String> stems;
  final List<String?> futureMnemonics;
  final List<String?> perfectNotes;
  final List<String> tenses;
  final List<String> persons;
  final List<VerbForm> forms;
  final List<NounEntry> nouns;
  final bool isNoun;
  final bool isCustom;

  factory GameData.fromJson(Map<String, Object?> json) {
    final forms = (json['forms'] as List<Object?>)
        .map((form) => VerbForm.fromJson(form as List<Object?>))
        .toList();
    return GameData(
      verbs: (json['verbs'] as List<Object?>).cast<String>(),
      conjugations: (json['konj'] as List<Object?>).cast<String>(),
      stems: json['stamm'] is List
          ? (json['stamm'] as List<Object?>).cast<String>()
          : const [],
      futureMnemonics: json['futmn'] is List
          ? (json['futmn'] as List<Object?>)
                .map((value) => value as String?)
                .toList()
          : const [],
      perfectNotes: json['pft'] is List
          ? (json['pft'] as List<Object?>)
                .map((value) => value as String?)
                .toList()
          : const [],
      tenses: (json['tenses'] as List<Object?>).cast<String>(),
      persons: (json['pers'] as List<Object?>).cast<String>(),
      forms: forms,
      isCustom: json['custom'] == true,
    );
  }

  factory GameData.fromNouns(
    List<NounEntry> nouns,
    List<String> cases,
    List<String> numbers,
  ) {
    final forms = <VerbForm>[];
    for (var noun = 0; noun < nouns.length; noun++) {
      for (var number = 0; number < 2; number++) {
        for (
          var grammaticalCase = 0;
          grammaticalCase < cases.length;
          grammaticalCase++
        ) {
          final form = nouns[noun].forms[number][grammaticalCase];
          forms.add(
            VerbForm(
              form: form,
              verb: noun,
              tense: grammaticalCase,
              person: number,
              segments: [FormSegment(form, 'S')],
              german: nouns[noun].german[number][grammaticalCase],
            ),
          );
        }
      }
    }
    return GameData(
      verbs: nouns.map((noun) => noun.nominative).toList(),
      conjugations: nouns.map((noun) => noun.declension).toList(),
      stems: const [],
      futureMnemonics: const [],
      perfectNotes: const [],
      tenses: cases,
      persons: numbers,
      forms: forms,
      nouns: nouns,
      isNoun: true,
    );
  }

  factory GameData.fromCustomVerbs(List<CustomVerb> entries) {
    final forms = <VerbForm>[];
    final conjugations = <String>[];
    final stems = <String>[];
    final futureMnemonics = <String?>[];
    final perfectNotes = <String?>[];
    final verbs = <String>[];

    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final generated = VerbBuilder.build(entry);
      verbs.add('${entry.infinitive} (${entry.meaning})');
      conjugations.add(generated.conjugation);
      stems.add('${entry.infinitive}, ${entry.present}, ${entry.perfect}');
      futureMnemonics.add(generated.futureMnemonic);
      perfectNotes.add(generated.perfectNote);
      for (var tense = 0; tense < generated.forms.length; tense++) {
        for (var person = 0; person < generated.forms[tense].length; person++) {
          final segments = generated.forms[tense][person];
          forms.add(
            VerbForm(
              form: segments
                  .where((segment) => segment.kind != 'H')
                  .map((segment) => segment.text)
                  .join(),
              verb: index,
              tense: tense,
              person: person,
              segments: segments,
              german: generated.germanForms[tense][person],
              futureMnemonic: generated.futureMnemonic,
            ),
          );
        }
      }
    }

    return GameData(
      verbs: verbs,
      conjugations: conjugations,
      stems: stems,
      futureMnemonics: futureMnemonics,
      perfectNotes: perfectNotes,
      tenses: defaultTenses,
      persons: defaultPersons,
      forms: forms,
      isCustom: true,
    );
  }

  static const defaultTenses = [
    'Präsens',
    'Imperfekt',
    'Futur I',
    'Perfekt',
    'Plusquamperfekt',
    'Futur II',
  ];
  static const defaultPersons = [
    '1. Sg.',
    '2. Sg.',
    '3. Sg.',
    '1. Pl.',
    '2. Pl.',
    '3. Pl.',
  ];
}

class WheelPackage {
  const WheelPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.data,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final GameData data;
}

class SkinPackage {
  const SkinPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.palette,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final Map<String, String> palette;
}

class GameCatalog {
  const GameCatalog({
    required this.starter,
    required this.wheels,
    required this.skins,
    required this.nouns,
    required this.cases,
    required this.numbers,
  });

  final GameData starter;
  final List<WheelPackage> wheels;
  final List<SkinPackage> skins;
  final List<NounEntry> nouns;
  final List<String> cases;
  final List<String> numbers;

  GameData get nounData => GameData.fromNouns(nouns, cases, numbers);

  static Future<GameCatalog> load() async {
    final wheelJson =
        jsonDecode(await rootBundle.loadString('public/data/wheels.json'))
            as Map<String, Object?>;
    final shopJson =
        jsonDecode(await rootBundle.loadString('public/data/shop.json'))
            as Map<String, Object?>;
    final nounJson =
        jsonDecode(await rootBundle.loadString('public/data/nouns.json'))
            as Map<String, Object?>;

    final starterJson = (wheelJson['wheels'] as List<Object?>)
        .map((wheel) => wheel as Map<String, Object?>)
        .firstWhere((wheel) => wheel['id'] == 'starter');
    final starter = GameData.fromJson(
      starterJson['data'] as Map<String, Object?>,
    );
    final shopWheels = (shopJson['wheels'] as List<Object?>)
        .map((item) => item as Map<String, Object?>)
        .map(
          (item) => WheelPackage(
            id: item['id'] as String,
            name: item['name'] as String,
            description: item['description'] as String,
            price: item['price'] as int,
            data: GameData.fromCustomVerbs(
              (item['verbs'] as List<Object?>)
                  .map(
                    (verb) => CustomVerb.fromJson(verb as Map<String, Object?>),
                  )
                  .toList(),
            ),
          ),
        )
        .toList();
    final skins = (shopJson['skins'] as List<Object?>)
        .map((item) => item as Map<String, Object?>)
        .map(
          (item) => SkinPackage(
            id: item['id'] as String,
            name: item['name'] as String,
            description: item['description'] as String,
            price: item['price'] as int,
            palette: (item['palette'] as Map<String, Object?>).map(
              (key, value) => MapEntry(key, value as String),
            ),
          ),
        )
        .toList();
    final nouns = (nounJson['nouns'] as List<Object?>)
        .map((noun) => NounEntry.fromJson(noun as Map<String, Object?>))
        .toList();

    return GameCatalog(
      starter: starter,
      wheels: shopWheels,
      skins: skins,
      nouns: nouns,
      cases: (nounJson['cases'] as List<Object?>).cast<String>(),
      numbers: (nounJson['numbers'] as List<Object?>).cast<String>(),
    );
  }
}

class CustomVerb {
  const CustomVerb({
    required this.infinitive,
    required this.present,
    required this.perfect,
    required this.meaning,
    required this.thirdPerson,
    required this.past,
    required this.participle,
    required this.auxiliary,
    this.noMacrons = false,
  });

  final String infinitive;
  final String present;
  final String perfect;
  final String meaning;
  final String thirdPerson;
  final String past;
  final String participle;
  final String auxiliary;
  final bool noMacrons;

  factory CustomVerb.fromJson(Map<String, Object?> json) => CustomVerb(
    infinitive: json['inf'] as String,
    present: json['pr'] as String,
    perfect: json['pf'] as String,
    meaning: json['dInf'] as String,
    thirdPerson: json['dEr'] as String,
    past: json['dPt'] as String,
    participle: json['dP2'] as String,
    auxiliary: json['aux'] as String? ?? 'haben',
    noMacrons: json['nm'] as bool? ?? false,
  );

  Map<String, Object?> toJson() => {
    'inf': infinitive,
    'pr': present,
    'pf': perfect,
    'dInf': meaning,
    'dEr': thirdPerson,
    'dPt': past,
    'dP2': participle,
    'aux': auxiliary,
    if (noMacrons) 'nm': true,
  };
}
