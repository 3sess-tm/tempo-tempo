// Rangliste für "tempo, tempo" – Cloudflare Worker + D1 (Free-Plan reicht)
const json = (o, s = 200) => new Response(JSON.stringify(o), {
  status: s, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });

const CITY_MATERIAL_PRICE = 4;
const CITY_HOUSE_MATERIALS = 20;
const CITY_ORDER = ['rome', 'trier', 'verona'];
const CITY_DEFINITIONS = {
  rome: {
    houses: ['insula-1', 'insula-2', 'insula-3', 'insula-4', 'insula-5'],
    buildings: [
      { id: 'forum', houses: 5, materials: 100 },
      { id: 'thermae', houses: 15, materials: 200 },
      { id: 'colosseum', houses: 30, materials: 300 },
      { id: 'circus', houses: 50, materials: 400 },
      { id: 'pantheon', houses: 80, materials: 500 }
    ]
  },
  trier: {
    houses: ['vicus-1', 'vicus-2', 'vicus-3', 'vicus-4', 'vicus-5'],
    buildings: [
      { id: 'porta-nigra', houses: 5, materials: 100 },
      { id: 'thermae-trier', houses: 15, materials: 200 },
      { id: 'amphitheater', houses: 30, materials: 300 },
      { id: 'basilica', houses: 50, materials: 400 },
      { id: 'roemerbruecke', houses: 80, materials: 500 }
    ]
  },
  verona: {
    houses: ['borgo-1', 'borgo-2', 'borgo-3', 'borgo-4', 'borgo-5'],
    buildings: [
      { id: 'arena', houses: 5, materials: 100 },
      { id: 'porta-borsari', houses: 15, materials: 200 },
      { id: 'teatro-romano', houses: 30, materials: 300 },
      { id: 'ponte-pietra', houses: 50, materials: 400 },
      { id: 'arco-gavi', houses: 80, materials: 500 }
    ]
  }
};

function citySiteIds(cityId) {
  const definition = CITY_DEFINITIONS[cityId];
  return [...definition.houses, ...definition.buildings.map(building => building.id)];
}

function emptyCitySites(cityId) {
  return Object.fromEntries(citySiteIds(cityId).map(id => [id, 0]));
}

function isValidCitySites(cityId, sites) {
  return sites && typeof sites === 'object' && !Array.isArray(sites) &&
    citySiteIds(cityId).every(id => {
      const limit = CITY_DEFINITIONS[cityId].houses.includes(id)
        ? 400
        : CITY_DEFINITIONS[cityId].buildings.find(building => building.id === id).materials;
      return Number.isSafeInteger(sites[id]) && sites[id] >= 0 && sites[id] <= limit;
    });
}

function legacyRomeSites(account, legacy) {
  if (isValidCitySites('rome', legacy)) return legacy;
  const sites = emptyCitySites('rome');
  let remaining = account.city_progress;
  for (const id of CITY_DEFINITIONS.rome.houses) {
    const investment = Math.min(remaining, 400);
    sites[id] = investment;
    remaining -= investment;
  }
  const legacyBuildings = Math.min(CITY_DEFINITIONS.rome.buildings.length,
    Math.floor((Math.floor(account.city_progress / CITY_HOUSE_MATERIALS) - account.city_currency) / 5));
  CITY_DEFINITIONS.rome.buildings.slice(0, Math.max(0, legacyBuildings))
    .forEach(building => { sites[building.id] = building.materials; });
  return sites;
}

function cityWorldFor(account) {
  let saved;
  try { saved = JSON.parse(account.city_sites || '{}'); } catch { saved = null; }
  if (saved && saved.version === 1) {
    if (!saved.cities || typeof saved.cities !== 'object' || Array.isArray(saved.cities))
      throw new Error('Stored city world has an invalid shape.');
    const cities = {};
    for (const cityId of CITY_ORDER) {
      const sites = saved.cities[cityId]?.sites;
      if (!isValidCitySites(cityId, sites))
        throw new Error(`Stored ${cityId} progress is invalid.`);
      cities[cityId] = { sites };
    }
    return { version: 1, cities };
  }
  return {
    version: 1,
    cities: {
      rome: { sites: legacyRomeSites(account, saved) },
      trier: { sites: emptyCitySites('trier') },
      verona: { sites: emptyCitySites('verona') }
    }
  };
}

function cityHouses(cityId, sites) {
  return CITY_DEFINITIONS[cityId].houses.reduce(
    (sum, site) => sum + Math.floor(sites[site] / CITY_HOUSE_MATERIALS), 0);
}

function cityComplete(cityId, sites) {
  return CITY_DEFINITIONS[cityId].buildings.every(
    building => sites[building.id] >= building.materials);
}

function unlockedCities(world) {
  const unlocked = ['rome'];
  for (let index = 1; index < CITY_ORDER.length; index++) {
    const previous = CITY_ORDER[index - 1];
    if (!cityComplete(previous, world.cities[previous].sites)) break;
    unlocked.push(CITY_ORDER[index]);
  }
  return unlocked;
}

function cityResponse(account, world) {
  const cities = {};
  for (const cityId of CITY_ORDER) {
    const sites = world.cities[cityId].sites;
    cities[cityId] = {
      progress: Object.values(sites).reduce((sum, value) => sum + value, 0),
      sites,
      complete: cityComplete(cityId, sites)
    };
  }
  return {
    progress: account.city_progress,
    currency: account.city_currency,
    balance: account.balance,
    earned: account.score,
    sites: cities.rome.sites,
    cities,
    unlockedCities: unlockedCities(world)
  };
}

async function cityApi(req, env, url) {
  const board = (url.searchParams.get('board') || '').toLowerCase();
  const id = url.searchParams.get('id') || '';
  if (!/^[a-z0-9_-]{1,24}$/.test(board) || !/^[A-Za-z0-9]{8,40}$/.test(id))
    return json({ error: 'invalid account' }, 400);

  if (req.method !== 'GET' && req.method !== 'POST')
    return new Response('Method not allowed', { status: 405 });

  const account = await env.DB.prepare(
    'SELECT score, balance, city_progress, city_currency, city_sites FROM scores WHERE board = ? AND id = ?'
  ).bind(board, id).first();
  if (!account) return json({ error: 'account' }, 404);
  const world = cityWorldFor(account);

  if (req.method === 'GET')
    return json(cityResponse(account, world));

  let body;
  try { body = await req.json(); } catch { return json({ error: 'json' }, 400); }
  if (!body || typeof body !== 'object' || Array.isArray(body))
    return json({ error: 'invalid' }, 400);

  if (body.action === 'invest') {
    const cityId = body.city;
    if (!CITY_ORDER.includes(cityId)) return json({ error: 'city' }, 400);
    if (!unlockedCities(world).includes(cityId)) return json({ error: 'city_locked' }, 409);
    const site = body.site;
    const materials = body.materials;
    const definition = CITY_DEFINITIONS[cityId];
    const sites = world.cities[cityId].sites;
    const building = definition.buildings.find(candidate => candidate.id === site);
    const housingSite = definition.houses.includes(site);
    const currentInvestment = sites[site];
    const capacity = housingSite ? 400 : building?.materials;
    if (!Number.isSafeInteger(materials) || materials < 1 || materials > 100 ||
        (!housingSite && !building) || currentInvestment + materials > capacity)
      return json({ error: 'investment' }, 400);
    const houses = cityHouses(cityId, sites);
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
    const newBalance = account.balance - materials * CITY_MATERIAL_PRICE;
    if (newBalance < 0) return json({ error: 'funds' }, 409);

    const updatedWorld = {
      ...world,
      cities: {
        ...world.cities,
        [cityId]: { sites: { ...sites, [site]: newInvestment } }
      }
    };
    const result = await env.DB.prepare(
      `UPDATE scores SET balance = ?1, city_progress = ?2, city_currency = ?3, city_sites = ?4
       WHERE board = ?5 AND id = ?6 AND balance = ?7 AND city_progress = ?8
         AND city_currency = ?9 AND city_sites = ?10`
    ).bind(newBalance, progress, newCurrency, JSON.stringify(updatedWorld), board, id,
      account.balance, account.city_progress, account.city_currency, account.city_sites || '{}').run();
    if (!result.meta.changes) return json({ error: 'conflict' }, 409);
  } else {
    return json({ error: 'action' }, 400);
  }

  const updated = await env.DB.prepare(
    'SELECT score, balance, city_progress, city_currency, city_sites FROM scores WHERE board = ? AND id = ?'
  ).bind(board, id).first();
  return json(cityResponse(updated, cityWorldFor(updated)));
}

export default {
  async fetch(req, env) {
      const ip = req.headers.get("CF-Connecting-IP") || "0.0.0.0";
      const { success } = await env.RATE_LIMITER.limit({ key: ip });
      if (!success) {
        return new Response("Too many requests", {
          status: 429,
          headers: { "Content-Type": "text/plain", "Retry-After": "60" }
        });
      }

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
          'SELECT id, name, score, balance, city_progress FROM scores WHERE board = ? AND lower(name) = lower(?) ORDER BY score DESC, updated DESC LIMIT 1'
        ).bind(board, name).first();
        return json({ account: account || null });
      }
      const { results } = await env.DB
        .prepare('SELECT name, score, city_progress FROM scores WHERE board = ? ORDER BY score DESC LIMIT 25')
        .bind(board).all();
      return json({ rows: results });
    }

    if (req.method === 'POST') {
      let b; try { b = await req.json(); } catch { return json({ error: 'json' }, 400); }
      if (!b || typeof b !== 'object' || Array.isArray(b))
        return json({ error: 'invalid' }, 400);
      const board = String(b.board || '').toLowerCase();
      const id = String(b.id || '');
      const name = String(b.name || '').replace(/[\u0000-\u001f<>&"]/g, '').trim().slice(0, 16);
      const score = Number(b.score);
      const hasBalance = Object.hasOwn(b, 'balance');
      const balance = hasBalance ? Number(b.balance) : null;
      if (!/^[a-z0-9_-]{1,24}$/.test(board) || !/^[A-Za-z0-9]{8,40}$/.test(id) ||
          name.length < 2 || !Number.isSafeInteger(score) || score < 0 || score > 1e6 ||
          (hasBalance && (!Number.isSafeInteger(balance) || balance < 0 || balance > score)))
        return json({ error: 'invalid' }, 400);
      const result = await env.DB.prepare(
        `INSERT INTO scores (board, id, name, score, balance, updated)
         VALUES (?1, ?2, ?3, ?4, COALESCE(?5, ?4), ?6)
         ON CONFLICT (board, id) DO UPDATE
         SET name = ?3, score = ?4,
             balance = CASE WHEN ?5 IS NULL THEN scores.balance ELSE ?5 END,
             updated = ?6
         WHERE ?4 >= scores.score AND ?4 <= scores.score + 500
           AND (?5 IS NULL OR
             (?5 <= scores.balance + (?4 - scores.score)
               AND ?5 <= ?4 - scores.city_progress * 4))`
      ).bind(board, id, name, score, balance, Date.now()).run();
      if (!result.meta.changes) return json({ error: 'conflict' }, 409);
      return json({ ok: true, score, balance });
    }
    return new Response('Method not allowed', { status: 405 });
  }
};
