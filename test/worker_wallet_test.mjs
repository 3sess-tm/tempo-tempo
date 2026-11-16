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
          all: async () => ({
            results: [{
              name: this.account.name,
              score: this.account.score,
              city_progress: this.account.city_progress,
            }],
          }),
          run: async () => {
            const [board, id, name, score, balance] = values;
            const nextBalance = balance ?? this.account.balance;
            if (
              this.account.board !== board ||
              this.account.id !== id ||
              score < this.account.score ||
              score > this.account.score + 500 ||
              (balance !== null &&
                (balance > this.account.balance + score - this.account.score ||
                  balance > score - this.account.city_progress * 4))
            ) {
              return { meta: { changes: 0 } };
            }
            this.account.name = name;
            this.account.score = score;
            this.account.balance = nextBalance;
            return { meta: { changes: 1 } };
          },
        };
      },
    };
  }
}

function request(database, method, body, query = '') {
  const headers = body ? { 'Content-Type': 'application/json' } : undefined;
  return worker.fetch(
    new Request(`https://tempo.test/api/lb${query}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    }),
    { DB: database },
  );
}

test('wallet balance cannot be restored by relogging after city investment', async () => {
  const database = new MemoryDatabase({
    board: 'class-a',
    id: 'Account123',
    name: 'Livia',
    score: 1000,
    balance: 800,
    city_progress: 50,
    city_currency: 0,
    city_sites: '{}',
    updated: 1,
  });
  const payload = {
    board: 'class-a',
    id: 'Account123',
    name: 'Livia',
    score: 1000,
    balance: 1000,
  };

  const staleSync = await request(database, 'POST', payload);
  assert.equal(staleSync.status, 409);

  const login = await request(database, 'GET', null, '?board=class-a&name=Livia');
  const { account } = await login.json();
  assert.equal(account.balance, 800);
  assert.equal(account.score, 1000);
  assert.equal(account.city_progress, 50);
});

test('earned increases can replenish balance only by the newly earned amount', async () => {
  const database = new MemoryDatabase({
    board: 'class-a',
    id: 'Account123',
    name: 'Livia',
    score: 1000,
    balance: 800,
    city_progress: 50,
    city_currency: 0,
    city_sites: '{}',
    updated: 1,
  });
  const body = {
    board: 'class-a',
    id: 'Account123',
    name: 'Livia',
    score: 1050,
    balance: 850,
  };

  const accepted = await request(database, 'POST', body);
  assert.equal(accepted.status, 200);
  assert.equal(database.account.balance, 850);

  const staleOrInflated = await request(database, 'POST', {
    ...body,
    balance: 851,
  });
  assert.equal(staleOrInflated.status, 409);
  assert.equal(database.account.balance, 850);
});

test('older clients can sync earned without overwriting the saved balance', async () => {
  const database = new MemoryDatabase({
    board: 'class-a',
    id: 'Account123',
    name: 'Livia',
    score: 1000,
    balance: 800,
    city_progress: 50,
    city_currency: 0,
    city_sites: '{}',
    updated: 1,
  });

  const response = await request(database, 'POST', {
    board: 'class-a',
    id: 'Account123',
    name: 'Livia',
    score: 1050,
  });

  assert.equal(response.status, 200);
  assert.equal(database.account.score, 1050);
  assert.equal(database.account.balance, 800);
});

test('leaderboard rows include city material progress', async () => {
  const database = new MemoryDatabase({
    board: 'class-a',
    id: 'Account123',
    name: 'Livia',
    score: 1000,
    balance: 800,
    city_progress: 50,
    city_currency: 0,
    city_sites: '{}',
    updated: 1,
  });

  const response = await request(database, 'GET', null, '?board=class-a');
  assert.deepEqual(await response.json(), {
    rows: [{ name: 'Livia', score: 1000, city_progress: 50 }],
  });
});
