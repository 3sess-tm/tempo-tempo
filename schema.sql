CREATE TABLE IF NOT EXISTS scores (
  board   TEXT NOT NULL,
  id      TEXT NOT NULL,
  name    TEXT NOT NULL,
  score   INTEGER NOT NULL,
  updated INTEGER NOT NULL,
  PRIMARY KEY (board, id)
);
CREATE INDEX IF NOT EXISTS idx_board_score ON scores (board, score DESC);
