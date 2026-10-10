-- BooksCraft company file schema (specification).
-- Dialect: SQLite >= 3.45 (rusqlite "bundled"). Every table is STRICT.
-- One company = one file. The store crate applies this as migration 0001 and
-- keeps this file equal to the cumulative schema (store test `schema_matches_spec`).
--
-- Connection settings applied by the store on every open (not persisted here):
--   PRAGMA foreign_keys = ON;  PRAGMA journal_mode = WAL;  PRAGMA synchronous = FULL;
--   PRAGMA busy_timeout = 5000; PRAGMA trusted_schema = OFF;
--
-- Conventions (see DATA_MODEL.md section 1):
--   id columns      TEXT UUIDv7, lowercase, 36 chars.
--   dates           TEXT 'YYYY-MM-DD' (civil date, no time zone); CHECK (date(x) IS x).
--   timestamps      TEXT 'YYYY-MM-DDTHH:MM:SS.sssZ' (UTC).
--   money           INTEGER minor units of the row's currency; +debit / -credit in postings.
--   decimals        TEXT canonical decimal (qty, unit price, rates); never REAL or NUMERIC.
--   booleans        INTEGER 0/1.
--   JSON            TEXT with json_valid() CHECK.
--   Trigger errors  RAISE(ABORT, '<namespace>.<code>'); the code is the API error code.

-- ---------------------------------------------------------------------------
-- 1. Bookkeeping of the file itself
-- ---------------------------------------------------------------------------

CREATE TABLE schema_migrations (
    version     INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    checksum    TEXT NOT NULL CHECK (length(checksum) = 64),
    applied_at  TEXT NOT NULL CHECK (applied_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;

CREATE TABLE company (
    id                       TEXT PRIMARY KEY CHECK (length(id) = 36),
    singleton                INTEGER NOT NULL DEFAULT 1 UNIQUE CHECK (singleton = 1),
    name                     TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 200),
    legal_name               TEXT,
    base_currency            TEXT NOT NULL CHECK (length(base_currency) = 3 AND base_currency = upper(base_currency)),
    fiscal_year_start_month  INTEGER NOT NULL CHECK (fiscal_year_start_month BETWEEN 1 AND 12),
    time_zone                TEXT NOT NULL,             -- IANA name; only used to default "today"
    locale                   TEXT NOT NULL DEFAULT 'en-US',
    soft_locked_through      TEXT CHECK (soft_locked_through IS NULL OR date(soft_locked_through) IS soft_locked_through),
    hard_locked_through      TEXT CHECK (hard_locked_through IS NULL OR date(hard_locked_through) IS hard_locked_through),
    multi_currency_enabled   INTEGER NOT NULL DEFAULT 0 CHECK (multi_currency_enabled IN (0, 1)),
    address_json             TEXT CHECK (address_json IS NULL OR json_valid(address_json)),
    settings_json            TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(settings_json)),
    version                  INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at               TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at               TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK (hard_locked_through IS NULL OR soft_locked_through IS NULL OR hard_locked_through <= soft_locked_through)
) STRICT;

CREATE TABLE number_sequence (
    doc_type    TEXT PRIMARY KEY,
    prefix      TEXT NOT NULL DEFAULT '',
    next_value  INTEGER NOT NULL CHECK (next_value >= 1),
    padding     INTEGER NOT NULL DEFAULT 0 CHECK (padding BETWEEN 0 AND 12)
) STRICT;

-- ---------------------------------------------------------------------------
-- 2. Lists (master data)
-- ---------------------------------------------------------------------------

CREATE TABLE account (
    id           TEXT PRIMARY KEY CHECK (length(id) = 36),
    code         TEXT CHECK (code IS NULL OR length(code) BETWEEN 1 AND 20),
    name         TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 200),
    class        TEXT NOT NULL CHECK (class IN ('asset', 'liability', 'equity', 'income', 'expense')),
    subtype      TEXT NOT NULL,
    detail       TEXT,                                   -- free text, e.g. an imported QBO AccountSubType
    parent_id    TEXT REFERENCES account(id),
    currency     TEXT NOT NULL CHECK (length(currency) = 3 AND currency = upper(currency)),
    system_role  TEXT,
    description  TEXT,
    is_archived  INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version      INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at   TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at   TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK (parent_id IS NULL OR parent_id <> id),
    CHECK (
        (class = 'asset'     AND subtype IN ('bank', 'accounts_receivable', 'other_current_asset', 'fixed_asset', 'other_asset')) OR
        (class = 'liability' AND subtype IN ('accounts_payable', 'credit_card', 'other_current_liability', 'long_term_liability')) OR
        (class = 'equity'    AND subtype = 'equity') OR
        (class = 'income'    AND subtype IN ('income', 'other_income')) OR
        (class = 'expense'   AND subtype IN ('cost_of_sales', 'expense', 'other_expense'))
    ),
    CHECK (system_role IS NULL OR
        (system_role = 'accounts_receivable'    AND subtype = 'accounts_receivable') OR
        (system_role = 'accounts_payable'       AND subtype = 'accounts_payable') OR
        (system_role = 'undeposited_funds'      AND subtype = 'other_current_asset') OR
        (system_role = 'uncategorized_asset'    AND subtype = 'other_current_asset') OR
        (system_role = 'sales_tax_payable'      AND subtype = 'other_current_liability') OR
        (system_role = 'retained_earnings'      AND subtype = 'equity') OR
        (system_role = 'opening_balance_equity' AND subtype = 'equity') OR
        (system_role = 'uncategorized_income'   AND class = 'income') OR
        (system_role = 'discounts_given'        AND class = 'income') OR
        (system_role = 'uncategorized_expense'  AND class = 'expense') OR
        (system_role = 'rounding'               AND class = 'expense') OR
        (system_role = 'fx_gain_loss'           AND class IN ('income', 'expense'))
    )
) STRICT;
CREATE UNIQUE INDEX account_code_uq ON account(code) WHERE code IS NOT NULL;
CREATE UNIQUE INDEX account_name_uq ON account(coalesce(parent_id, ''), name COLLATE NOCASE);
CREATE UNIQUE INDEX account_singleton_role_uq ON account(system_role)
    WHERE system_role IS NOT NULL AND system_role <> 'sales_tax_payable';
CREATE INDEX account_parent_idx ON account(parent_id) WHERE parent_id IS NOT NULL;

CREATE TRIGGER account_parent_same_class_i BEFORE INSERT ON account
WHEN NEW.parent_id IS NOT NULL AND (SELECT class FROM account WHERE id = NEW.parent_id) IS NOT NEW.class
BEGIN SELECT RAISE(ABORT, 'books.account_parent_class_mismatch'); END;
CREATE TRIGGER account_parent_same_class_u BEFORE UPDATE OF parent_id, class ON account
WHEN NEW.parent_id IS NOT NULL AND (SELECT class FROM account WHERE id = NEW.parent_id) IS NOT NEW.class
BEGIN SELECT RAISE(ABORT, 'books.account_parent_class_mismatch'); END;

CREATE TABLE term (
    id                    TEXT PRIMARY KEY CHECK (length(id) = 36),
    name                  TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
    due_days              INTEGER CHECK (due_days IS NULL OR due_days >= 0),
    day_of_month_due      INTEGER CHECK (day_of_month_due IS NULL OR day_of_month_due BETWEEN 1 AND 31),
    due_next_month_days   INTEGER CHECK (due_next_month_days IS NULL OR due_next_month_days >= 0),
    discount_percent      TEXT CHECK (discount_percent IS NULL OR (
                              (discount_percent GLOB '[0-9]*' OR discount_percent GLOB '-[0-9]*') AND
                              discount_percent NOT GLOB '*[^0-9.-]*' AND discount_percent NOT GLOB '?*-*' AND
                              discount_percent NOT GLOB '*.*.*' AND discount_percent NOT GLOB '*.')),
    discount_days         INTEGER CHECK (discount_days IS NULL OR discount_days >= 0),
    is_archived           INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version               INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at            TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at            TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK ((due_days IS NOT NULL) <> (day_of_month_due IS NOT NULL))
) STRICT;
CREATE UNIQUE INDEX term_name_uq ON term(name COLLATE NOCASE);

CREATE TABLE payment_method (
    id           TEXT PRIMARY KEY CHECK (length(id) = 36),
    name         TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
    kind         TEXT NOT NULL CHECK (kind IN ('cash', 'check', 'card', 'bank_transfer', 'other')),
    is_archived  INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version      INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at   TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at   TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;
CREATE UNIQUE INDEX payment_method_name_uq ON payment_method(name COLLATE NOCASE);

CREATE TABLE tax_agency (
    id                    TEXT PRIMARY KEY CHECK (length(id) = 36),
    name                  TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 200),
    liability_account_id  TEXT NOT NULL UNIQUE REFERENCES account(id),
    registration_number   TEXT,
    filing_frequency      TEXT CHECK (filing_frequency IS NULL OR filing_frequency IN ('monthly', 'quarterly', 'annual')),
    is_archived           INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version               INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at            TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at            TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;
CREATE UNIQUE INDEX tax_agency_name_uq ON tax_agency(name COLLATE NOCASE);

CREATE TRIGGER tax_agency_liability_role_i BEFORE INSERT ON tax_agency
WHEN (SELECT system_role FROM account WHERE id = NEW.liability_account_id) IS NOT 'sales_tax_payable'
BEGIN SELECT RAISE(ABORT, 'books.tax_agency_account_role'); END;
CREATE TRIGGER tax_agency_liability_role_u BEFORE UPDATE OF liability_account_id ON tax_agency
WHEN (SELECT system_role FROM account WHERE id = NEW.liability_account_id) IS NOT 'sales_tax_payable'
BEGIN SELECT RAISE(ABORT, 'books.tax_agency_account_role'); END;

CREATE TABLE tax_rate (
    id            TEXT PRIMARY KEY CHECK (length(id) = 36),
    agency_id     TEXT NOT NULL REFERENCES tax_agency(id),
    name          TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 200),
    rate_percent  TEXT NOT NULL CHECK (
                      rate_percent GLOB '[0-9]*' AND rate_percent NOT GLOB '*[^0-9.]*' AND
                      rate_percent NOT GLOB '*.*.*' AND rate_percent NOT GLOB '*.'),
    is_archived   INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version       INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at    TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at    TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;
CREATE UNIQUE INDEX tax_rate_name_uq ON tax_rate(agency_id, name COLLATE NOCASE);

CREATE TABLE tax_code (
    id           TEXT PRIMARY KEY CHECK (length(id) = 36),
    name         TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 200),
    description  TEXT,
    is_archived  INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version      INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at   TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at   TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;
CREATE UNIQUE INDEX tax_code_name_uq ON tax_code(name COLLATE NOCASE);

CREATE TABLE tax_code_rate (
    tax_code_id  TEXT NOT NULL REFERENCES tax_code(id),
    tax_rate_id  TEXT NOT NULL REFERENCES tax_rate(id),
    sort_order   INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (tax_code_id, tax_rate_id)
) STRICT;

CREATE TABLE contact (
    id                     TEXT PRIMARY KEY CHECK (length(id) = 36),
    display_name           TEXT NOT NULL CHECK (length(display_name) BETWEEN 1 AND 200),
    company_name           TEXT,
    given_name             TEXT,
    family_name            TEXT,
    is_customer            INTEGER NOT NULL DEFAULT 0 CHECK (is_customer IN (0, 1)),
    is_vendor              INTEGER NOT NULL DEFAULT 0 CHECK (is_vendor IN (0, 1)),
    is_employee            INTEGER NOT NULL DEFAULT 0 CHECK (is_employee IN (0, 1)),
    parent_id              TEXT REFERENCES contact(id),  -- sub-customer / job
    email                  TEXT,
    phone                  TEXT,
    website                TEXT,
    billing_address_json   TEXT CHECK (billing_address_json IS NULL OR json_valid(billing_address_json)),
    shipping_address_json  TEXT CHECK (shipping_address_json IS NULL OR json_valid(shipping_address_json)),
    tax_id                 TEXT,                           -- shown masked in the UI
    is_1099                INTEGER NOT NULL DEFAULT 0 CHECK (is_1099 IN (0, 1)),
    is_taxable             INTEGER NOT NULL DEFAULT 1 CHECK (is_taxable IN (0, 1)),
    default_tax_code_id    TEXT REFERENCES tax_code(id),
    default_terms_id       TEXT REFERENCES term(id),
    currency               TEXT NOT NULL CHECK (length(currency) = 3 AND currency = upper(currency)),
    notes                  TEXT,
    is_archived            INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version                INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at             TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at             TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK (parent_id IS NULL OR parent_id <> id)
) STRICT;
CREATE UNIQUE INDEX contact_display_name_uq ON contact(display_name COLLATE NOCASE);
CREATE INDEX contact_parent_idx ON contact(parent_id) WHERE parent_id IS NOT NULL;

CREATE TABLE item (
    id                    TEXT PRIMARY KEY CHECK (length(id) = 36),
    name                  TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 200),
    sku                   TEXT,
    kind                  TEXT NOT NULL CHECK (kind IN ('service', 'non_inventory', 'inventory', 'bundle', 'category')),
    parent_id             TEXT REFERENCES item(id),      -- category hierarchy
    sales_description     TEXT,
    sales_price           TEXT CHECK (sales_price IS NULL OR (
                              (sales_price GLOB '[0-9]*' OR sales_price GLOB '-[0-9]*') AND
                              sales_price NOT GLOB '*[^0-9.-]*' AND sales_price NOT GLOB '?*-*' AND
                              sales_price NOT GLOB '*.*.*' AND sales_price NOT GLOB '*.')),
    income_account_id     TEXT REFERENCES account(id),
    purchase_description  TEXT,
    purchase_cost         TEXT CHECK (purchase_cost IS NULL OR (
                              (purchase_cost GLOB '[0-9]*' OR purchase_cost GLOB '-[0-9]*') AND
                              purchase_cost NOT GLOB '*[^0-9.-]*' AND purchase_cost NOT GLOB '?*-*' AND
                              purchase_cost NOT GLOB '*.*.*' AND purchase_cost NOT GLOB '*.')),
    expense_account_id    TEXT REFERENCES account(id),
    asset_account_id      TEXT REFERENCES account(id),   -- inventory items (imported; FIFO is later)
    is_taxable            INTEGER NOT NULL DEFAULT 1 CHECK (is_taxable IN (0, 1)),
    is_archived           INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version               INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at            TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at            TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK (parent_id IS NULL OR parent_id <> id),
    CHECK (kind IN ('category', 'bundle') OR income_account_id IS NOT NULL OR expense_account_id IS NOT NULL)
) STRICT;
CREATE UNIQUE INDEX item_name_uq ON item(coalesce(parent_id, ''), name COLLATE NOCASE);

CREATE TABLE bundle_component (
    bundle_item_id     TEXT NOT NULL REFERENCES item(id),
    component_item_id  TEXT NOT NULL REFERENCES item(id),
    qty                TEXT NOT NULL CHECK (
                           qty GLOB '[0-9]*' AND qty NOT GLOB '*[^0-9.]*' AND qty NOT GLOB '*.*.*' AND qty NOT GLOB '*.'),
    sort_order         INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (bundle_item_id, component_item_id),
    CHECK (bundle_item_id <> component_item_id)
) STRICT;

CREATE TABLE dimension (
    id           TEXT PRIMARY KEY CHECK (length(id) = 36),
    name         TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
    preset       TEXT CHECK (preset IS NULL OR preset IN ('class', 'location', 'project')),
    applies_to   TEXT NOT NULL CHECK (applies_to IN ('line', 'document')),
    is_archived  INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version      INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at   TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at   TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;
CREATE UNIQUE INDEX dimension_name_uq ON dimension(name COLLATE NOCASE);
CREATE UNIQUE INDEX dimension_preset_uq ON dimension(preset) WHERE preset IS NOT NULL;

CREATE TABLE dimension_value (
    id            TEXT PRIMARY KEY CHECK (length(id) = 36),
    dimension_id  TEXT NOT NULL REFERENCES dimension(id),
    parent_id     TEXT REFERENCES dimension_value(id),
    name          TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 200),
    is_archived   INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version       INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at    TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at    TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK (parent_id IS NULL OR parent_id <> id)
) STRICT;
CREATE UNIQUE INDEX dimension_value_name_uq ON dimension_value(dimension_id, coalesce(parent_id, ''), name COLLATE NOCASE);

CREATE TRIGGER dimension_value_parent_same_dimension BEFORE INSERT ON dimension_value
WHEN NEW.parent_id IS NOT NULL AND (SELECT dimension_id FROM dimension_value WHERE id = NEW.parent_id) IS NOT NEW.dimension_id
BEGIN SELECT RAISE(ABORT, 'books.dimension_parent_mismatch'); END;

CREATE TABLE custom_field_def (
    id               TEXT PRIMARY KEY CHECK (length(id) = 36),
    entity_type      TEXT NOT NULL CHECK (entity_type IN ('contact', 'item', 'account', 'document')),
    doc_type         TEXT,                                -- NULL = every document type
    name             TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
    value_type       TEXT NOT NULL CHECK (value_type IN ('text', 'number', 'date', 'boolean', 'list')),
    options_json     TEXT CHECK (options_json IS NULL OR json_valid(options_json)),
    is_archived      INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version          INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at       TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at       TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;
CREATE UNIQUE INDEX custom_field_def_name_uq ON custom_field_def(entity_type, coalesce(doc_type, ''), name COLLATE NOCASE);

CREATE TABLE custom_field_value (
    def_id     TEXT NOT NULL REFERENCES custom_field_def(id),
    entity_id  TEXT NOT NULL,
    value      TEXT NOT NULL,
    PRIMARY KEY (def_id, entity_id)
) STRICT;

-- ---------------------------------------------------------------------------
-- 3. Source documents (mutable while draft; posted content is versioned by revision)
-- ---------------------------------------------------------------------------

CREATE TABLE document (
    id                     TEXT PRIMARY KEY CHECK (length(id) = 36),
    doc_type               TEXT NOT NULL CHECK (doc_type IN (
                               'estimate', 'invoice', 'sales_receipt', 'customer_payment', 'credit_memo',
                               'refund_receipt', 'customer_refund', 'bill', 'bill_payment', 'vendor_credit',
                               'expense', 'card_credit', 'vendor_refund', 'deposit', 'transfer',
                               'journal_entry', 'opening_balance')),
    status                 TEXT NOT NULL CHECK (status IN ('draft', 'posted', 'voided')),
    revision               INTEGER NOT NULL DEFAULT 0 CHECK (revision >= 0),   -- 0 = never posted
    number                 TEXT,                                               -- not unique (imports keep duplicates)
    doc_date               TEXT NOT NULL CHECK (date(doc_date) IS doc_date),
    due_date               TEXT CHECK (due_date IS NULL OR date(due_date) IS due_date),
    contact_id             TEXT REFERENCES contact(id),
    currency               TEXT NOT NULL CHECK (length(currency) = 3 AND currency = upper(currency)),
    fx_rate                TEXT CHECK (fx_rate IS NULL OR (
                               fx_rate GLOB '[0-9]*' AND fx_rate NOT GLOB '*[^0-9.]*' AND
                               fx_rate NOT GLOB '*.*.*' AND fx_rate NOT GLOB '*.')),  -- base units per 1 unit of currency
    ar_ap_account_id       TEXT REFERENCES account(id),
    money_account_id       TEXT REFERENCES account(id),   -- bank, card, undeposited funds or cash account
    payment_method_id      TEXT REFERENCES payment_method(id),
    reference_number       TEXT,                          -- check no., payment reference, vendor invoice no.
    terms_id               TEXT REFERENCES term(id),
    tax_code_id            TEXT REFERENCES tax_code(id),
    tax_mode               TEXT NOT NULL DEFAULT 'exclusive' CHECK (tax_mode IN ('exclusive', 'inclusive', 'none')),
    tax_after_discount     INTEGER NOT NULL DEFAULT 1 CHECK (tax_after_discount IN (0, 1)),
    discount_kind          TEXT CHECK (discount_kind IS NULL OR discount_kind IN ('percent', 'amount')),
    discount_value         TEXT CHECK (discount_value IS NULL OR (
                               discount_value GLOB '[0-9]*' AND discount_value NOT GLOB '*[^0-9.]*' AND
                               discount_value NOT GLOB '*.*.*' AND discount_value NOT GLOB '*.')),
    discount_account_id    TEXT REFERENCES account(id),
    subtotal_minor         INTEGER NOT NULL DEFAULT 0,
    discount_minor         INTEGER NOT NULL DEFAULT 0 CHECK (discount_minor >= 0),
    tax_minor              INTEGER NOT NULL DEFAULT 0 CHECK (tax_minor >= 0),
    total_minor            INTEGER NOT NULL CHECK (total_minor >= 0),
    memo                   TEXT,                          -- printed on the document
    private_note           TEXT,
    billing_address_json   TEXT CHECK (billing_address_json IS NULL OR json_valid(billing_address_json)),
    shipping_address_json  TEXT CHECK (shipping_address_json IS NULL OR json_valid(shipping_address_json)),
    estimate_status        TEXT CHECK (estimate_status IS NULL OR estimate_status IN ('pending', 'accepted', 'closed', 'rejected')),
    is_residual            INTEGER NOT NULL DEFAULT 0 CHECK (is_residual IN (0, 1)),  -- migration residual JE
    source                 TEXT NOT NULL CHECK (source IN ('ui', 'api', 'mcp', 'cli', 'import', 'job')),
    created_by_actor_type  TEXT NOT NULL CHECK (created_by_actor_type IN ('user', 'api', 'agent')),
    created_by_actor_id    TEXT NOT NULL,
    approved_by_user_id    TEXT,                          -- set when a draft from api/agent is approved
    approved_at            TEXT CHECK (approved_at IS NULL OR approved_at GLOB '????-??-??T??:??:??.???Z'),
    last_sent_at           TEXT CHECK (last_sent_at IS NULL OR last_sent_at GLOB '????-??-??T??:??:??.???Z'),
    voided_at              TEXT CHECK (voided_at IS NULL OR voided_at GLOB '????-??-??T??:??:??.???Z'),
    void_reason            TEXT,
    version                INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at             TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at             TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK ((status = 'draft') = (revision = 0)),
    CHECK ((status = 'voided') = (voided_at IS NOT NULL)),
    CHECK ((doc_type = 'estimate') = (estimate_status IS NOT NULL)),
    CHECK ((discount_kind IS NULL) = (discount_value IS NULL)),
    CHECK (tax_mode <> 'exclusive' OR total_minor = subtotal_minor - discount_minor + tax_minor),
    CHECK (tax_mode = 'exclusive' OR total_minor = subtotal_minor - discount_minor),
    CHECK (tax_mode <> 'none' OR tax_minor = 0),
    CHECK (doc_type NOT IN ('estimate', 'invoice', 'credit_memo', 'customer_payment', 'customer_refund',
                            'bill', 'vendor_credit', 'bill_payment', 'vendor_refund') OR contact_id IS NOT NULL),
    CHECK ((doc_type IN ('invoice', 'credit_memo', 'customer_payment', 'customer_refund',
                         'bill', 'vendor_credit', 'bill_payment', 'vendor_refund')) = (ar_ap_account_id IS NOT NULL)),
    CHECK (doc_type NOT IN ('sales_receipt', 'refund_receipt', 'customer_refund', 'vendor_refund',
                            'expense', 'card_credit', 'deposit', 'transfer') OR money_account_id IS NOT NULL),
    CHECK (doc_type NOT IN ('customer_payment', 'bill_payment') OR total_minor = 0 OR money_account_id IS NOT NULL),
    CHECK (doc_type NOT IN ('invoice', 'estimate', 'credit_memo', 'bill', 'vendor_credit',
                            'journal_entry', 'opening_balance') OR money_account_id IS NULL),
    CHECK (is_residual = 0 OR doc_type = 'journal_entry')
) STRICT;
CREATE INDEX document_type_date_idx ON document(doc_type, doc_date);
CREATE INDEX document_contact_idx ON document(contact_id, doc_date) WHERE contact_id IS NOT NULL;
CREATE INDEX document_number_idx ON document(doc_type, number) WHERE number IS NOT NULL;
CREATE INDEX document_status_idx ON document(status) WHERE status = 'draft';

-- Status machine: draft -> posted -> voided; posted documents may be reposted (revision + 1).
-- One trigger with ordered checks so the reported error code is deterministic.
CREATE TRIGGER document_state_machine BEFORE UPDATE OF status, revision ON document
BEGIN
    SELECT RAISE(ABORT, 'document.invalid_status_transition')
    WHERE OLD.status = 'voided' OR (OLD.status = 'posted' AND NEW.status = 'draft');
    SELECT RAISE(ABORT, 'document.invalid_revision')
    WHERE NEW.revision < OLD.revision OR NEW.revision > OLD.revision + 1;
END;

-- Ledger-relevant header fields of a posted document change only together with a repost (revision + 1).
CREATE TRIGGER document_posted_financial_fields BEFORE UPDATE ON document
WHEN OLD.status = 'posted' AND NEW.revision = OLD.revision AND (
       NEW.doc_type IS NOT OLD.doc_type OR NEW.doc_date IS NOT OLD.doc_date OR
       NEW.contact_id IS NOT OLD.contact_id OR NEW.currency IS NOT OLD.currency OR
       NEW.fx_rate IS NOT OLD.fx_rate OR NEW.ar_ap_account_id IS NOT OLD.ar_ap_account_id OR
       NEW.money_account_id IS NOT OLD.money_account_id OR NEW.tax_code_id IS NOT OLD.tax_code_id OR
       NEW.tax_mode IS NOT OLD.tax_mode OR NEW.tax_after_discount IS NOT OLD.tax_after_discount OR
       NEW.discount_kind IS NOT OLD.discount_kind OR NEW.discount_value IS NOT OLD.discount_value OR
       NEW.discount_account_id IS NOT OLD.discount_account_id OR NEW.subtotal_minor IS NOT OLD.subtotal_minor OR
       NEW.discount_minor IS NOT OLD.discount_minor OR NEW.tax_minor IS NOT OLD.tax_minor OR
       NEW.total_minor IS NOT OLD.total_minor)
BEGIN SELECT RAISE(ABORT, 'document.posted_requires_repost'); END;

CREATE TRIGGER document_voided_frozen BEFORE UPDATE ON document
WHEN OLD.status = 'voided'
BEGIN SELECT RAISE(ABORT, 'document.voided_immutable'); END;

CREATE TRIGGER document_delete_draft_only BEFORE DELETE ON document
WHEN OLD.status <> 'draft'
BEGIN SELECT RAISE(ABORT, 'document.delete_requires_draft'); END;

CREATE TRIGGER document_ar_ap_account_subtype_i BEFORE INSERT ON document
WHEN NEW.ar_ap_account_id IS NOT NULL AND (SELECT subtype FROM account WHERE id = NEW.ar_ap_account_id) IS NOT
     (CASE WHEN NEW.doc_type IN ('invoice', 'credit_memo', 'customer_payment', 'customer_refund')
           THEN 'accounts_receivable' ELSE 'accounts_payable' END)
BEGIN SELECT RAISE(ABORT, 'document.ar_ap_account_subtype'); END;
CREATE TRIGGER document_ar_ap_account_subtype_u BEFORE UPDATE OF ar_ap_account_id ON document
WHEN NEW.ar_ap_account_id IS NOT NULL AND (SELECT subtype FROM account WHERE id = NEW.ar_ap_account_id) IS NOT
     (CASE WHEN NEW.doc_type IN ('invoice', 'credit_memo', 'customer_payment', 'customer_refund')
           THEN 'accounts_receivable' ELSE 'accounts_payable' END)
BEGIN SELECT RAISE(ABORT, 'document.ar_ap_account_subtype'); END;

-- Lines are keyed by (document, revision). Revision 0 = draft working copy (mutable).
-- Lines of revision >= 1 are a posted snapshot and never change.
CREATE TABLE document_line (
    document_id         TEXT NOT NULL REFERENCES document(id) ON DELETE CASCADE,
    revision            INTEGER NOT NULL CHECK (revision >= 0),
    line_no             INTEGER NOT NULL CHECK (line_no >= 1),
    line_key            TEXT NOT NULL CHECK (length(line_key) = 36),   -- stable across revisions
    kind                TEXT NOT NULL CHECK (kind IN ('item', 'account', 'description', 'subtotal', 'group', 'deposit_source')),
    item_id             TEXT REFERENCES item(id),
    account_id          TEXT REFERENCES account(id),
    contact_id          TEXT REFERENCES contact(id),
    description         TEXT,
    qty                 TEXT CHECK (qty IS NULL OR (
                            (qty GLOB '[0-9]*' OR qty GLOB '-[0-9]*') AND qty NOT GLOB '*[^0-9.-]*' AND
                            qty NOT GLOB '?*-*' AND qty NOT GLOB '*.*.*' AND qty NOT GLOB '*.')),
    unit_price          TEXT CHECK (unit_price IS NULL OR (
                            (unit_price GLOB '[0-9]*' OR unit_price GLOB '-[0-9]*') AND unit_price NOT GLOB '*[^0-9.-]*' AND
                            unit_price NOT GLOB '?*-*' AND unit_price NOT GLOB '*.*.*' AND unit_price NOT GLOB '*.')),
    amount_minor        INTEGER NOT NULL DEFAULT 0,   -- commercial lines: signed line amount; JE lines: +debit / -credit
    is_taxable          INTEGER NOT NULL DEFAULT 0 CHECK (is_taxable IN (0, 1)),
    tax_minor           INTEGER NOT NULL DEFAULT 0,   -- tax inside the amount (tax-inclusive documents only)
    service_date        TEXT CHECK (service_date IS NULL OR date(service_date) IS service_date),
    source_document_id  TEXT REFERENCES document(id), -- deposit_source lines: the payment/receipt held in undeposited funds
    group_line_no       INTEGER,                       -- bundle component lines point at their group line
    PRIMARY KEY (document_id, revision, line_no),
    UNIQUE (document_id, revision, line_key),
    CHECK (kind <> 'item' OR item_id IS NOT NULL),
    CHECK (kind <> 'account' OR account_id IS NOT NULL),
    CHECK ((kind = 'deposit_source') = (source_document_id IS NOT NULL)),
    CHECK (kind NOT IN ('description', 'subtotal') OR amount_minor = 0)   -- group lines carry a display total only
) STRICT;
CREATE INDEX document_line_source_idx ON document_line(source_document_id) WHERE source_document_id IS NOT NULL;
CREATE INDEX document_line_item_idx ON document_line(item_id) WHERE item_id IS NOT NULL;

CREATE TRIGGER document_line_snapshot_insert BEFORE INSERT ON document_line
WHEN NEW.revision >= 1 AND NEW.revision <= (SELECT revision FROM document WHERE id = NEW.document_id)
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;
CREATE TRIGGER document_line_snapshot_update BEFORE UPDATE ON document_line
WHEN OLD.revision >= 1
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;
CREATE TRIGGER document_line_snapshot_delete BEFORE DELETE ON document_line
WHEN OLD.revision >= 1
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;

-- A payment or receipt sits in at most one posted deposit.
CREATE TRIGGER document_line_single_deposit BEFORE INSERT ON document_line
WHEN NEW.kind = 'deposit_source' AND EXISTS (
    SELECT 1 FROM document_line dl JOIN document d ON d.id = dl.document_id
    WHERE dl.kind = 'deposit_source' AND dl.source_document_id = NEW.source_document_id
      AND d.status = 'posted' AND dl.revision = d.revision AND dl.document_id <> NEW.document_id)
BEGIN SELECT RAISE(ABORT, 'banking.already_deposited'); END;

CREATE TABLE document_tax_line (
    document_id         TEXT NOT NULL REFERENCES document(id) ON DELETE CASCADE,
    revision            INTEGER NOT NULL CHECK (revision >= 0),
    tax_rate_id         TEXT NOT NULL REFERENCES tax_rate(id),
    agency_id           TEXT NOT NULL REFERENCES tax_agency(id),
    taxable_base_minor  INTEGER NOT NULL,
    tax_minor           INTEGER NOT NULL,
    PRIMARY KEY (document_id, revision, tax_rate_id)
) STRICT;
CREATE TRIGGER document_tax_line_snapshot_insert BEFORE INSERT ON document_tax_line
WHEN NEW.revision >= 1 AND NEW.revision <= (SELECT revision FROM document WHERE id = NEW.document_id)
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;
CREATE TRIGGER document_tax_line_snapshot_update BEFORE UPDATE ON document_tax_line
WHEN OLD.revision >= 1
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;
CREATE TRIGGER document_tax_line_snapshot_delete BEFORE DELETE ON document_tax_line
WHEN OLD.revision >= 1
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;

CREATE TABLE document_dimension (
    document_id   TEXT NOT NULL REFERENCES document(id) ON DELETE CASCADE,
    revision      INTEGER NOT NULL CHECK (revision >= 0),
    dimension_id  TEXT NOT NULL REFERENCES dimension(id),
    value_id      TEXT NOT NULL REFERENCES dimension_value(id),
    PRIMARY KEY (document_id, revision, dimension_id)
) STRICT;

CREATE TABLE document_line_dimension (
    document_id   TEXT NOT NULL,
    revision      INTEGER NOT NULL CHECK (revision >= 0),
    line_no       INTEGER NOT NULL,
    dimension_id  TEXT NOT NULL REFERENCES dimension(id),
    value_id      TEXT NOT NULL REFERENCES dimension_value(id),
    PRIMARY KEY (document_id, revision, line_no, dimension_id),
    FOREIGN KEY (document_id, revision, line_no) REFERENCES document_line(document_id, revision, line_no) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER document_dimension_snapshot_insert BEFORE INSERT ON document_dimension
WHEN NEW.revision >= 1 AND NEW.revision <= (SELECT revision FROM document WHERE id = NEW.document_id)
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;
CREATE TRIGGER document_dimension_snapshot_change BEFORE UPDATE ON document_dimension
WHEN OLD.revision >= 1
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;
CREATE TRIGGER document_dimension_snapshot_delete BEFORE DELETE ON document_dimension
WHEN OLD.revision >= 1
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;
CREATE TRIGGER document_line_dimension_snapshot_insert BEFORE INSERT ON document_line_dimension
WHEN NEW.revision >= 1 AND NEW.revision <= (SELECT revision FROM document WHERE id = NEW.document_id)
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;
CREATE TRIGGER document_line_dimension_snapshot_change BEFORE UPDATE ON document_line_dimension
WHEN OLD.revision >= 1
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;
CREATE TRIGGER document_line_dimension_snapshot_delete BEFORE DELETE ON document_line_dimension
WHEN OLD.revision >= 1
BEGIN SELECT RAISE(ABORT, 'document.line_immutable'); END;

-- AR/AP application graph (QBO LinkedTxn). Rows are immutable. A settlement is active while its
-- event document is posted and still at event_revision (view active_settlement).
CREATE TABLE settlement (
    id                  TEXT PRIMARY KEY CHECK (length(id) = 36),
    event_document_id   TEXT NOT NULL REFERENCES document(id),
    event_revision      INTEGER NOT NULL CHECK (event_revision >= 1),
    ledger              TEXT NOT NULL CHECK (ledger IN ('ar', 'ap')),
    account_id          TEXT NOT NULL REFERENCES account(id),
    contact_id          TEXT NOT NULL REFERENCES contact(id),
    charge_document_id  TEXT NOT NULL REFERENCES document(id),  -- raises the balance: invoice, bill, refund to customer...
    credit_document_id  TEXT NOT NULL REFERENCES document(id),  -- lowers the balance: payment, credit memo, vendor credit...
    amount_minor        INTEGER NOT NULL CHECK (amount_minor > 0),
    currency            TEXT NOT NULL CHECK (length(currency) = 3 AND currency = upper(currency)),
    settled_on          TEXT NOT NULL CHECK (date(settled_on) IS settled_on),
    created_at          TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK (charge_document_id <> credit_document_id)
) STRICT;
CREATE INDEX settlement_charge_idx ON settlement(charge_document_id);
CREATE INDEX settlement_credit_idx ON settlement(credit_document_id);
CREATE INDEX settlement_event_idx ON settlement(event_document_id, event_revision);

CREATE TRIGGER settlement_revision_current BEFORE INSERT ON settlement
WHEN NEW.event_revision < (SELECT revision FROM document WHERE id = NEW.event_document_id)
BEGIN SELECT RAISE(ABORT, 'settlement.stale_revision'); END;
-- Hard-locked periods are immutable for settlements too, including those of documents that write
-- no journal entry (zero-amount payments). Soft locks for those are checked by the service.
CREATE TRIGGER settlement_hard_lock BEFORE INSERT ON settlement
WHEN NEW.settled_on <= coalesce((SELECT hard_locked_through FROM company), '0000-01-01')
BEGIN SELECT RAISE(ABORT, 'period.hard_locked'); END;
CREATE TRIGGER settlement_no_update BEFORE UPDATE ON settlement
BEGIN SELECT RAISE(ABORT, 'settlement.immutable'); END;
CREATE TRIGGER settlement_no_delete BEFORE DELETE ON settlement
BEGIN SELECT RAISE(ABORT, 'settlement.immutable'); END;

-- Non-settlement links between documents: an invoice converted from an estimate, and a reversing
-- journal entry that reverses another (LEDGER_SPEC section 4.16). More types in v1.
CREATE TABLE document_link (
    id                TEXT PRIMARY KEY CHECK (length(id) = 36),
    from_document_id  TEXT NOT NULL REFERENCES document(id),
    to_document_id    TEXT NOT NULL REFERENCES document(id),
    link_type         TEXT NOT NULL CHECK (link_type IN ('converted_from', 'reverses')),
    amount_minor      INTEGER,
    created_at        TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK (from_document_id <> to_document_id),
    UNIQUE (from_document_id, to_document_id, link_type)
) STRICT;

-- ---------------------------------------------------------------------------
-- 4. Ledger (append-only)
-- ---------------------------------------------------------------------------

CREATE TABLE journal_entry (
    id                 TEXT PRIMARY KEY CHECK (length(id) = 36),
    document_id        TEXT NOT NULL REFERENCES document(id),
    document_revision  INTEGER NOT NULL CHECK (document_revision >= 1),  -- the revision this entry posts or reverses
    kind               TEXT NOT NULL CHECK (kind IN ('original', 'reversal')),
    reverses_entry_id  TEXT UNIQUE REFERENCES journal_entry(id),
    entry_date         TEXT NOT NULL CHECK (date(entry_date) IS entry_date),
    rules_version      TEXT NOT NULL CHECK (length(rules_version) BETWEEN 3 AND 64),  -- e.g. 'invoice@1'
    state              TEXT NOT NULL CHECK (state IN ('open', 'final')),
    content_hash       TEXT CHECK (content_hash IS NULL OR length(content_hash) = 64),
    created_at         TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    finalized_at       TEXT CHECK (finalized_at IS NULL OR finalized_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK ((kind = 'reversal') = (reverses_entry_id IS NOT NULL)),
    CHECK ((state = 'final') = (finalized_at IS NOT NULL)),
    CHECK ((state = 'final') = (content_hash IS NOT NULL))
) STRICT;
CREATE UNIQUE INDEX journal_entry_doc_rev_kind_uq ON journal_entry(document_id, document_revision, kind);
CREATE INDEX journal_entry_date_idx ON journal_entry(entry_date) WHERE state = 'final';

CREATE TABLE posting (
    id                 TEXT PRIMARY KEY CHECK (length(id) = 36),
    journal_entry_id   TEXT NOT NULL REFERENCES journal_entry(id),
    line_no            INTEGER NOT NULL CHECK (line_no >= 1),
    line_key           TEXT NOT NULL CHECK (length(line_key) BETWEEN 1 AND 120),
    account_id         TEXT NOT NULL REFERENCES account(id),
    contact_id         TEXT REFERENCES contact(id),
    currency           TEXT NOT NULL CHECK (length(currency) = 3 AND currency = upper(currency)),
    amount_minor       INTEGER NOT NULL,       -- transaction currency, +debit / -credit
    base_amount_minor  INTEGER NOT NULL,       -- company base currency, +debit / -credit
    memo               TEXT,
    UNIQUE (journal_entry_id, line_no),
    UNIQUE (journal_entry_id, line_key),
    CHECK (amount_minor <> 0 OR base_amount_minor <> 0),
    CHECK ((amount_minor >= 0 AND base_amount_minor >= 0) OR (amount_minor <= 0 AND base_amount_minor <= 0))
) STRICT;
CREATE INDEX posting_account_idx ON posting(account_id, journal_entry_id);
CREATE INDEX posting_contact_idx ON posting(contact_id) WHERE contact_id IS NOT NULL;
CREATE INDEX posting_line_key_idx ON posting(account_id, line_key);

CREATE TABLE posting_dimension (
    posting_id    TEXT NOT NULL REFERENCES posting(id),
    dimension_id  TEXT NOT NULL REFERENCES dimension(id),
    value_id      TEXT NOT NULL REFERENCES dimension_value(id),
    PRIMARY KEY (posting_id, dimension_id)
) STRICT;
CREATE INDEX posting_dimension_value_idx ON posting_dimension(value_id);

CREATE TABLE lock_override (
    id                TEXT PRIMARY KEY CHECK (length(id) = 36),
    journal_entry_id  TEXT NOT NULL UNIQUE REFERENCES journal_entry(id),
    reason            TEXT NOT NULL CHECK (length(trim(reason)) >= 5),
    actor_id          TEXT NOT NULL,
    created_at        TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;
CREATE TRIGGER lock_override_no_update BEFORE UPDATE ON lock_override
BEGIN SELECT RAISE(ABORT, 'period.override_immutable'); END;
CREATE TRIGGER lock_override_no_delete BEFORE DELETE ON lock_override
BEGIN SELECT RAISE(ABORT, 'period.override_immutable'); END;

-- Entries are created 'open', receive their postings, then are finalized in the same transaction.
CREATE TRIGGER journal_entry_insert_open BEFORE INSERT ON journal_entry
WHEN NEW.state <> 'open' OR NEW.finalized_at IS NOT NULL OR NEW.content_hash IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'ledger.entry_must_start_open'); END;

CREATE TRIGGER journal_entry_finalize BEFORE UPDATE ON journal_entry
WHEN OLD.state = 'open' AND NEW.state = 'final'
BEGIN
    SELECT RAISE(ABORT, 'ledger.entry_fields_changed')
    WHERE NEW.id IS NOT OLD.id OR NEW.document_id IS NOT OLD.document_id
       OR NEW.document_revision IS NOT OLD.document_revision OR NEW.kind IS NOT OLD.kind
       OR NEW.reverses_entry_id IS NOT OLD.reverses_entry_id OR NEW.entry_date IS NOT OLD.entry_date
       OR NEW.rules_version IS NOT OLD.rules_version OR NEW.created_at IS NOT OLD.created_at;
    SELECT RAISE(ABORT, 'ledger.too_few_lines')
    WHERE (SELECT count(*) FROM posting WHERE journal_entry_id = NEW.id) < 2;
    SELECT RAISE(ABORT, 'ledger.unbalanced')
    WHERE (SELECT sum(base_amount_minor) FROM posting WHERE journal_entry_id = NEW.id) <> 0;
    SELECT RAISE(ABORT, 'ledger.unbalanced_currency')
    WHERE (SELECT count(DISTINCT currency) FROM posting WHERE journal_entry_id = NEW.id) = 1
      AND (SELECT sum(amount_minor) FROM posting WHERE journal_entry_id = NEW.id) <> 0;
    SELECT RAISE(ABORT, 'period.hard_locked')
    WHERE NEW.entry_date <= coalesce((SELECT hard_locked_through FROM company), '0000-01-01');
    SELECT RAISE(ABORT, 'period.soft_locked')
    WHERE NEW.entry_date <= coalesce((SELECT soft_locked_through FROM company), '0000-01-01')
      AND NOT EXISTS (SELECT 1 FROM lock_override WHERE journal_entry_id = NEW.id);
    SELECT RAISE(ABORT, 'ledger.reversal_target_not_final')
    WHERE NEW.kind = 'reversal'
      AND (SELECT state FROM journal_entry WHERE id = NEW.reverses_entry_id) IS NOT 'final';
    SELECT RAISE(ABORT, 'ledger.reversal_mismatch')
    WHERE NEW.kind = 'reversal' AND (
          (SELECT document_id FROM journal_entry WHERE id = NEW.reverses_entry_id) IS NOT NEW.document_id
       OR (SELECT document_revision FROM journal_entry WHERE id = NEW.reverses_entry_id) IS NOT NEW.document_revision
       OR (SELECT entry_date FROM journal_entry WHERE id = NEW.reverses_entry_id) IS NOT NEW.entry_date
       OR EXISTS (
            SELECT 1 FROM posting p
            WHERE p.journal_entry_id IN (NEW.id, NEW.reverses_entry_id)
            GROUP BY p.line_key, p.account_id, coalesce(p.contact_id, ''), p.currency
            HAVING sum(p.amount_minor) <> 0 OR sum(p.base_amount_minor) <> 0)
       -- each (line key, dimension, value) must appear once in the original and once in the reversal
       OR EXISTS (
            SELECT 1 FROM posting p JOIN posting_dimension d ON d.posting_id = p.id
            WHERE p.journal_entry_id IN (NEW.id, NEW.reverses_entry_id)
            GROUP BY p.line_key, d.dimension_id, d.value_id
            HAVING count(*) <> 2));
END;

CREATE TRIGGER journal_entry_open_update_forbidden BEFORE UPDATE ON journal_entry
WHEN OLD.state = 'open' AND NEW.state <> 'final'
BEGIN SELECT RAISE(ABORT, 'ledger.entry_update_forbidden'); END;

CREATE TRIGGER journal_entry_final_immutable BEFORE UPDATE ON journal_entry
WHEN OLD.state = 'final'
BEGIN SELECT RAISE(ABORT, 'ledger.entry_immutable'); END;

CREATE TRIGGER journal_entry_final_no_delete BEFORE DELETE ON journal_entry
WHEN OLD.state = 'final'
BEGIN SELECT RAISE(ABORT, 'ledger.entry_immutable'); END;

CREATE TRIGGER posting_insert_requires_open_entry BEFORE INSERT ON posting
WHEN (SELECT state FROM journal_entry WHERE id = NEW.journal_entry_id) IS NOT 'open'
BEGIN SELECT RAISE(ABORT, 'ledger.entry_not_open'); END;

CREATE TRIGGER posting_ar_ap_requires_contact BEFORE INSERT ON posting
WHEN NEW.contact_id IS NULL
 AND (SELECT subtype FROM account WHERE id = NEW.account_id) IN ('accounts_receivable', 'accounts_payable')
BEGIN SELECT RAISE(ABORT, 'ledger.ar_ap_requires_contact'); END;

CREATE TRIGGER posting_no_update BEFORE UPDATE ON posting
BEGIN SELECT RAISE(ABORT, 'ledger.posting_immutable'); END;

CREATE TRIGGER posting_final_no_delete BEFORE DELETE ON posting
WHEN (SELECT state FROM journal_entry WHERE id = OLD.journal_entry_id) = 'final'
BEGIN SELECT RAISE(ABORT, 'ledger.posting_immutable'); END;

CREATE TRIGGER posting_dimension_requires_open_entry BEFORE INSERT ON posting_dimension
WHEN (SELECT je.state FROM posting p JOIN journal_entry je ON je.id = p.journal_entry_id WHERE p.id = NEW.posting_id) IS NOT 'open'
BEGIN SELECT RAISE(ABORT, 'ledger.entry_not_open'); END;
CREATE TRIGGER posting_dimension_no_update BEFORE UPDATE ON posting_dimension
BEGIN SELECT RAISE(ABORT, 'ledger.posting_immutable'); END;
CREATE TRIGGER posting_dimension_final_no_delete BEFORE DELETE ON posting_dimension
WHEN (SELECT je.state FROM posting p JOIN journal_entry je ON je.id = p.journal_entry_id WHERE p.id = OLD.posting_id) = 'final'
BEGIN SELECT RAISE(ABORT, 'ledger.posting_immutable'); END;

-- ---------------------------------------------------------------------------
-- 5. Banking: imports, review queue, rules, feeds, reconciliation
-- ---------------------------------------------------------------------------

CREATE TABLE bank_feed (
    id                   TEXT PRIMARY KEY CHECK (length(id) = 36),
    account_id           TEXT NOT NULL REFERENCES account(id),
    provider             TEXT NOT NULL CHECK (provider IN ('simplefin', 'teller', 'plaid')),
    provider_account_id  TEXT NOT NULL,
    display_name         TEXT,
    credential_ref       TEXT NOT NULL,     -- key into the SecretStore; never the secret itself
    status               TEXT NOT NULL CHECK (status IN ('active', 'needs_attention', 'disabled')),
    last_synced_at       TEXT CHECK (last_synced_at IS NULL OR last_synced_at GLOB '????-??-??T??:??:??.???Z'),
    last_error           TEXT,
    version              INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at           TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at           TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z'),
    UNIQUE (provider, provider_account_id)
) STRICT;

CREATE TABLE bank_import (
    id                    TEXT PRIMARY KEY CHECK (length(id) = 36),
    account_id            TEXT NOT NULL REFERENCES account(id),
    format                TEXT NOT NULL CHECK (format IN ('ofx', 'qfx', 'qbo', 'csv')),
    file_name             TEXT NOT NULL,
    file_sha256           TEXT NOT NULL CHECK (length(file_sha256) = 64),
    statement_start       TEXT CHECK (statement_start IS NULL OR date(statement_start) IS statement_start),
    statement_end         TEXT CHECK (statement_end IS NULL OR date(statement_end) IS statement_end),
    ledger_balance_minor  INTEGER,
    imported_count        INTEGER NOT NULL CHECK (imported_count >= 0),
    duplicate_count       INTEGER NOT NULL CHECK (duplicate_count >= 0),
    actor_id              TEXT NOT NULL,
    created_at            TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;

CREATE TABLE bank_rule (
    id              TEXT PRIMARY KEY CHECK (length(id) = 36),
    name            TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 200),
    priority        INTEGER NOT NULL,
    account_id      TEXT REFERENCES account(id),        -- NULL = every bank/card account
    conditions_json TEXT NOT NULL CHECK (json_valid(conditions_json)),
    actions_json    TEXT NOT NULL CHECK (json_valid(actions_json)),
    auto_add        INTEGER NOT NULL DEFAULT 0 CHECK (auto_add IN (0, 1)),
    author_user_id  TEXT NOT NULL,                       -- auto_add runs as this user (LEDGER_SPEC section 11)
    is_archived     INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    version         INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at      TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at      TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;
CREATE INDEX bank_rule_priority_idx ON bank_rule(priority) WHERE is_archived = 0;

CREATE TABLE bank_txn (
    id                 TEXT PRIMARY KEY CHECK (length(id) = 36),
    account_id         TEXT NOT NULL REFERENCES account(id),
    source             TEXT NOT NULL CHECK (source IN ('ofx', 'qfx', 'qbo', 'csv', 'simplefin', 'teller', 'plaid')),
    import_id          TEXT REFERENCES bank_import(id),
    feed_id            TEXT REFERENCES bank_feed(id),
    external_id        TEXT,                      -- FITID or provider transaction id
    dedupe_hash        TEXT NOT NULL CHECK (length(dedupe_hash) = 64),
    posted_date        TEXT NOT NULL CHECK (date(posted_date) IS posted_date),
    amount_minor       INTEGER NOT NULL CHECK (amount_minor <> 0),   -- + money in, - money out
    currency           TEXT NOT NULL CHECK (length(currency) = 3 AND currency = upper(currency)),
    payee_raw          TEXT,
    memo_raw           TEXT,
    check_number       TEXT,
    txn_type           TEXT,
    status             TEXT NOT NULL CHECK (status IN ('for_review', 'matched', 'added', 'excluded')),
    suggested_rule_id  TEXT REFERENCES bank_rule(id),
    version            INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at         TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    updated_at         TEXT NOT NULL CHECK (updated_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK ((import_id IS NULL) <> (feed_id IS NULL))
) STRICT;
CREATE UNIQUE INDEX bank_txn_external_uq ON bank_txn(account_id, external_id) WHERE external_id IS NOT NULL;
CREATE UNIQUE INDEX bank_txn_hash_uq ON bank_txn(account_id, dedupe_hash) WHERE external_id IS NULL;
CREATE INDEX bank_txn_review_idx ON bank_txn(account_id, status, posted_date);

-- Append-only history of what happened to each bank line.
CREATE TABLE bank_txn_action (
    bank_txn_id  TEXT NOT NULL REFERENCES bank_txn(id),
    seq          INTEGER NOT NULL CHECK (seq >= 1),
    action       TEXT NOT NULL CHECK (action IN ('match', 'add', 'exclude', 'undo')),
    document_id  TEXT REFERENCES document(id),
    line_key     TEXT,                            -- money-side posting line the bank line stands for
    actor_id     TEXT NOT NULL,
    created_at   TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    PRIMARY KEY (bank_txn_id, seq),
    CHECK (action NOT IN ('match', 'add') OR (document_id IS NOT NULL AND line_key IS NOT NULL))
) STRICT;
CREATE INDEX bank_txn_action_document_idx ON bank_txn_action(document_id) WHERE document_id IS NOT NULL;
CREATE TRIGGER bank_txn_action_no_update BEFORE UPDATE ON bank_txn_action
BEGIN SELECT RAISE(ABORT, 'banking.history_immutable'); END;
CREATE TRIGGER bank_txn_action_no_delete BEFORE DELETE ON bank_txn_action
BEGIN SELECT RAISE(ABORT, 'banking.history_immutable'); END;

CREATE TABLE reconciliation (
    id                       TEXT PRIMARY KEY CHECK (length(id) = 36),
    account_id               TEXT NOT NULL REFERENCES account(id),
    statement_date           TEXT NOT NULL CHECK (date(statement_date) IS statement_date),
    beginning_balance_minor  INTEGER NOT NULL,
    ending_balance_minor     INTEGER NOT NULL,
    status                   TEXT NOT NULL CHECK (status IN ('in_progress', 'completed', 'undone')),
    started_by               TEXT NOT NULL,
    started_at               TEXT NOT NULL CHECK (started_at GLOB '????-??-??T??:??:??.???Z'),
    completed_by             TEXT,
    completed_at             TEXT CHECK (completed_at IS NULL OR completed_at GLOB '????-??-??T??:??:??.???Z'),
    snapshot_hash            TEXT CHECK (snapshot_hash IS NULL OR length(snapshot_hash) = 64),
    undone_by                TEXT,
    undone_at                TEXT CHECK (undone_at IS NULL OR undone_at GLOB '????-??-??T??:??:??.???Z'),
    undo_reason              TEXT,
    version                  INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    CHECK ((status IN ('completed', 'undone')) = (completed_at IS NOT NULL AND snapshot_hash IS NOT NULL)),
    CHECK ((status = 'undone') = (undone_at IS NOT NULL AND undo_reason IS NOT NULL))
) STRICT;
CREATE UNIQUE INDEX reconciliation_one_open_uq ON reconciliation(account_id) WHERE status = 'in_progress';
CREATE INDEX reconciliation_account_idx ON reconciliation(account_id, statement_date);

CREATE TRIGGER reconciliation_transition BEFORE UPDATE ON reconciliation
WHEN NOT (
        (OLD.status = 'in_progress' AND NEW.status IN ('in_progress', 'completed'))
     OR (OLD.status = 'completed' AND NEW.status = 'undone'))
  OR NEW.account_id IS NOT OLD.account_id
  OR (OLD.status <> 'in_progress' AND (
        NEW.statement_date IS NOT OLD.statement_date OR NEW.beginning_balance_minor IS NOT OLD.beginning_balance_minor
     OR NEW.ending_balance_minor IS NOT OLD.ending_balance_minor OR NEW.completed_at IS NOT OLD.completed_at
     OR NEW.snapshot_hash IS NOT OLD.snapshot_hash))
BEGIN SELECT RAISE(ABORT, 'reconciliation.invalid_transition'); END;
CREATE TRIGGER reconciliation_delete_in_progress_only BEFORE DELETE ON reconciliation
WHEN OLD.status <> 'in_progress'
BEGIN SELECT RAISE(ABORT, 'reconciliation.immutable'); END;

CREATE TABLE reconciliation_line (
    reconciliation_id  TEXT NOT NULL REFERENCES reconciliation(id) ON DELETE CASCADE,
    line_key           TEXT NOT NULL,
    posting_id         TEXT NOT NULL REFERENCES posting(id),
    amount_minor       INTEGER NOT NULL,
    entry_date         TEXT NOT NULL CHECK (date(entry_date) IS entry_date),
    PRIMARY KEY (reconciliation_id, line_key)
) STRICT;
CREATE TRIGGER reconciliation_line_insert_open BEFORE INSERT ON reconciliation_line
WHEN (SELECT status FROM reconciliation WHERE id = NEW.reconciliation_id) IS NOT 'in_progress'
BEGIN SELECT RAISE(ABORT, 'reconciliation.immutable'); END;
CREATE TRIGGER reconciliation_line_no_update BEFORE UPDATE ON reconciliation_line
BEGIN SELECT RAISE(ABORT, 'reconciliation.immutable'); END;
CREATE TRIGGER reconciliation_line_delete_open BEFORE DELETE ON reconciliation_line
WHEN (SELECT status FROM reconciliation WHERE id = OLD.reconciliation_id) IS NOT 'in_progress'
BEGIN SELECT RAISE(ABORT, 'reconciliation.immutable'); END;

-- Clearing state of money-side lines, keyed by (account, line_key) so it survives reposts.
-- Current state = row with the highest seq; no row = 'uncleared'.
CREATE TABLE clearing_event (
    seq                INTEGER PRIMARY KEY,
    id                 TEXT NOT NULL UNIQUE CHECK (length(id) = 36),
    account_id         TEXT NOT NULL REFERENCES account(id),
    line_key           TEXT NOT NULL,
    state              TEXT NOT NULL CHECK (state IN ('uncleared', 'cleared', 'reconciled')),
    reconciliation_id  TEXT REFERENCES reconciliation(id),
    actor_id           TEXT NOT NULL,
    reason             TEXT,
    created_at         TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    CHECK ((state = 'reconciled') = (reconciliation_id IS NOT NULL))
) STRICT;
CREATE INDEX clearing_event_key_idx ON clearing_event(account_id, line_key, seq);
CREATE TRIGGER clearing_event_no_update BEFORE UPDATE ON clearing_event
BEGIN SELECT RAISE(ABORT, 'reconciliation.history_immutable'); END;
CREATE TRIGGER clearing_event_no_delete BEFORE DELETE ON clearing_event
BEGIN SELECT RAISE(ABORT, 'reconciliation.history_immutable'); END;

-- ---------------------------------------------------------------------------
-- 6. Attachments, imports, external references
-- ---------------------------------------------------------------------------

CREATE TABLE attachment (
    id            TEXT PRIMARY KEY CHECK (length(id) = 36),
    file_name     TEXT NOT NULL CHECK (length(file_name) BETWEEN 1 AND 255),
    content_type  TEXT NOT NULL,
    size_bytes    INTEGER NOT NULL CHECK (size_bytes >= 0),
    sha256        TEXT NOT NULL CHECK (length(sha256) = 64),
    created_by    TEXT NOT NULL,
    created_at    TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;

CREATE TABLE attachment_blob (
    attachment_id  TEXT PRIMARY KEY REFERENCES attachment(id),
    data           BLOB NOT NULL
) STRICT;

CREATE TABLE attachment_link (
    attachment_id  TEXT NOT NULL REFERENCES attachment(id),
    entity_type    TEXT NOT NULL CHECK (entity_type IN ('document', 'contact', 'item', 'account', 'reconciliation', 'company')),
    entity_id      TEXT NOT NULL,
    created_at     TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    PRIMARY KEY (attachment_id, entity_type, entity_id)
) STRICT;
CREATE INDEX attachment_link_entity_idx ON attachment_link(entity_type, entity_id);

CREATE TABLE import_run (
    id                 TEXT PRIMARY KEY CHECK (length(id) = 36),
    source             TEXT NOT NULL CHECK (source IN ('qbo_api', 'csv', 'interchange', 'iif')),
    realm              TEXT NOT NULL DEFAULT '',          -- QBO realm id, or sha256 of the imported file set
    status             TEXT NOT NULL CHECK (status IN ('running', 'succeeded', 'failed', 'rolled_back')),
    options_json       TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(options_json)),
    stats_json         TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(stats_json)),
    validation_json    TEXT CHECK (validation_json IS NULL OR json_valid(validation_json)),
    backup_path        TEXT,                               -- automatic pre-import backup
    first_audit_seq    INTEGER,
    last_audit_seq     INTEGER,
    actor_id           TEXT NOT NULL,
    version            INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    started_at         TEXT NOT NULL CHECK (started_at GLOB '????-??-??T??:??:??.???Z'),
    finished_at        TEXT CHECK (finished_at IS NULL OR finished_at GLOB '????-??-??T??:??:??.???Z')
) STRICT;

CREATE TABLE external_ref (
    id             TEXT PRIMARY KEY CHECK (length(id) = 36),
    entity_type    TEXT NOT NULL,                 -- 'account', 'contact', 'item', 'document', 'term', ...
    entity_id      TEXT NOT NULL,
    source         TEXT NOT NULL CHECK (source IN ('qbo', 'iif', 'csv', 'interchange', 'ofx', 'simplefin', 'teller', 'plaid')),
    realm          TEXT NOT NULL DEFAULT '',      -- QBO realm id; '' when the source has no tenant
    external_type  TEXT NOT NULL,                 -- source entity name, e.g. 'Invoice', 'Customer', 'TRNS'
    external_id    TEXT NOT NULL,
    sync_token     TEXT,                          -- QBO SyncToken at import time
    payload_json   TEXT CHECK (payload_json IS NULL OR json_valid(payload_json)),  -- raw source record (lossless)
    import_run_id  TEXT REFERENCES import_run(id),
    created_at     TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    UNIQUE (source, realm, external_type, external_id)
) STRICT;
CREATE INDEX external_ref_entity_idx ON external_ref(entity_type, entity_id);

-- Source records BooksCraft does not model yet (QBO PurchaseOrder, TimeActivity, Budget,
-- InventoryAdjustment, ...), kept verbatim so a migration loses nothing and v1 can import them later.
CREATE TABLE import_archive (
    id             TEXT PRIMARY KEY CHECK (length(id) = 36),
    import_run_id  TEXT NOT NULL REFERENCES import_run(id),
    source         TEXT NOT NULL CHECK (source IN ('qbo', 'iif', 'csv', 'interchange')),
    realm          TEXT NOT NULL DEFAULT '',
    external_type  TEXT NOT NULL,
    external_id    TEXT NOT NULL,
    payload_json   TEXT NOT NULL CHECK (json_valid(payload_json)),
    created_at     TEXT NOT NULL CHECK (created_at GLOB '????-??-??T??:??:??.???Z'),
    UNIQUE (source, realm, external_type, external_id)
) STRICT;

-- ---------------------------------------------------------------------------
-- 7. Audit log (append-only, hash-chained) and request idempotency
-- ---------------------------------------------------------------------------

CREATE TABLE audit_event (
    seq          INTEGER PRIMARY KEY,                -- 1, 2, 3, ... supplied by the writer
    id           TEXT NOT NULL UNIQUE CHECK (length(id) = 36),
    occurred_at  TEXT NOT NULL CHECK (occurred_at GLOB '????-??-??T??:??:??.???Z'),
    actor_type   TEXT NOT NULL CHECK (actor_type IN ('user', 'api', 'agent')),
    actor_id     TEXT NOT NULL,
    actor_name   TEXT NOT NULL,
    via          TEXT NOT NULL CHECK (via IN ('ui', 'api', 'mcp', 'cli', 'import', 'job')),
    action       TEXT NOT NULL,                      -- e.g. 'document.post', 'period.set_locks', 'approval.approve'
    entity_type  TEXT NOT NULL,
    entity_id    TEXT NOT NULL,
    before_json  TEXT CHECK (before_json IS NULL OR json_valid(before_json)),
    after_json   TEXT CHECK (after_json IS NULL OR json_valid(after_json)),
    reason       TEXT,
    request_id   TEXT,
    prev_hash    TEXT NOT NULL CHECK (length(prev_hash) = 64),
    hash         TEXT NOT NULL UNIQUE CHECK (length(hash) = 64)
) STRICT;
CREATE INDEX audit_event_entity_idx ON audit_event(entity_type, entity_id, seq);
CREATE INDEX audit_event_time_idx ON audit_event(occurred_at);

-- The writer computes `hash` (SHA-256, see LEDGER_SPEC.md section 10); storage enforces the links.
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
CREATE INDEX idempotency_key_expiry_idx ON idempotency_key(expires_at);

-- ---------------------------------------------------------------------------
-- 8. Read models used by reports (views only; nothing derived is stored)
-- ---------------------------------------------------------------------------

CREATE VIEW ledger_line AS
SELECT p.id                 AS posting_id,
       p.journal_entry_id   AS journal_entry_id,
       je.entry_date        AS entry_date,
       je.kind              AS entry_kind,
       je.document_id       AS document_id,
       je.document_revision AS document_revision,
       d.doc_type           AS doc_type,
       d.number             AS number,
       d.status             AS document_status,
       p.line_no            AS line_no,
       p.line_key           AS line_key,
       p.account_id         AS account_id,
       p.contact_id         AS contact_id,
       p.currency           AS currency,
       p.amount_minor       AS amount_minor,
       p.base_amount_minor  AS base_amount_minor,
       p.memo               AS memo
FROM posting p
JOIN journal_entry je ON je.id = p.journal_entry_id
JOIN document d ON d.id = je.document_id
WHERE je.state = 'final';

CREATE VIEW active_settlement AS
SELECT s.*
FROM settlement s
JOIN document e ON e.id = s.event_document_id
WHERE e.status = 'posted' AND s.event_revision = e.revision;

CREATE VIEW current_document_line AS
SELECT dl.*
FROM document_line dl
JOIN document d ON d.id = dl.document_id
WHERE dl.revision = d.revision;

CREATE VIEW clearing_state AS
SELECT ce.account_id, ce.line_key, ce.state, ce.reconciliation_id, ce.seq
FROM clearing_event ce
WHERE ce.seq = (SELECT max(c2.seq) FROM clearing_event c2
                WHERE c2.account_id = ce.account_id AND c2.line_key = ce.line_key);
