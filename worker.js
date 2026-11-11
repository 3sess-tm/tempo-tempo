// Rangliste für "tempo, tempo" – Cloudflare Worker + D1 (Free-Plan reicht)
const json = (o, s = 200) => new Response(JSON.stringify(o), {
  status: s, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
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
