# Rangliste auf Cloudflare (kostenlos)

Voraussetzung: Node.js, Cloudflare-Konto (hast du). Kein Tunnel nötig.

1. `cd cloudflare`
2. `npx wrangler login`
3. `npx wrangler d1 create tempo-lb`  → die ausgegebene `database_id` in `wrangler.toml` eintragen
4. `npx wrangler d1 execute tempo-lb --remote --file=schema.sql`
5. `npx wrangler deploy`
6. Dashboard → Workers & Pages → tempo-tempo → Settings → Domains & Routes → Custom Domain (z. B. latein.deinedomain.de)

Die Seite und die API laufen dann auf derselben Domain (`/api/lb`), deshalb braucht es kein CORS.
Zum Aktualisieren der Seite: neue `index.html` nach `public/` kopieren, `npx wrangler deploy`.
