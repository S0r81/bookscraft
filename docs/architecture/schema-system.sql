-- BooksCraft system file schema (specification).
-- One system file per installation: `system.bookscraft` in the platform data directory.
-- It holds who can sign in and which company files exist; accounting data never lives here.
-- Dialect and conventions: same as schema.sql (SQLite >= 3.45, STRICT, UUIDv7 text ids,
-- UTC timestamps 'YYYY-MM-DDTHH:MM:SS.sssZ'). The store crate applies it as system migration 0001.

CREATE TABLE schema_migrations (
    version     INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    checksum    TEXT NOT NULL CHECK (length(checksum) = 64),
    applied_at  TEXT NOT NULL CHECK (applied_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;

CREATE TABLE installation (
    id          TEXT PRIMARY KEY CHECK (length(id) = 36),
    singleton   INTEGER NOT NULL DEFAULT 1 UNIQUE CHECK (singleton = 1),
    mode        TEXT NOT NULL CHECK (mode IN ('desktop', 'server')),
    created_at  TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;

CREATE TABLE user (
    id             TEXT PRIMARY KEY CHECK (length(id) = 36),
    username       TEXT NOT NULL CHECK (length(username) BETWEEN 1 AND 100 AND username = lower(username)),
    display_name   TEXT NOT NULL CHECK (length(display_name) BETWEEN 1 AND 200),
    email          TEXT,
    kind           TEXT NOT NULL CHECK (kind IN ('local', 'os', 'oidc')),  -- 'os' = desktop profile user
    password_hash  TEXT,                                                    -- argon2id PHC string
    oidc_issuer    TEXT,
    oidc_subject   TEXT,
    is_disabled    INTEGER NOT NULL DEFAULT 0 CHECK (is_disabled IN (0, 1)),
    version        INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at     TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at     TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z'),
    last_login_at  TEXT CHECK (last_login_at IS NULL OR last_login_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK (kind <> 'local' OR password_hash IS NOT NULL),
    CHECK ((kind = 'oidc') = (oidc_issuer IS NOT NULL AND oidc_subject IS NOT NULL))
) STRICT;
CREATE UNIQUE INDEX user_username_uq ON user(username);
CREATE UNIQUE INDEX user_oidc_uq ON user(oidc_issuer, oidc_subject) WHERE kind = 'oidc';

CREATE TABLE company_registry (
    id              TEXT PRIMARY KEY CHECK (length(id) = 36),   -- equals company.id inside the file
    name            TEXT NOT NULL,
    file_path       TEXT NOT NULL,                               -- absolute, platform-native
    created_at      TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    last_opened_at  TEXT CHECK (last_opened_at IS NULL OR last_opened_at GLOB '????-??-??T??:??:??.???Z'),
    is_archived     INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1))
) STRICT;
-- Case-insensitive so behaviour matches on Windows and macOS default filesystems.
CREATE UNIQUE INDEX company_registry_path_uq ON company_registry(file_path COLLATE NOCASE);

CREATE TABLE membership (
    user_id     TEXT NOT NULL REFERENCES user(id),
    company_id  TEXT NOT NULL REFERENCES company_registry(id),
    role        TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'bookkeeper', 'accountant', 'viewer')),
    created_at  TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    PRIMARY KEY (user_id, company_id)
) STRICT;

CREATE TABLE session (
    id            TEXT PRIMARY KEY CHECK (length(id) = 36),
    token_sha256  TEXT NOT NULL UNIQUE CHECK (length(token_sha256) = 64),
    user_id       TEXT NOT NULL REFERENCES user(id),
    created_at    TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    expires_at    TEXT NOT NULL CHECK (expires_at GLOB '????-??-??T??:??:??.???Z'),
    last_seen_at  TEXT NOT NULL CHECK (last_seen_at GLOB '????-??-??T??:??:??.???Z'),
    revoked_at    TEXT CHECK (revoked_at IS NULL OR revoked_at GLOB '????-??-??T??:??:??.???Z'),
    user_agent    TEXT
) STRICT;
CREATE INDEX session_user_idx ON session(user_id);

CREATE TABLE api_token (
    id            TEXT PRIMARY KEY CHECK (length(id) = 36),
    user_id       TEXT NOT NULL REFERENCES user(id),       -- the person accountable for the token
    name          TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
    token_sha256  TEXT NOT NULL UNIQUE CHECK (length(token_sha256) = 64),
    prefix        TEXT NOT NULL CHECK (length(prefix) = 8),   -- shown in lists, e.g. 'bc_a1b2c'
    actor_type    TEXT NOT NULL CHECK (actor_type IN ('api', 'agent')),
    scopes_json   TEXT NOT NULL CHECK (json_valid(scopes_json) AND json_type(scopes_json) = 'array'),
    company_id    TEXT REFERENCES company_registry(id),    -- NULL = every company the user belongs to
    created_at    TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    expires_at    TEXT CHECK (expires_at IS NULL OR expires_at GLOB '????-??-??T??:??:??.???Z'),
    last_used_at  TEXT CHECK (last_used_at IS NULL OR last_used_at GLOB '????-??-??T??:??:??.???Z'),
    revoked_at    TEXT CHECK (revoked_at IS NULL OR revoked_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;
CREATE INDEX api_token_user_idx ON api_token(user_id);

-- In-process job queue (email sends, imports, exports, bank syncs, backups, verify runs).
CREATE TABLE job (
    id           TEXT PRIMARY KEY CHECK (length(id) = 36),
    company_id   TEXT REFERENCES company_registry(id),
    kind         TEXT NOT NULL CHECK (kind IN ('import', 'export', 'email_send', 'bank_sync', 'backup',
                                              'verify', 'reversing_entry')),
    status       TEXT NOT NULL CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'canceled')),
    payload_json TEXT NOT NULL CHECK (json_valid(payload_json)),
    result_json  TEXT CHECK (result_json IS NULL OR json_valid(result_json)),
    error        TEXT,
    attempts     INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    run_after    TEXT NOT NULL CHECK (run_after GLOB '????-??-??T??:??:??.???Z'),
    created_by   TEXT NOT NULL,
    created_at   TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    started_at   TEXT CHECK (started_at IS NULL OR started_at GLOB '????-??-??T??:??:??.???Z'),
    finished_at  TEXT CHECK (finished_at IS NULL OR finished_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;
CREATE INDEX job_queue_idx ON job(status, run_after);

-- Server-mode secrets, envelope-encrypted: a per-secret data key wrapped by the key-encryption key
-- from server configuration. Desktop secrets live in the OS keychain instead (platform crate).
CREATE TABLE secret (
    id           TEXT PRIMARY KEY CHECK (length(id) = 36),   -- the credential_ref other rows point at
    company_id   TEXT REFERENCES company_registry(id),
    purpose      TEXT NOT NULL CHECK (purpose IN ('bank_feed', 'qbo_oauth', 'smtp')),
    kek_version  INTEGER NOT NULL CHECK (kek_version >= 1),
    wrapped_dek  BLOB NOT NULL,
    nonce        BLOB NOT NULL,
    ciphertext   BLOB NOT NULL,
    created_at   TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    rotated_at   TEXT CHECK (rotated_at IS NULL OR rotated_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;

-- OAuth state for the QBO migrator (state + PKCE verifier), short-lived.
CREATE TABLE oauth_state (
    state          TEXT PRIMARY KEY CHECK (length(state) >= 32),
    company_id     TEXT NOT NULL REFERENCES company_registry(id),
    user_id        TEXT NOT NULL REFERENCES user(id),
    code_verifier  TEXT NOT NULL,
    created_at     TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    expires_at     TEXT NOT NULL CHECK (expires_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;

CREATE TABLE setting (
    key         TEXT PRIMARY KEY,
    value_json  TEXT NOT NULL CHECK (json_valid(value_json)),
    updated_at  TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;

-- System audit log: user, membership, token and company-registry changes. Same chain rules as
-- the company audit log (see schema.sql section 7).
CREATE TABLE audit_event (
    seq          INTEGER PRIMARY KEY,
    id           TEXT NOT NULL UNIQUE CHECK (length(id) = 36),
    occurred_at  TEXT NOT NULL CHECK (occurred_at GLOB '????-??-??T??:??:??.???Z'),
    actor_type   TEXT NOT NULL CHECK (actor_type IN ('user', 'api', 'agent')),
    actor_id     TEXT NOT NULL,
    actor_name   TEXT NOT NULL,
    via          TEXT NOT NULL CHECK (via IN ('ui', 'api', 'mcp', 'cli', 'import', 'job')),
    action       TEXT NOT NULL,
    entity_type  TEXT NOT NULL,
    entity_id    TEXT NOT NULL,
    before_json  TEXT CHECK (before_json IS NULL OR json_valid(before_json)),
    after_json   TEXT CHECK (after_json IS NULL OR json_valid(after_json)),
    reason       TEXT,
    request_id   TEXT,
    prev_hash    TEXT NOT NULL CHECK (length(prev_hash) = 64),
    hash         TEXT NOT NULL UNIQUE CHECK (length(hash) = 64)
) STRICT;
CREATE TRIGGER audit_event_append BEFORE INSERT ON audit_event
BEGIN
    SELECT RAISE(ABORT, 'audit.sequence_gap')
    WHERE NEW.seq IS NOT (SELECT coalesce(max(seq), 0) + 1 FROM audit_event);
    SELECT RAISE(ABORT, 'audit.chain_broken')
    WHERE NEW.prev_hash IS NOT coalesce(
            (SELECT hash FROM audit_event WHERE seq = NEW.seq - 1),
            '0000000000000000000000000000000000000000000000000000000000000000');
END;
CREATE TRIGGER audit_event_no_update BEFORE UPDATE ON audit_event
BEGIN SELECT RAISE(ABORT, 'audit.immutable'); END;
CREATE TRIGGER audit_event_no_delete BEFORE DELETE ON audit_event
BEGIN SELECT RAISE(ABORT, 'audit.immutable'); END;

CREATE TABLE idempotency_key (
    principal_id           TEXT NOT NULL,
    key                    TEXT NOT NULL CHECK (length(key) BETWEEN 8 AND 200),
    method                 TEXT NOT NULL,
    path                   TEXT NOT NULL,
    request_sha256         TEXT NOT NULL CHECK (length(request_sha256) = 64),
    state                  TEXT NOT NULL CHECK (state IN ('in_progress', 'completed')),
    response_status        INTEGER,
    response_headers_json  TEXT CHECK (response_headers_json IS NULL OR json_valid(response_headers_json)),
    response_body          BLOB,
    created_at             TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    expires_at             TEXT NOT NULL CHECK (expires_at GLOB '????-??-??T??:??:??.???Z'),
    PRIMARY KEY (principal_id, key),
    CHECK ((state = 'completed') = (response_status IS NOT NULL))
) STRICT;
