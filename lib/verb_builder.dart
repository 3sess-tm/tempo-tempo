import 'game_data.dart';

class GeneratedVerb {
  const GeneratedVerb({
    required this.forms,
    required this.conjugation,
    required this.futureMnemonic,
    required this.perfectNote,
    required this.germanForms,
  });

  final List<List<List<FormSegment>>> forms;
  final String conjugation;
  final String futureMnemonic;
  final String perfectNote;
  final List<List<String>> germanForms;
}

class ParsedVerbLine {
  const ParsedVerbLine(this.entry, this.hadMacrons);

  final CustomVerb entry;
  final bool hadMacrons;
}

class VerbBuilder {
  static const _persons = ['ich', 'du', 'er (sie, es)', 'wir', 'ihr', 'sie'];
  static const _perfectEndings = ['ī', 'istī', 'it', 'imus', 'istis', 'ērunt'];
  static const _presentEndings = ['m', 's', 't', 'mus', 'tis', 'nt'];
  static const _presentPerfEndings = ['ō', 's', 't', 'mus', 'tis', 'nt'];
  static const _werden = [
    'werde',
    'wirst',
    'wird',
    'werden',
    'werdet',
    'werden',
  ];
  static const _haben = ['habe', 'hast', 'hat', 'haben', 'habt', 'haben'];
  static const _sein = ['bin', 'bist', 'ist', 'sind', 'seid', 'sind'];
  static const _hatte = [
    'hatte',
    'hattest',
    'hatte',
    'hatten',
    'hattet',
    'hatten',
  ];
  static const _war = ['war', 'warst', 'war', 'waren', 'wart', 'waren'];

  static FormSegment s(String text) => FormSegment(text, 'S');
  static FormSegment e(String text) => FormSegment(text, 'E');
  static FormSegment t(String text) => FormSegment(text, 'T');
  static FormSegment b(String text) => FormSegment(text, 'B');
  static const _hyphen = FormSegment('-', 'H');

  static List<FormSegment> join(List<List<FormSegment>> parts) {
    final result = <FormSegment>[];
    for (final part in parts) {
      if (result.isNotEmpty) result.add(_hyphen);
      result.addAll(part);
    }
    return result;
  }

  static GeneratedVerb build(CustomVerb entry) {
    final infinitive = entry.infinitive.trim().toLowerCase();
    final present = entry.present.trim().toLowerCase();
    final perfect = entry.perfect.trim().toLowerCase();
    final plainInfinitive = _plain(infinitive);
    final plainPresent = _plain(present);
    final plainPerfect = _plain(perfect);
    if (infinitive.isEmpty || !plainPresent.endsWith('o')) {
      throw const FormatException(
        'Die 1. Sg. Präsens muss auf -ō enden (z. B. laudō).',
      );
    }
    if (!plainPerfect.endsWith('i')) {
      throw const FormatException(
        'Die 1. Sg. Perfekt muss auf -ī enden (z. B. laudāvī).',
      );
    }
    if (entry.meaning.trim().isEmpty ||
        entry.thirdPerson.trim().isEmpty ||
        entry.past.trim().isEmpty ||
        entry.participle.trim().isEmpty) {
      throw const FormatException('Bitte alle deutschen Felder ausfüllen.');
    }

    final root = present.substring(0, present.length - 1);
    final perfectStem = perfect.substring(0, perfect.length - 1);
    final forms = List.generate(
      6,
      (_) => List<List<FormSegment>>.filled(6, const [], growable: false),
      growable: false,
    );
    late final String conjugationCode;
    late final String conjugation;
    late final String future;

    if (plainInfinitive.endsWith('are')) {
      conjugationCode = 'a';
      conjugation = 'a-Konjugation';
      future = 'ghost';
      final longStem = '$root\u0101';
      final shortStem = '$root\u0061';
      forms[0] = [
        join([
          [s(root)],
          [e('ō')],
        ]),
        join([
          [s(longStem)],
          [e('s')],
        ]),
        join([
          [s(shortStem)],
          [e('t')],
        ]),
        join([
          [s(longStem)],
          [e('mus')],
        ]),
        join([
          [s(longStem)],
          [e('tis')],
        ]),
        join([
          [s(shortStem)],
          [e('nt')],
        ]),
      ];
      forms[1] = List.generate(
        6,
        (i) => join([
          [s(longStem)],
          [
            t([0, 2, 5].contains(i) ? 'ba' : 'bā'),
          ],
          [e(_presentEndings[i])],
        ]),
      );
      forms[2] = List.generate(
        6,
        (i) => join([
          [s(longStem)],
          [
            t(['b', 'bi', 'bi', 'bi', 'bi', 'bu'][i]),
          ],
          [e(_presentPerfEndings[i])],
        ]),
      );
    } else if (plainInfinitive.endsWith('ere') && plainPresent.endsWith('eo')) {
      conjugationCode = 'e';
      conjugation = 'e-Konjugation';
      future = 'ghost';
      final longStem = '${root.substring(0, root.length - 1)}ē';
      forms[0] = [
        join([
          [s(root)],
          [e('ō')],
        ]),
        join([
          [s(longStem)],
          [e('s')],
        ]),
        join([
          [s(root)],
          [e('t')],
        ]),
        join([
          [s(longStem)],
          [e('mus')],
        ]),
        join([
          [s(longStem)],
          [e('tis')],
        ]),
        join([
          [s(root)],
          [e('nt')],
        ]),
      ];
      forms[1] = List.generate(
        6,
        (i) => join([
          [s(longStem)],
          [
            t([0, 2, 5].contains(i) ? 'ba' : 'bā'),
          ],
          [e(_presentEndings[i])],
        ]),
      );
      forms[2] = List.generate(
        6,
        (i) => join([
          [s(longStem)],
          [
            t(['b', 'bi', 'bi', 'bi', 'bi', 'bu'][i]),
          ],
          [e(_presentPerfEndings[i])],
        ]),
      );
    } else if (plainInfinitive.endsWith('ire') && plainPresent.endsWith('io')) {
      conjugationCode = 'i';
      conjugation = 'i-Konjugation';
      future = 'camel';
      final longStem = '${root.substring(0, root.length - 1)}ī';
      forms[0] = [
        join([
          [s(root)],
          [e('ō')],
        ]),
        join([
          [s(longStem)],
          [e('s')],
        ]),
        join([
          [s(root)],
          [e('t')],
        ]),
        join([
          [s(longStem)],
          [e('mus')],
        ]),
        join([
          [s(longStem)],
          [e('tis')],
        ]),
        join([
          [s(root)],
          [b('u')],
          [e('nt')],
        ]),
      ];
      forms[1] = List.generate(
        6,
        (i) => join([
          [s(root)],
          [
            t([0, 2, 5].contains(i) ? 'ēba' : 'ēbā'),
          ],
          [e(_presentEndings[i])],
        ]),
      );
      forms[2] = List.generate(
        6,
        (i) => join([
          [s(root)],
          [
            t(['a', 'ē', 'e', 'ē', 'ē', 'e'][i]),
          ],
          [e(_presentEndings[i])],
        ]),
      );
    } else if (plainInfinitive.endsWith('ere') && plainPresent.endsWith('io')) {
      conjugationCode = 'm';
      conjugation = 'kons. Konjugation mit i-Erweiterung';
      future = 'camel';
      forms[0] = [
        join([
          [s(root)],
          [e('ō')],
        ]),
        join([
          [s(root)],
          [e('s')],
        ]),
        join([
          [s(root)],
          [e('t')],
        ]),
        join([
          [s(root)],
          [e('mus')],
        ]),
        join([
          [s(root)],
          [e('tis')],
        ]),
        join([
          [s(root)],
          [b('u')],
          [e('nt')],
        ]),
      ];
      forms[1] = List.generate(
        6,
        (i) => join([
          [s(root)],
          [
            t([0, 2, 5].contains(i) ? 'ēba' : 'ēbā'),
          ],
          [e(_presentEndings[i])],
        ]),
      );
      forms[2] = List.generate(
        6,
        (i) => join([
          [s(root)],
          [
            t(['a', 'ē', 'e', 'ē', 'ē', 'e'][i]),
          ],
          [e(_presentEndings[i])],
        ]),
      );
    } else if (plainInfinitive.endsWith('ere') &&
        RegExp(r'[^ei]o$').hasMatch(plainPresent)) {
      conjugationCode = 'k';
      conjugation = 'konsonantische Konjugation';
      future = 'camel';
      forms[0] = [
        join([
          [s(root)],
          [e('ō')],
        ]),
        join([
          [s(root)],
          [b('i')],
          [e('s')],
        ]),
        join([
          [s(root)],
          [b('i')],
          [e('t')],
        ]),
        join([
          [s(root)],
          [b('i')],
          [e('mus')],
        ]),
        join([
          [s(root)],
          [b('i')],
          [e('tis')],
        ]),
        join([
          [s(root)],
          [b('u')],
          [e('nt')],
        ]),
      ];
      forms[1] = List.generate(
        6,
        (i) => join([
          [s(root)],
          [
            t([0, 2, 5].contains(i) ? 'ēba' : 'ēbā'),
          ],
          [e(_presentEndings[i])],
        ]),
      );
      forms[2] = List.generate(
        6,
        (i) => join([
          [s(root)],
          [
            t(['a', 'ē', 'e', 'ē', 'ē', 'e'][i]),
          ],
          [e(_presentEndings[i])],
        ]),
      );
    } else {
      throw const FormatException(
        'Konjugation nicht erkannt. Verwende -āre, -ēre, -īre oder -ere '
        'mit einer passenden Präsensform auf -ō.',
      );
    }

    var perfectParts = <FormSegment>[s(perfectStem)];
    var perfectNote = 'Perfekt mit eigenem Stamm';
    if (RegExp(r'^([^aeiou])[aeiou]\1').hasMatch(plainPerfect) &&
        !plainRoot(
          root,
          conjugationCode,
        ).startsWith(plainPerfect.substring(0, 3))) {
      perfectParts = [
        FormSegment(perfectStem.substring(0, 2), 'P'),
        _hyphen,
        s(perfectStem.substring(2)),
      ];
      perfectNote = 'Reduplikationsperfekt';
    } else if (plainPerfect.endsWith('v')) {
      perfectParts = [
        s(perfectStem.substring(0, perfectStem.length - 1)),
        _hyphen,
        const FormSegment('v', 'P'),
      ];
      perfectNote = 'v-Perfekt';
    } else if (plainPerfect.endsWith('u')) {
      perfectParts = [
        s(perfectStem.substring(0, perfectStem.length - 1)),
        _hyphen,
        const FormSegment('u', 'P'),
      ];
      perfectNote = 'u-Perfekt';
    } else if (plainPerfect.endsWith('x') ||
        (plainPerfect.endsWith('s') &&
            !plainRoot(root, conjugationCode).endsWith('s'))) {
      perfectParts = [
        s(perfectStem.substring(0, perfectStem.length - 1)),
        _hyphen,
        FormSegment(perfectStem.substring(perfectStem.length - 1), 'P'),
      ];
      perfectNote = 's-Perfekt';
    } else if (RegExp('[āēīōū]').hasMatch(perfect)) {
      perfectNote = 'Dehnungsperfekt';
    } else if (perfectStem == root ||
        perfectStem == root.replaceFirst(RegExp(r'i$'), '')) {
      perfectNote = 'Stammperfekt';
    }

    forms[3] = List.generate(
      6,
      (i) => join([
        perfectParts,
        [e(_perfectEndings[i])],
      ]),
    );
    forms[4] = List.generate(
      6,
      (i) => join([
        perfectParts,
        [
          t([0, 2, 5].contains(i) ? 'era' : 'erā'),
        ],
        [e(_presentEndings[i])],
      ]),
    );
    forms[5] = List.generate(
      6,
      (i) => join([
        perfectParts,
        [t(i == 0 ? 'er' : 'eri')],
        [e(_presentPerfEndings[i])],
      ]),
    );

    return GeneratedVerb(
      forms: forms,
      conjugation: conjugation,
      futureMnemonic: future,
      perfectNote: perfectNote,
      germanForms: _germanForms(entry),
    );
  }

  static String plainRoot(String root, String conjugation) {
    final plain = _plain(root);
    if (conjugation == 'a' || conjugation == 'k') return plain;
    return plain.isNotEmpty ? plain.substring(0, plain.length - 1) : plain;
  }

  static List<List<String>> _germanForms(CustomVerb entry) {
    final infinitive = entry.meaning.trim();
    final er = entry.thirdPerson.trim();
    final past = entry.past.trim();
    final participle = entry.participle.trim();
    final stem = infinitive.replaceFirst(RegExp(r'e?n$'), '');
    final ihr = RegExp(r'([dt]|[^lrhmnaeiouäöü][mn])$').hasMatch(stem)
        ? '${stem}et'
        : '${stem}t';
    final du = RegExp(r'(s|ß|z|x)t$').hasMatch(er)
        ? er
        : er.replaceFirst(RegExp(r't$'), 'st');
    final present = ['${stem}e', du, er, infinitive, ihr, infinitive];
    final pastForms = past.endsWith('te') || past.endsWith('e')
        ? [past, '${past}st', past, '${past}n', '${past}t', '${past}n']
        : [
            past,
            '$past${RegExp(r'(s|ß|z|x|[dt])$').hasMatch(past) ? 'est' : 'st'}',
            past,
            '${past}en',
            '$past${RegExp(r'[dt]$').hasMatch(past) ? 'et' : 't'}',
            '${past}en',
          ];
    final auxiliary = entry.auxiliary == 'sein' ? _sein : _haben;
    final pastAuxiliary = entry.auxiliary == 'sein' ? _war : _hatte;
    return [
      List.generate(6, (i) => '${_persons[i]} ${present[i]}'),
      List.generate(6, (i) => '${_persons[i]} ${pastForms[i]}'),
      List.generate(6, (i) => '${_persons[i]} ${_werden[i]} $infinitive'),
      List.generate(6, (i) => '${_persons[i]} ${auxiliary[i]} $participle'),
      List.generate(6, (i) => '${_persons[i]} ${pastAuxiliary[i]} $participle'),
      List.generate(
        6,
        (i) => '${_persons[i]} ${_werden[i]} $participle ${entry.auxiliary}',
      ),
    ];
  }

  static ParsedVerbLine parse(String line) {
    final normalized = line
        .replaceAll(RegExp('[—–]'), ' – ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final separator = RegExp(r'\s[–-]\s|\s*[:=]\s*').firstMatch(normalized);
    var latin = separator == null
        ? normalized
        : normalized.substring(0, separator.start);
    var meaning = separator == null
        ? ''
        : normalized.substring(separator.end).trim();
    var tokens = latin
        .split(RegExp(r'[,;\s]+'))
        .map((token) => token.replaceAll(RegExp(r'[:.]+$'), ''))
        .where((token) => token.isNotEmpty)
        .toList();
    if (separator == null) {
      final count =
          tokens.length > 3 && RegExp(r'(um|us)$').hasMatch(_plain(tokens[3]))
          ? 4
          : 3;
      meaning = tokens.skip(count).join(' ');
      tokens = tokens.take(count).toList();
    }
    if (tokens.length < 3 || meaning.isEmpty) {
      throw const FormatException(
        'Bitte Infinitiv, 1. Sg. Präsens und Perfekt sowie eine deutsche '
        'Bedeutung angeben – z. B. „mittere, mittō, mīsī – schicken“.',
      );
    }

    var infinitive = tokens[0].toLowerCase();
    var present = tokens[1].toLowerCase();
    var perfect = tokens[2].toLowerCase();
    final hadMacrons = RegExp('[āēīōū]').hasMatch(normalized);
    if (_plain(present).endsWith('o')) {
      present = '${present.substring(0, present.length - 1)}ō';
    }
    if (_plain(perfect).endsWith('i')) {
      perfect = '${perfect.substring(0, perfect.length - 1)}ī';
    }
    if (_plain(infinitive).endsWith('are')) {
      infinitive = '${infinitive.substring(0, infinitive.length - 3)}āre';
    } else if (_plain(infinitive).endsWith('ire') &&
        _plain(present).endsWith('io')) {
      infinitive = '${infinitive.substring(0, infinitive.length - 3)}īre';
    } else if (_plain(infinitive).endsWith('ere') &&
        _plain(present).endsWith('eo')) {
      infinitive = '${infinitive.substring(0, infinitive.length - 3)}ēre';
    }
    if (infinitive.endsWith('āre')) {
      perfect = perfect.replaceFirst(RegExp(r'avī$'), 'āvī');
    } else if (infinitive.endsWith('īre')) {
      perfect = perfect.replaceFirst(RegExp(r'ivī$'), 'īvī');
    } else if (infinitive.endsWith('ēre')) {
      perfect = perfect.replaceFirst(RegExp(r'evī$'), 'ēvī');
    }
    final german = _automaticGerman(meaning);
    return ParsedVerbLine(
      CustomVerb(
        infinitive: infinitive,
        present: present,
        perfect: perfect,
        meaning: german.meaning,
        thirdPerson: german.thirdPerson,
        past: german.past,
        participle: german.participle,
        auxiliary: german.auxiliary,
        noMacrons: !hadMacrons,
      ),
      hadMacrons,
    );
  }

  static ({
    String meaning,
    String thirdPerson,
    String past,
    String participle,
    String auxiliary,
  })
  _automaticGerman(String raw) {
    final meaning = raw.trim().toLowerCase();
    const irregular = <String, List<String>>{
      'sein': ['ist', 'war', 'gewesen', 'sein'],
      'haben': ['hat', 'hatte', 'gehabt', 'haben'],
      'werden': ['wird', 'wurde', 'geworden', 'sein'],
      'gehen': ['geht', 'ging', 'gegangen', 'sein'],
      'kommen': ['kommt', 'kam', 'gekommen', 'sein'],
      'fahren': ['fährt', 'fuhr', 'gefahren', 'sein'],
      'laufen': ['läuft', 'lief', 'gelaufen', 'sein'],
      'sehen': ['sieht', 'sah', 'gesehen', 'haben'],
      'lesen': ['liest', 'las', 'gelesen', 'haben'],
      'sprechen': ['spricht', 'sprach', 'gesprochen', 'haben'],
      'schreiben': ['schreibt', 'schrieb', 'geschrieben', 'haben'],
      'nehmen': ['nimmt', 'nahm', 'genommen', 'haben'],
      'geben': ['gibt', 'gab', 'gegeben', 'haben'],
      'essen': ['isst', 'aß', 'gegessen', 'haben'],
      'trinken': ['trinkt', 'trank', 'getrunken', 'haben'],
      'finden': ['findet', 'fand', 'gefunden', 'haben'],
      'bringen': ['bringt', 'brachte', 'gebracht', 'haben'],
      'denken': ['denkt', 'dachte', 'gedacht', 'haben'],
      'machen': ['macht', 'machte', 'gemacht', 'haben'],
      'schlafen': ['schläft', 'schlief', 'geschlafen', 'haben'],
      'helfen': ['hilft', 'half', 'geholfen', 'haben'],
      'tragen': ['trägt', 'trug', 'getragen', 'haben'],
      'ziehen': ['zieht', 'zog', 'gezogen', 'haben'],
      'liegen': ['liegt', 'lag', 'gelegen', 'haben'],
      'stehen': ['steht', 'stand', 'gestanden', 'haben'],
      'bleiben': ['bleibt', 'blieb', 'geblieben', 'sein'],
    };
    final base = meaning.replaceFirst(RegExp(r'^sich\s+'), '');
    final known = irregular[base];
    if (known != null) {
      return (
        meaning: meaning,
        thirdPerson: known[0],
        past: known[1],
        participle: known[2],
        auxiliary: known[3],
      );
    }
    final stem = meaning.replaceFirst(RegExp(r'e?n$'), '');
    final et = RegExp(r'([dt]|[^lrhmnaeiouäöü][mn])$').hasMatch(stem);
    final thirdPerson = '$stem${et ? 'et' : 't'}';
    final past = '$stem${et ? 'ete' : 'te'}';
    final participle = meaning.endsWith('ieren')
        ? '$stem${et ? 'et' : 't'}'
        : 'ge$stem${et ? 'et' : 't'}';
    return (
      meaning: meaning,
      thirdPerson: thirdPerson,
      past: past,
      participle: participle,
      auxiliary: 'haben',
    );
  }

  static String _plain(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll('ā', 'a')
      .replaceAll('ē', 'e')
      .replaceAll('ī', 'i')
      .replaceAll('ō', 'o')
      .replaceAll('ū', 'u');
}
