CREATE TABLE IF NOT EXISTS scores (
  board   TEXT NOT NULL,
  id      TEXT NOT NULL,
  name    TEXT NOT NULL,
  score   INTEGER NOT NULL,
  updated INTEGER NOT NULL,
  city_progress  INTEGER NOT NULL DEFAULT 0,
  city_currency  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (board, id)
);
CREATE INDEX IF NOT EXISTS idx_board_score ON scores (board, score DESC);
