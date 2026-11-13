// Rangliste für "tempo, tempo" – Cloudflare Worker + D1 (Free-Plan reicht)
const json = (o, s = 200) => new Response(JSON.stringify(o), {
  status: s, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });

const CITY_MATERIAL_PRICE = 4;
const CITY_HOUSE_MATERIALS = 20;
const CITY_BUILDINGS = [
  { houses: 5, name: 'Forum Romanum' },
  { houses: 15, name: 'Thermen' },
  { houses: 30, name: 'Kolosseum' },
  { houses: 50, name: 'Circus Maximus' },
  { houses: 80, name: 'Pantheon' }
];

async function cityApi(req, env, url) {
  const board = (url.searchParams.get('board') || '').toLowerCase();
  const id = url.searchParams.get('id') || '';
  if (!/^[a-z0-9_-]{1,24}$/.test(board) || !/^[A-Za-z0-9]{8,40}$/.test(id))
    return json({ error: 'invalid account' }, 400);

  if (req.method !== 'GET' && req.method !== 'POST')
    return new Response('Method not allowed', { status: 405 });

  const account = await env.DB.prepare(
    'SELECT score, city_progress, city_currency FROM scores WHERE board = ? AND id = ?'
  ).bind(board, id).first();
  if (!account) return json({ error: 'account' }, 404);

  if (req.method === 'GET')
    return json({ progress: account.city_progress, currency: account.city_currency });

  let body;
  try { body = await req.json(); } catch { return json({ error: 'json' }, 400); }
  if (!body || typeof body !== 'object' || Array.isArray(body))
    return json({ error: 'invalid' }, 400);

  if (body.action === 'invest') {
    const progress = body.progress;
    if (!Number.isSafeInteger(progress) || progress < account.city_progress || progress > 250000)
      return json({ error: 'progress' }, 400);
    if (progress === account.city_progress)
      return json({ progress: account.city_progress, currency: account.city_currency });
    if (progress * CITY_MATERIAL_PRICE > account.score)
      return json({ error: 'balance' }, 409);

    const result = await env.DB.prepare(
      `UPDATE scores SET city_progress = ?1,
         city_currency = city_currency +
           (CAST(?1 / ?2 AS INTEGER) - CAST(city_progress / ?2 AS INTEGER))
       WHERE board = ?3 AND id = ?4 AND city_progress = ?5 AND score >= ?1 * ?6`
    ).bind(progress, CITY_HOUSE_MATERIALS, board, id, account.city_progress, CITY_MATERIAL_PRICE).run();
    if (!result.meta.changes) return json({ error: 'conflict' }, 409);
  } else if (body.action === 'building') {
    const index = body.index;
    const houses = Math.floor(account.city_progress / CITY_HOUSE_MATERIALS);
    const spent = houses - account.city_currency;
    const completed = Math.floor(spent / 5);
    const building = CITY_BUILDINGS[index];
    if (!Number.isSafeInteger(index) || !building || index !== completed ||
        houses < building.houses || account.city_currency < 5)
      return json({ error: 'locked' }, 409);

    const result = await env.DB.prepare(
      `UPDATE scores SET city_currency = city_currency - 5
       WHERE board = ?1 AND id = ?2 AND city_progress = ?3 AND city_currency = ?4`
    ).bind(board, id, account.city_progress, account.city_currency).run();
    if (!result.meta.changes) return json({ error: 'conflict' }, 409);
  } else {
    return json({ error: 'action' }, 400);
  }

  const updated = await env.DB.prepare(
    'SELECT city_progress, city_currency FROM scores WHERE board = ? AND id = ?'
  ).bind(board, id).first();
  return json({ progress: updated.city_progress, currency: updated.city_currency });
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
