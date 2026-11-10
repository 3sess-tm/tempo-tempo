# tempo, tempo – fit in Formen

Ein kleines Latein-Lernspiel mit einer interaktiven Konjugationsscheibe, Übungen, optional eigenen Verben und einer gemeinsamen Rangliste. Das Frontend wird als statische Cloudflare-Assets ausgeliefert; der Cloudflare Worker stellt die Ranglisten-API bereit und speichert sie in D1.

## Lokal starten

Voraussetzung ist Node.js. Wrangler wird bei den Befehlen über `npx` ausgeführt; eine separate Paketinstallation ist nicht nötig.

```sh
npx wrangler dev
```

Die lokale Vorschau ist normalerweise unter `http://localhost:8787` erreichbar. Für lokale Ranglisten-Tests kann das D1-Schema einmalig in die lokale Datenbank geladen werden:

```sh
npx wrangler d1 execute tempo-lb --local --file=./schema.sql
```

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

- `worker.js`: Worker-Endpunkt für die Rangliste
- `schema.sql`: D1-Schema
- `wrangler.toml`: Worker-, Assets- und D1-Konfiguration
- `public/index.html`: HTML-Grundgerüst
- `public/app.css`: Stylesheet
- `public/app.js`: Spiel-Logik
- `public/data/wheels.json`: Daten des kostenlosen Grundrads
- `public/data/shop.json`: kaufbare Radpakete und Skin-Paletten

Der Shop bietet drei zusätzliche Verb-Räder und drei kaufbare Skins. Guthaben, Käufe und Ausrüstung werden lokal im Browser gespeichert und sind nicht zwischen Geräten synchronisiert. Ausgaben senken nur das verfügbare Guthaben; die Rangliste zählt weiterhin alle verdienten Asse.
