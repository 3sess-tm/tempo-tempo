# tempo, tempo – fit in Formen

Ein kleines Latein-Lernspiel mit einer interaktiven Konjugationsscheibe, Übungen, optional eigenen Verben und einer gemeinsamen Rangliste. Das Frontend wird als statische Cloudflare-Assets ausgeliefert; der Cloudflare Worker stellt die Ranglisten-API bereit und speichert sie in D1.

Die Kartenplätze für Wohnviertel und Sonderbauten werden in `city_sites` gespeichert. Falls die vorherige Rom-Version bereits ausgerollt wurde, muss nach `0002_city.sql` auch die neue Migration einmalig auf die bestehende Datenbank angewendet werden:

```sh
npx wrangler d1 execute tempo-lb --remote --file=./migrations/0003_city_sites.sql
```

## Lokal starten

Voraussetzung ist Node.js. Wrangler wird bei den Befehlen über `npx` ausgeführt; eine separate Paketinstallation ist nicht nötig.

```sh
npx wrangler dev
```

Die lokale Vorschau ist normalerweise unter `http://localhost:8787` erreichbar. Für lokale Ranglisten-Tests kann das D1-Schema einmalig in die lokale Datenbank geladen werden:

```sh
npx wrangler d1 execute tempo-lb --local --file=./schema.sql
```

Wenn eine Datenbank bereits mit dem vorherigen Schema läuft, einmalig die Stadterweiterung einspielen:

```sh
npx wrangler d1 execute tempo-lb --local --file=./migrations/0002_city.sql
npx wrangler d1 execute tempo-lb --local --file=./migrations/0003_city_sites.sql
```

Bei einer Datenbank, auf der die erste Rom-Version schon läuft, nur die neue Migration ausführen: `npx wrangler d1 execute tempo-lb --remote --file=./migrations/0003_city_sites.sql`. Die Migrationen sind jeweils einmal pro Datenbank auszuführen. Neu angelegte Datenbanken erhalten alle Spalten direkt über `schema.sql`.

## Cloudflare einrichten und veröffentlichen

Voraussetzung sind ein Cloudflare-Konto und eine Anmeldung bei Wrangler:

```sh
npx wrangler login
npx wrangler d1 execute tempo-lb --remote --file=./schema.sql
npx wrangler deploy
```

Die D1-Datenbank `tempo-lb` ist bereits in `wrangler.toml` konfiguriert. Für eine neue Cloudflare-Umgebung zuerst eine D1-Datenbank anlegen und deren `database_id` dort eintragen:

```sh
npx wrangler d1 create tempo-lb
```

`wrangler deploy` veröffentlicht den Worker und alle Frontend-Dateien aus `public/`. Eine eigene Domain lässt sich im Cloudflare-Dashboard unter **Workers & Pages → tempo-tempo → Settings → Domains & Routes** hinzufügen. Frontend und Ranglisten-API laufen auf derselben Domain; die API ist unter `/api/lb` erreichbar und benötigt kein CORS.

## Projektdateien

- `worker.js`: Worker-Endpunkte für Rangliste und Stadtbau
- `schema.sql`: D1-Schema
- `migrations/0002_city.sql`: einmalige Migration für vorhandene D1-Datenbanken
- `migrations/0003_city_sites.sql`: einmalige Migration für gespeicherte Bauplätze auf der Rom-Karte
- `wrangler.toml`: Worker-, Assets- und D1-Konfiguration
- `public/index.html`: HTML-Grundgerüst
- `public/app.css`: Stylesheet
- `public/app.js`: Spiel-Logik
- `public/data/wheels.json`: Daten des kostenlosen Grundrads
- `public/data/shop.json`: kaufbare Radpakete und Skin-Paletten
- `public/data/nouns.json`: Substantive mit vollständigen Kasus- und Numerusformen

Im Reiter **Rom** kaufen angemeldete Spieler Baumaterial mit Assen und investieren es in einzelne Bauplätze auf der Karte: 20 Materialien (80 Asse) ergeben ein Haus. Fertige Häuser geben je 1 Gloria; freigeschaltete Sonderbauten kosten zusätzlich 5 Gloria und Baumaterial. Häuser erzeugen je 1 As Steuer pro Stunde, solange die Seite sichtbar geöffnet ist. Fortschritt und Gloria werden im Ranglisten-Konto gespeichert; neue Datenbanken nutzen das vollständige Schema, bestehende Datenbanken benötigen die Migration oben.

Der Shop bietet drei zusätzliche Verb-Räder und drei kaufbare Skins. Käufe und Ausrüstung werden lokal im Browser gespeichert und sind nicht zwischen Geräten synchronisiert. Bei der Rangliste meldet „Mitmachen“ mit Klassencode und Spitzname am vorhandenen Konto an oder legt ein neues an. Bei einer erneuten Anmeldung wird das Asse-Guthaben mit dem gespeicherten Ranglistenstand synchronisiert; lokaler Shop-Besitz bleibt auf das jeweilige Gerät beschränkt. Ausgaben senken nur das verfügbare Guthaben; die Rangliste zählt weiterhin alle verdienten Asse.

Das Layout passt sich kleinen Bildschirmen an: Die Drehscheibe lässt sich einklappen, und die Reiternavigation bleibt beim Scrollen erreichbar. Ein automatischer Dunkelmodus folgt der Systemeinstellung; beim Drucken werden Bedienelemente ausgeblendet und nur der gerade aktive Bereich ausgegeben.

Die Spielbereiche sind auch direkt verlinkbar: `#practice`, `#identify`, `#my-verbs`, `#shop`, `#rome`, `#leaderboard` und `#help`. Auf Mobilgeräten lässt sich innerhalb des aktiven Bereichs horizontal wischen; Browser-Zurück und -Vorwärts wechseln zwischen den zuletzt geöffneten Bereichen.

Über die Wortart-Auswahl gibt es zwei Übungsarten für Substantive: deutsche Vorgaben ins Lateinische übertragen sowie eine lateinische Form nach Substantiv, Kasus und Numerus bestimmen. Das Substantivrad zeigt die fünf Deklinationsklassen mit ausgewählten Formen aller fünf Deklinationen; der Genitiv Singular und das Genus gehören jeweils zum Lemma. Die Formen sind im Katalog vollständig hinterlegt, damit auch Neutra, i-Stämme und besondere Vokativformen nicht durch pauschale Endungsregeln verfälscht werden.

## Flutter-Portierung (Vorbereitung)

Das Flutter-Projekt liegt im Repository-Root; die bestehende HTML-/JavaScript-Version und das bisherige Deployment bleiben bis zu einer ausdrücklich geplanten Umstellung aktiv. Der erste Zielpfad ist **Flutter Web**, passend zum bestehenden Browser-Produkt. Das Flutter-SDK enthält bereits das Dart-SDK. Im aktuellen Entwicklungscontainer sind Flutter 3.50.0 und Dart 3.14.0 unter `$HOME/flutter` installiert. Für eine neue Umgebung Flutter stable installieren und den SDK-Ordner zum `PATH` hinzufügen:

```sh
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"
```

In einer vorhandenen Shell kann die `PATH`-Ergänzung stattdessen in die eigene Shell-Konfiguration übernommen werden. Projektbefehle:

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d web-server --web-port 8080
flutter build web
```

`flutter build web` erzeugt `build/web/`. Für eine lokale Vorschau zusammen mit dem bestehenden Worker nach dem Build `npx wrangler dev --config wrangler.flutter.toml` verwenden; bei Bedarf das lokale D1-Schema mit `npx wrangler d1 execute tempo-lb --local --config wrangler.flutter.toml --file=./schema.sql` laden. Diese Konfiguration ist nur für lokale Vorschauen gedacht. **Nicht** mit ihr deployen: `wrangler.toml` und der bestehende GitHub-Deploy-Workflow veröffentlichen weiterhin `public/`. Ein Wechsel des Produktiv-Frontends erfordert einen separaten, abgestimmten Deployment-Schritt.

### Leitplanken für die Übersetzung

- Die drei JSON-Kataloge unter `public/data/` bleiben zunächst die einzige Datenquelle und sind bereits als Flutter-Assets eingebunden. Macrons, vollständige Substantivparadigmen, IDs und Preise unverändert übernehmen; keine Formen aus allgemeinen Endungsregeln ableiten.
- Spiellogik (Formbildung, Aufgaben, Belohnungen, Shop-/Stadtregeln) von UI und Plattformdiensten trennen. Die bisherige Anwendung bündelt diese Bereiche in `public/app.js`; sinnvolle Dart-Features sind Drehscheibe, Übungen, eigene Verben, Shop, Rom, Rangliste und Hilfe.
- Die Backend-Verträge bleiben same-origin: `/api/lb` und `/api/city` sprechen mit dem Cloudflare Worker und D1. HTTP-Status und Fehlerantworten beachten; keine zweite Client-Implementierung der serverseitigen Stadtregeln und kein CORS erforderlich.
- Browserdaten sind Teil des Nutzerkontos auf dem Gerät: vor Änderungen an `localStorage`-Schlüsseln, Guthaben, gekauften Rädern/Skins, eigenen Verben und Einstellungen eine versionsbezogene Übernahme planen. Shop-Besitz bleibt lokal; Ranglistenstand und Rom sind kontogebunden.
- Die Web-Version nutzt Browserfunktionen, die Dart nicht automatisch ersetzt: SVG-/Touch-Drehscheibe, Vorlesen (`speechSynthesis`), Ton, Vollbild, Drucken, Sichtbarkeit/Steuer-Timer, Deep Links und Browser-Zurück/Vorwärts. Für jede Funktion eine Web-Implementierung oder einen klaren Ersatz vorsehen und Tastaturbedienung, Semantik, kleine Bildschirme sowie hell/dunkel mitprüfen.
- Vor einem öffentlichen Wechsel App-Icons/Installationsmetadaten prüfen, Web-Routen und Deep Links testen sowie Ranglisten- und Rom-API gegen eine lokale D1-Datenbank validieren. Android-/iOS-Toolchains sind nicht Teil dieser Web-Vorbereitung; dafür wäre eine eigene Plattformentscheidung und Einrichtung nötig.
