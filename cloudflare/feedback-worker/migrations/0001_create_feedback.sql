CREATE TABLE IF NOT EXISTS feedback (
  id TEXT PRIMARY KEY,
  received_day TEXT NOT NULL,
  created_day TEXT NOT NULL,
  app_version TEXT NOT NULL,
  locale TEXT NOT NULL,
  query TEXT NOT NULL,
  route_kind TEXT NOT NULL,
  tool TEXT,
  confidence REAL,
  chosen_tool TEXT,
  rating TEXT
);

CREATE INDEX IF NOT EXISTS feedback_received_day ON feedback (received_day);
CREATE INDEX IF NOT EXISTS feedback_rating ON feedback (rating);
