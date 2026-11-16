import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../worker.js', import.meta.url), 'utf8');
const { default: worker } = await import(
  `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`
);

class MemoryDatabase {
  constructor(account) {
    this.account = { ...account };
  }

  prepare(query) {
    let values = [];
    return {
      bind: (...bound) => {
        values = bound;
        return {
          first: async () => ({ ...this.account }),
          run: async () => {
            const [
              progress,
              currency,
              sites,
              board,
              id,
              oldProgress,
              oldCurrency,
              oldSites,
              price,
            ] = values;
            if (
              this.account.board !== board ||
              this.account.id !== id ||
              this.account.city_progress !== oldProgress ||
              this.account.city_currency !== oldCurrency ||
              (this.account.city_sites || '{}') !== oldSites ||
              this.account.score < progress * price
            ) {
              return { meta: { changes: 0 } };
            }
            this.account.city_progress = progress;
            this.account.city_currency = currency;
            this.account.city_sites = sites;
            return { meta: { changes: 1 } };
          },
        };
      },
    };
  }
}

function request(database, method, body) {
  const request = new Request(
    'https://tempo.test/api/city?board=class-a&id=Account123',
    {
      method,
      headers: body ? { 'Content-Type': 'application/json' } : undefined,
      body: body ? JSON.stringify(body) : undefined,
    },
  );
  return worker.fetch(request, { DB: database });
}

async function invest(database, city, site, materials = 100) {
  const response = await request(database, 'POST', {
    action: 'invest',
    city,
    site,
    materials,
  });
  if (response.status !== 200) {
    assert.fail(`Investment failed: ${response.status} ${await response.text()}`);
  }
  return response.json();
}

async function buildCity(database, city, housingSites, buildings) {
  for (const site of housingSites.slice(0, 4)) {
    for (let index = 0; index < 4; index++) {
      await invest(database, city, site);
    }
  }
  for (const [buildingIndex, site] of buildings.entries()) {
    for (let index = 0; index <= buildingIndex; index++) {
      await invest(database, city, site);
    }
  }
}

test('city progress persists and unlocks Trier then Verona', async () => {
  const database = new MemoryDatabase({
    board: 'class-a',
    id: 'Account123',
    score: 100000,
    city_progress: 0,
    city_currency: 0,
    city_sites: '{}',
  });

  const initial = await request(database, 'GET');
  const initialWorld = await initial.json();
  assert.equal(initial.status, 200);
  assert.deepEqual(initialWorld.unlockedCities, ['rome']);

  const locked = await request(database, 'POST', {
    action: 'invest',
    city: 'trier',
    site: 'vicus-1',
    materials: 20,
  });
  assert.equal(locked.status, 409);

  await buildCity(
    database,
    'rome',
    ['insula-1', 'insula-2', 'insula-3', 'insula-4', 'insula-5'],
    ['forum', 'thermae', 'colosseum', 'circus', 'pantheon'],
  );
  let world = await (await request(database, 'GET')).json();
  assert.deepEqual(world.unlockedCities, ['rome', 'trier']);
  assert.equal(world.cities.rome.complete, true);
  assert.equal(world.currency, 55);
  assert.equal(world.cities.trier.progress, 0);

  await buildCity(
    database,
    'trier',
    ['vicus-1', 'vicus-2', 'vicus-3', 'vicus-4', 'vicus-5'],
    [
      'porta-nigra',
      'thermae-trier',
      'amphitheater',
      'basilica',
      'roemerbruecke',
    ],
  );
  world = await (await request(database, 'GET')).json();
  assert.deepEqual(world.unlockedCities, ['rome', 'trier', 'verona']);
  assert.equal(world.cities.trier.complete, true);
  assert.equal(world.cities.rome.sites.pantheon, 500);
  assert.equal(world.currency, 110);
  assert.equal(world.cities.rome.progress, 3100);
  assert.equal(world.cities.trier.progress, 3100);

  await invest(database, 'verona', 'borgo-1', 20);
  world = await (await request(database, 'GET')).json();
  assert.equal(world.cities.verona.sites['borgo-1'], 20);
  assert.equal(world.cities.rome.sites['insula-1'], 400);
});

test('legacy Rome site data is retained in the multi-city response', async () => {
  const legacySites = Object.fromEntries(
    [
      'insula-1',
      'insula-2',
      'insula-3',
      'insula-4',
      'insula-5',
      'forum',
      'thermae',
      'colosseum',
      'circus',
      'pantheon',
    ].map((site) => [site, 0]),
  );
  legacySites['insula-1'] = 40;
  const database = new MemoryDatabase({
    board: 'class-a',
    id: 'Account123',
    score: 1000,
    city_progress: 40,
    city_currency: 2,
    city_sites: JSON.stringify(legacySites),
  });

  const response = await request(database, 'GET');
  assert.equal(response.status, 200);
  const world = await response.json();
  assert.equal(world.cities.rome.sites['insula-1'], 40);
  assert.equal(world.cities.rome.sites.forum, 0);
  assert.deepEqual(world.unlockedCities, ['rome']);

  await invest(database, 'rome', 'insula-1', 10);
  const migrated = JSON.parse(database.account.city_sites);
  assert.equal(migrated.version, 1);
  assert.equal(migrated.cities.rome.sites['insula-1'], 50);
  assert.equal(migrated.cities.trier.sites['vicus-1'], 0);
});
