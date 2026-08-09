export const schemaSql = `
  PRAGMA foreign_keys = ON;

  CREATE TABLE IF NOT EXISTS people (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    relationship TEXT NOT NULL,
    initials TEXT NOT NULL,
    created_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    person_id TEXT NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    file_name TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    page_count INTEGER NOT NULL,
    status TEXT NOT NULL,
    issued_on TEXT,
    expires_on TEXT,
    created_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS extracted_fields (
    id TEXT PRIMARY KEY,
    document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    page_number INTEGER NOT NULL,
    field_key TEXT NOT NULL,
    label TEXT NOT NULL,
    value TEXT NOT NULL,
    confidence REAL NOT NULL CHECK(confidence >= 0 AND confidence <= 1),
    source_text TEXT NOT NULL,
    review_status TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS review_items (
    id TEXT PRIMARY KEY,
    field_id TEXT NOT NULL REFERENCES extracted_fields(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    created_at TEXT NOT NULL,
    resolved_at TEXT
  );

  CREATE INDEX IF NOT EXISTS documents_expires_on_idx ON documents(expires_on);
  CREATE INDEX IF NOT EXISTS documents_person_id_idx ON documents(person_id);
  CREATE INDEX IF NOT EXISTS extracted_fields_field_key_idx ON extracted_fields(field_key);
`;
