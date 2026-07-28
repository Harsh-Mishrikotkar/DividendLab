-- ---------------------------------------------------------------------
-- DEVELOPER NOTES
-- ---------------------------------------------------------------------
-- DividendLab uses SQLite as its database engine.
--
-- SQLite is a file-based database and DOES NOT require a database server
-- such as MySQL or PostgreSQL.
--
-- For normal use of DividendLab, the application will automatically
-- create and initialize the database from this schema if it does not
-- already exist.
--
-- This section is intended for developers who wish to inspect,
-- modify, rebuild, or extend the database manually.
--
--
-- ---------------------------------------------------------------------
-- MANUALLY CREATING THE DATABASE
-- ---------------------------------------------------------------------
-- If you want to create the database yourself, first install SQLite.
--
-- Then, from the database/ directory:
--
-- Linux / macOS
--
--     sqlite3 market_data.db < market_schema.sql
--
-- Windows PowerShell
--
--     sqlite3 market_data.db ".read market_schema.sql"
--
-- This creates a new SQLite database using the schema defined in this
-- file.
--
--
-- ---------------------------------------------------------------------
-- VIEWING OR EDITING THE DATABASE
-- ---------------------------------------------------------------------
-- VS Code users:
--
-- The SQLite extensions for VS Code may prompt you to select or create
-- a local database file. This is expected—SQLite databases are simply
-- local files (*.db), not server instances.
--
-- Open the generated:
--
--     market_data.db
--
-- to browse tables, run queries, or test schema changes.
--
-- After modifying this schema, either recreate the database or write a
-- migration so existing databases remain compatible.
--
--
-- ---------------------------------------------------------------------
-- VERSION CONTROL
-- ---------------------------------------------------------------------
-- Commit:
--
--     ✓ market_schema.sql
--     ✓ portfolio_schema.sql
--
-- Do NOT commit:
--
--     ✗ market_data.db
--     ✗ portfolio.db
--
-- The *.db files are generated locally and should be ignored by Git.


CREATE TABLE IF NOT EXISTS assets (
    asset_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    ticker              TEXT    NOT NULL,
    name                TEXT    NOT NULL,
    asset_type          TEXT    NOT NULL
                            CHECK (asset_type IN (
                                'stock', 'etf', 'reit',
                                'mutual_fund', 'bond', 'cash', 'other'
                            )),
    exchange            TEXT,
    currency            TEXT    NOT NULL DEFAULT 'USD' CHECK(length(currency)=3),
    sector              TEXT,
    industry            TEXT,
    expense_ratio       REAL CHECK (expense_ratio >= 0),
    dividend_frequency  TEXT
                            CHECK (dividend_frequency IN (
                                'monthly', 'quarterly', 'semi_annual',
                                'annual', 'irregular', 'none'
                            )),
    created_at          TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at          TEXT    NOT NULL DEFAULT (datetime('now')),

    UNIQUE (ticker)
);

CREATE TRIGGER IF NOT EXISTS trg_assets_updated_at
AFTER UPDATE ON assets
FOR EACH ROW
BEGIN
    UPDATE assets SET updated_at = datetime('now') WHERE asset_id = OLD.asset_id;
END;

-- ---------------------------------------------------------------------
-- price_history
-- ---------------------------------------------------------------------
-- Historical daily prices per asset. Shared by every portfolio that
-- holds the asset; never duplicated.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS price_history (
    price_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_id        INTEGER NOT NULL,
    date            TEXT NOT NULL   CHECK(date GLOB '????-??-??'),
    open_price      REAL            CHECK(open_price        >= 0),
    high_price      REAL            CHECK(high_price        >= 0),
    low_price       REAL            CHECK(low_price         >= 0),
    close_price     REAL            CHECK(close_price       >= 0),
    adjusted_close  REAL            CHECK(adjusted_close    >= 0),
    volume          INTEGER         CHECK(volume            >= 0),

    FOREIGN KEY (asset_id) REFERENCES assets (asset_id) ON DELETE CASCADE,
    UNIQUE (asset_id, date)
);

CREATE INDEX IF NOT EXISTS idx_price_history_asset_date
    ON price_history (asset_id, date);

-- ---------------------------------------------------------------------
-- dividend_history
-- ---------------------------------------------------------------------
-- Historical declared dividends per asset (company-level events).
-- Distinct from a portfolio's DRIP/dividend *transactions*, which
-- live in portfolio.db and represent what a specific portfolio
-- actually received.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dividend_history (
    dividend_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_id            INTEGER NOT NULL,
    payment_date        TEXT                CHECK(payment_date IS NULL  OR payment_date GLOB '????-??-??'),
    record_date         TEXT                CHECK(record_date IS NULL   OR record_date GLOB '????-??-??'),
    ex_dividend_date    TEXT    NOT NULL    CHECK(ex_dividend_date GLOB '????-??-??'),
    dividend_per_share  REAL    NOT NULL    CHECK(dividend_per_share >= 0),
    currency            TEXT    NOT NULL    DEFAULT 'USD',

    FOREIGN KEY (asset_id) REFERENCES assets (asset_id) ON DELETE CASCADE,
    UNIQUE (asset_id, ex_dividend_date)
);

-- ---------------------------------------------------------------------
-- database_metadata
-- ---------------------------------------------------------------------
-- Stores metadata about this database instance. Used for versioning,
-- update tracking, and migration support.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS database_metadata (
    key     TEXT PRIMARY KEY,
    value   TEXT NOT NULL
);

INSERT OR IGNORE INTO database_metadata (key, value)
VALUES
    ('schema_version', '1.0'),
    ('database_name', 'market_data'),
    ('created_by', 'DividendLab');

CREATE INDEX IF NOT EXISTS idx_dividend_history_asset_date
    ON dividend_history (asset_id, ex_dividend_date);