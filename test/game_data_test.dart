import 'package:flutter_test/flutter_test.dart';
import 'package:tempo_tempo/game_data.dart';
import 'package:tempo_tempo/verb_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the checked-in verb, shop, skin, and noun catalogs', () async {
    final catalog = await GameCatalog.load();

    expect(catalog.starter.forms, hasLength(180));
    expect(catalog.wheels, hasLength(3));
    expect(catalog.skins, hasLength(10));
    expect(catalog.nouns, hasLength(12));
    expect(catalog.nounData.forms, hasLength(144));
    expect(
      catalog.nounData.forms
          .where((form) => form.form == 'cornū')
          .map((form) => form.german),
      contains('mit dem Horn'),
    );
    expect(
      catalog.starter.forms.first.segments.map((segment) => segment.kind),
      contains('E'),
    );
  });

  test('generates all six tenses for the supported Latin conjugations', () {
    final samples = [
      (
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
        'laudās',
        'laudābam',
        'laudāvī',
      ),
      (
        CustomVerb(
          infinitive: 'monēre',
          present: 'moneō',
          perfect: 'monuī',
          meaning: 'mahnen',
          thirdPerson: 'mahnt',
          past: 'mahnte',
          participle: 'gemahnt',
          auxiliary: 'haben',
        ),
        'monēs',
        'monēbam',
        'monuī',
      ),
      (
        CustomVerb(
          infinitive: 'audīre',
          present: 'audiō',
          perfect: 'audīvī',
          meaning: 'hören',
          thirdPerson: 'hört',
          past: 'hörte',
          participle: 'gehört',
          auxiliary: 'haben',
        ),
        'audīs',
        'audiēbam',
        'audīvī',
      ),
      (
        CustomVerb(
          infinitive: 'vincere',
          present: 'vincō',
          perfect: 'vīcī',
          meaning: 'siegen',
          thirdPerson: 'siegt',
          past: 'siegte',
          participle: 'gesiegt',
          auxiliary: 'haben',
        ),
        'vincis',
        'vincēbam',
        'vīcī',
      ),
      (
        CustomVerb(
          infinitive: 'capere',
          present: 'capiō',
          perfect: 'cēpī',
          meaning: 'fangen',
          thirdPerson: 'fängt',
          past: 'fing',
          participle: 'gefangen',
          auxiliary: 'haben',
        ),
        'capis',
        'capiēbam',
        'cēpī',
      ),
    ];

    for (final (verb, secondPerson, imperfect, perfect) in samples) {
      final generated = VerbBuilder.build(verb);
      expect(generated.forms, hasLength(6));
      expect(generated.forms.every((tense) => tense.length == 6), isTrue);
      expect(
        generated.forms[0][1]
            .where((segment) => segment.kind != 'H')
            .map((segment) => segment.text)
            .join(),
        secondPerson,
      );
      expect(
        generated.forms[1][0]
            .where((segment) => segment.kind != 'H')
            .map((segment) => segment.text)
            .join(),
        imperfect,
      );
      expect(
        generated.forms[3][0]
            .where((segment) => segment.kind != 'H')
            .map((segment) => segment.text)
            .join(),
        perfect,
      );
    }
  });

  test('parses shareable input and adds the inferable final macrons', () {
    final parsed = VerbBuilder.parse('mittere, mitto, misi – schicken');

    expect(parsed.entry.infinitive, 'mittere');
    expect(parsed.entry.present, 'mittō');
    expect(parsed.entry.perfect, 'misī');
    expect(parsed.entry.meaning, 'schicken');
    expect(parsed.hadMacrons, isFalse);
    expect(
      () => VerbBuilder.parse('mittere – schicken'),
      throwsFormatException,
    );
  });
}
