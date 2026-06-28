-- =====================================================================
-- DividendLab — market_data.db
-- =====================================================================
-- Scope: shared, asset-level reference data only. No user-specific
-- or portfolio-specific data lives in this file.
--
-- This database is opened independently and ATTACHed to the main
-- portfolio.db connection at runtime, e.g.:
--
--     ATTACH DATABASE 'market_data.db' AS market;
--
-- IMPORTANT — cross-database FK limitation:
-- SQLite enforces foreign keys only *within* a single database file.
-- Tables in portfolio.db that reference asset_id (holdings,
-- transactions) are NOT protected by a real FK constraint against
-- this file. That existence check must be done in application code
-- (see backend/data/database.py) before any insert/delete that
-- crosses the attachment boundary.
--
-- FK enforcement WITHIN this file (asset_id -> price_history /
-- dividend_history) is real and is enabled by:
--     PRAGMA foreign_keys = ON;
-- which must be set by the connecting application, not by this file.
-- =====================================================================

-- ---------------------------------------------------------------------
-- assets
-- ---------------------------------------------------------------------
-- Master list of every tradable instrument. One row per ticker.
-- Never duplicated across portfolios — holdings/transactions in
-- portfolio.db reference asset_id by value only.
-- ---------------------------------------------------------------------
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
    currency            TEXT    NOT NULL DEFAULT 'USD',
    sector              TEXT,
    industry            TEXT,
    expense_ratio       REAL,
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
    date            TEXT    NOT NULL,  -- ISO-8601 (YYYY-MM-DD)
    open_price      REAL,
    high_price      REAL,
    low_price       REAL,
    close_price     REAL,
    adjusted_close  REAL,
    volume          INTEGER,

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
    payment_date        TEXT,
    record_date         TEXT,
    ex_dividend_date    TEXT    NOT NULL,
    dividend_per_share  REAL    NOT NULL,
    currency            TEXT    NOT NULL DEFAULT 'USD',

    FOREIGN KEY (asset_id) REFERENCES assets (asset_id) ON DELETE CASCADE,
    UNIQUE (asset_id, ex_dividend_date)
);

CREATE INDEX IF NOT EXISTS idx_dividend_history_asset_date
    ON dividend_history (asset_id, ex_dividend_date);