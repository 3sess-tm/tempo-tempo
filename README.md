# tempo, tempo – fit in Formen

Ein kleines Latein-Lernspiel mit einer interaktiven Konjugationsscheibe, Übungen, optional eigenen Verben und einer gemeinsamen Rangliste. Das Frontend wird als statische Cloudflare-Assets ausgeliefert; der Cloudflare Worker stellt die Ranglisten-API bereit und speichert sie in D1.

Wohnviertel und Sonderbauten werden in `city_sites` gespeichert. Bestehende Spielstände aus der bisherigen Rom-Version werden beim ersten Stadt-API-Aufruf automatisch als Rom übernommen. Falls eine Datenbank noch nicht die Spalte `city_sites` hat, die Migration einmalig ausführen:

```sh
npx wrangler d1 execute tempo-lb --remote --file=./migrations/0003_city_sites.sql
```

## Lokal entwickeln

Voraussetzung ist das Flutter-SDK (Flutter 3.50.0 / Dart 3.14.0) und Node.js. Die Flutter-Web-App kann separat gestartet werden:

```sh
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8000
```

In VS Code ist derselbe Startbefehl als Aufgabe **Flutter Web (Port 8000)** verfügbar. Nicht `web/index.html` direkt mit einem statischen Dateiserver öffnen: `flutter_bootstrap.js` wird beim Flutter-Lauf beziehungsweise Build erzeugt und liegt nicht im Quellordner `web/`. Falls Port 8000 bereits belegt ist, den dort laufenden statischen Server zuerst in seinem Terminal beenden. Für die veröffentlichungsnahe Vorschau mit Worker-API und lokaler D1-Datenbank zuerst die Web-App bauen und Wrangler starten:

```sh
flutter build web
npx wrangler dev
```

Die kombinierte Vorschau ist normalerweise unter `http://localhost:8787` erreichbar. Das lokale D1-Schema kann einmalig geladen werden:

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

`wrangler deploy` veröffentlicht den Worker und das zuvor gebaute Flutter-Web-Frontend aus `build/web/`. Der GitHub-Action-Workflow installiert Flutter, analysiert und testet den Dart-Code und erstellt den Web-Build, bevor er Wrangler deployt. Eine eigene Domain lässt sich im Cloudflare-Dashboard unter **Workers & Pages → tempo-tempo → Settings → Domains & Routes** hinzufügen. Frontend und APIs (`/api/lb`, `/api/city`) laufen auf derselben Domain; CORS ist nicht erforderlich.

## Projektdateien

- `worker.js`: Worker-Endpunkte für Rangliste und Stadtbau
- `schema.sql`: D1-Schema
- `migrations/0002_city.sql`: einmalige Migration für vorhandene D1-Datenbanken
- `migrations/0003_city_sites.sql`: einmalige Migration für gespeicherte Bauplätze auf der Rom-Karte
- `wrangler.toml`: Worker-, Assets- und D1-Konfiguration
- `lib/main.dart`: Flutter-Oberfläche und Browser-Einstieg
- `lib/app_state.dart`: Spielzustand und Belohnungslogik
- `lib/game_data.dart`, `lib/verb_builder.dart`: JSON-Kataloge und Verbformen
- `lib/app_services.dart`: lokale Speicherung und Worker-APIs
- `web/`: Flutter-Web-Startseite und App-Metadaten
- `public/data/wheels.json`: Daten des kostenlosen Grundrads
- `public/data/shop.json`: kaufbare Radpakete und Skin-Paletten
- `public/data/nouns.json`: Substantive mit vollständigen Kasus- und Numerusformen

Im Reiter **Städte** kaufen angemeldete Spieler Baumaterial mit Assen und investieren es auf einer interaktiven Karte. Die Haus-Silhouetten füllen sich entsprechend dem Ausbau. 20 Materialien (80 Asse) ergeben ein Haus. Fertige Häuser geben je 1 Gloria; freigeschaltete Wahrzeichen kosten bei Fertigstellung zusätzlich 5 Gloria. Häuser erzeugen je 1 As Steuer pro Stunde, solange die Seite sichtbar geöffnet ist.

Die Stadtreise führt durch **Rom**, **Trier** und **Verona**. Nach Fertigstellung aller fünf Wahrzeichen einer Stadt wird automatisch die nächste freigeschaltet; das letzte Wahrzeichen wird jeweils erst ab 80 Häusern freigeschaltet. Gloria und die steuerfinanzierten Asse sind städteübergreifend, Baufortschritt und Wohnviertel bleiben je Stadt getrennt. Bestehende römische Bauplätze und Gloria bleiben erhalten.

Der Shop bietet drei zusätzliche Verb-Räder und drei kaufbare Skins. Käufe und Ausrüstung werden lokal im Browser gespeichert und sind nicht zwischen Geräten synchronisiert. Bei der Rangliste meldet „Mitmachen“ mit Klassencode und Spitzname am vorhandenen Konto an oder legt ein neues an. Bei einer erneuten Anmeldung wird das Asse-Guthaben mit dem gespeicherten Ranglistenstand synchronisiert; lokaler Shop-Besitz bleibt auf das jeweilige Gerät beschränkt. Ausgaben senken nur das verfügbare Guthaben; die Rangliste zählt weiterhin alle verdienten Asse.

Das Layout passt sich kleinen Bildschirmen an: Die Drehscheibe lässt sich einklappen. Ein automatischer Dunkelmodus folgt der Systemeinstellung; Vollbild und Drucken verwenden die Browserfunktionen.

Die Spielbereiche sind auch direkt verlinkbar: `#practice`, `#identify`, `#my-verbs`, `#shop`, `#rome`, `#leaderboard` und `#help`. Browser-Zurück und -Vorwärts wechseln zwischen den zuletzt geöffneten Bereichen.

Über die Wortart-Auswahl gibt es zwei Übungsarten für Substantive: deutsche Vorgaben ins Lateinische übertragen sowie eine lateinische Form nach Substantiv, Kasus und Numerus bestimmen. Das Substantivrad zeigt die fünf Deklinationsklassen mit ausgewählten Formen aller fünf Deklinationen; der Genitiv Singular und das Genus gehören jeweils zum Lemma. Die Formen sind im Katalog vollständig hinterlegt, damit auch Neutra, i-Stämme und besondere Vokativformen nicht durch pauschale Endungsregeln verfälscht werden.

## Qualitätssicherung

```sh
flutter analyze --fatal-infos
flutter test
node --test test/worker_city_test.mjs
flutter build web --no-wasm-dry-run
```

Die lokale Speicherung übernimmt die bestehenden Browser-Schlüssel einschließlich Guthaben, Shop-Besitz, Einstellungen, eigenen Verben, Ranglisten-Konto und Spielstatistik. Rangliste und Städte verwenden weiterhin denselben Worker-Endpunkt und D1-Datensatz; die vorhandenen Rom-Spielstände werden automatisch in das Mehrstädteformat übernommen. Der Web-Build ist das einzige konfigurierte Ziel; Android- und iOS-Toolchains sind nicht Teil dieses Projekts.
