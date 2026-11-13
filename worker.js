// Rangliste für "tempo, tempo" – Cloudflare Worker + D1 (Free-Plan reicht)
const json = (o, s = 200) => new Response(JSON.stringify(o), {
  status: s, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });

const CITY_MATERIAL_PRICE = 4;
const CITY_HOUSE_MATERIALS = 20;
const CITY_HOUSING_SITES = ['insula-1', 'insula-2', 'insula-3', 'insula-4', 'insula-5'];
const CITY_BUILDINGS = [
  { id: 'forum', name: 'Forum Romanum', houses: 5, materials: 100 },
  { id: 'thermae', name: 'Thermen', houses: 15, materials: 200 },
  { id: 'colosseum', name: 'Kolosseum', houses: 30, materials: 300 },
  { id: 'circus', name: 'Circus Maximus', houses: 50, materials: 400 },
  { id: 'pantheon', name: 'Pantheon', houses: 80, materials: 500 }
];

function citySitesFor(account) {
  let sites;
  try { sites = JSON.parse(account.city_sites || '{}'); } catch { sites = null; }
  if (sites && typeof sites === 'object' && !Array.isArray(sites) &&
      [...CITY_HOUSING_SITES, ...CITY_BUILDINGS.map(building => building.id)]
        .every(id => Number.isSafeInteger(sites[id]) && sites[id] >= 0))
    return sites;

  sites = Object.fromEntries([...CITY_HOUSING_SITES, ...CITY_BUILDINGS.map(building => building.id)].map(id => [id, 0]));
  let remaining = account.city_progress;
  for (const id of CITY_HOUSING_SITES) {
    const investment = Math.min(remaining, 400);
    sites[id] = investment;
    remaining -= investment;
  }
  const legacyBuildings = Math.min(CITY_BUILDINGS.length,
    Math.floor((Math.floor(account.city_progress / CITY_HOUSE_MATERIALS) - account.city_currency) / 5));
  CITY_BUILDINGS.slice(0, Math.max(0, legacyBuildings)).forEach(building => { sites[building.id] = building.materials; });
  return sites;
}

async function cityApi(req, env, url) {
  const board = (url.searchParams.get('board') || '').toLowerCase();
  const id = url.searchParams.get('id') || '';
  if (!/^[a-z0-9_-]{1,24}$/.test(board) || !/^[A-Za-z0-9]{8,40}$/.test(id))
    return json({ error: 'invalid account' }, 400);

  if (req.method !== 'GET' && req.method !== 'POST')
    return new Response('Method not allowed', { status: 405 });

  const account = await env.DB.prepare(
    'SELECT score, city_progress, city_currency, city_sites FROM scores WHERE board = ? AND id = ?'
  ).bind(board, id).first();
  if (!account) return json({ error: 'account' }, 404);
  const sites = citySitesFor(account);
  const houses = CITY_HOUSING_SITES.reduce((sum, site) => sum + Math.floor(sites[site] / CITY_HOUSE_MATERIALS), 0);

  if (req.method === 'GET')
    return json({ progress: account.city_progress, currency: account.city_currency, sites });

  let body;
  try { body = await req.json(); } catch { return json({ error: 'json' }, 400); }
  if (!body || typeof body !== 'object' || Array.isArray(body))
    return json({ error: 'invalid' }, 400);

  if (body.action === 'invest') {
    const site = body.site;
    const materials = body.materials;
    const building = CITY_BUILDINGS.find(candidate => candidate.id === site);
    const housingSite = CITY_HOUSING_SITES.includes(site);
    const currentInvestment = sites[site];
    const capacity = housingSite ? 400 : building?.materials;
    if (!Number.isSafeInteger(materials) || materials < 1 || materials > 100 ||
        (!housingSite && !building) || currentInvestment + materials > capacity)
      return json({ error: 'investment' }, 400);
    if (building && houses < building.houses)
      return json({ error: 'locked' }, 409);

    const newInvestment = currentInvestment + materials;
    const newHouses = housingSite
      ? houses - Math.floor(currentInvestment / CITY_HOUSE_MATERIALS) +
        Math.floor(newInvestment / CITY_HOUSE_MATERIALS)
      : houses;
    let newCurrency = account.city_currency + (newHouses - houses);
    const buildingComplete = building && newInvestment === building.materials;
    if (buildingComplete) {
      if (newCurrency < 5) return json({ error: 'gloria' }, 409);
      newCurrency -= 5;
    }

    const progress = account.city_progress + materials;
    if (progress > 250000) return json({ error: 'investment' }, 400);
    if (progress * CITY_MATERIAL_PRICE > account.score)
      return json({ error: 'balance' }, 409);

    const updatedSites = { ...sites, [site]: newInvestment };
    const result = await env.DB.prepare(
      `UPDATE scores SET city_progress = ?1, city_currency = ?2, city_sites = ?3
       WHERE board = ?4 AND id = ?5 AND city_progress = ?6 AND city_currency = ?7
         AND city_sites = ?8 AND score >= ?1 * ?9`
    ).bind(progress, newCurrency, JSON.stringify(updatedSites), board, id, account.city_progress,
      account.city_currency, account.city_sites || '{}', CITY_MATERIAL_PRICE).run();
    if (!result.meta.changes) return json({ error: 'conflict' }, 409);
  } else {
    return json({ error: 'action' }, 400);
  }

  const updated = await env.DB.prepare(
    'SELECT city_progress, city_currency, city_sites FROM scores WHERE board = ? AND id = ?'
  ).bind(board, id).first();
  return json({ progress: updated.city_progress, currency: updated.city_currency, sites: citySitesFor(updated) });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === '/api/city') return cityApi(req, env, url);
    if (url.pathname !== '/api/lb') return new Response('Not found', { status: 404 });

    if (req.method === 'GET') {
      const board = (url.searchParams.get('board') || '').toLowerCase();
      if (!/^[a-z0-9_-]{1,24}$/.test(board)) return json({ error: 'board' }, 400);
      if (url.searchParams.has('name')) {
        const name = String(url.searchParams.get('name') || '')
          .replace(/[\u0000-\u001f<>&"]/g, '').trim().slice(0, 16);
        if (name.length < 2) return json({ error: 'name' }, 400);
        const account = await env.DB.prepare(
          'SELECT id, name, score FROM scores WHERE board = ? AND lower(name) = lower(?) ORDER BY score DESC, updated DESC LIMIT 1'
        ).bind(board, name).first();
        return json({ account: account || null });
      }
      const { results } = await env.DB
        .prepare('SELECT name, score FROM scores WHERE board = ? ORDER BY score DESC LIMIT 25')
        .bind(board).all();
      return json({ rows: results });
    }

    if (req.method === 'POST') {
      let b; try { b = await req.json(); } catch { return json({ error: 'json' }, 400); }
      const board = String(b.board || '').toLowerCase();
      const id = String(b.id || '');
      const name = String(b.name || '').replace(/[\u0000-\u001f<>&"]/g, '').trim().slice(0, 16);
      const score = Math.floor(Number(b.score));
      if (!/^[a-z0-9_-]{1,24}$/.test(board) || !/^[A-Za-z0-9]{8,40}$/.test(id) ||
          name.length < 2 || !Number.isFinite(score) || score < 0 || score > 1e6)
        return json({ error: 'invalid' }, 400);
      // Erst-Eintrag ok; spätere Sprünge > 500 Asse pro Meldung werden ignoriert (grober Schutz)
      await env.DB.prepare(
        `INSERT INTO scores (board, id, name, score, updated) VALUES (?1, ?2, ?3, ?4, ?5)
         ON CONFLICT (board, id) DO UPDATE SET name = ?3, score = ?4, updated = ?5
         WHERE ?4 >= scores.score AND ?4 <= scores.score + 500`
      ).bind(board, id, name, score, Date.now()).run();
      return json({ ok: true });
    }
    return new Response('Method not allowed', { status: 405 });
  }
};
