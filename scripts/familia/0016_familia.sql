-- Familia y amigos (etapa A): invitar personas y ver su ubicacion en el mapa.
--
-- Cada fila es una persona de la familia de `owner_email` (el titular que invita).
-- Nace como invitacion con un codigo de 6 caracteres; cuando la persona lo escribe
-- en su app, `member_email` pasa a ser su cuenta y `status` queda en 'activo'.
-- Una misma cuenta puede estar en la familia de varios titulares.
CREATE TABLE IF NOT EXISTS family_members (
  id TEXT PRIMARY KEY,
  owner_email TEXT NOT NULL,
  member_email TEXT,
  name TEXT NOT NULL,
  role TEXT NOT NULL,
  status TEXT NOT NULL,
  invite_code TEXT,
  invite_expires_at TEXT,
  paused_until TEXT,
  created_at TEXT NOT NULL,
  joined_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_family_owner ON family_members(owner_email, status);
CREATE INDEX IF NOT EXISTS idx_family_member ON family_members(member_email, status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_family_code ON family_members(invite_code);
