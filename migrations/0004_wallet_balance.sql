ALTER TABLE scores ADD COLUMN balance INTEGER NOT NULL DEFAULT 0;
UPDATE scores SET balance = MAX(0, score - city_progress * 4);
