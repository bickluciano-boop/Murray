CREATE TABLE IF NOT EXISTS pld_config (owner_email TEXT PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 1, display_name TEXT NOT NULL, night_from INTEGER NOT NULL DEFAULT 21, night_to INTEGER NOT NULL DEFAULT 6, silence_night_min INTEGER NOT NULL DEFAULT 90, silence_day_min INTEGER NOT NULL DEFAULT 360, far_km REAL NOT NULL DEFAULT 3, battery_pct INTEGER NOT NULL DEFAULT 15, min_signals INTEGER NOT NULL DEFAULT 3, emergency_hours INTEGER NOT NULL DEFAULT 3, home_lat REAL, home_lng REAL, paused_until TEXT, updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS pld_referentes (id TEXT PRIMARY KEY, owner_email TEXT NOT NULL, name TEXT NOT NULL, email TEXT NOT NULL, token_hash TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, accepted_at TEXT, muted_until TEXT);
CREATE TABLE IF NOT EXISTS pld_log (id TEXT PRIMARY KEY, owner_email TEXT NOT NULL, referente_id TEXT, kind TEXT NOT NULL, detail TEXT, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS pld_checkins (id TEXT PRIMARY KEY, owner_email TEXT NOT NULL, referente_id TEXT NOT NULL, token_hash TEXT NOT NULL, created_at TEXT NOT NULL, answered_at TEXT);
CREATE INDEX IF NOT EXISTS pld_referentes_owner ON pld_referentes (owner_email);
CREATE INDEX IF NOT EXISTS pld_log_owner ON pld_log (owner_email, created_at);
CREATE INDEX IF NOT EXISTS pld_checkins_ref ON pld_checkins (referente_id, created_at);
