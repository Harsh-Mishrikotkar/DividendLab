-- =====================================================================
-- DividendLab
-- portfolio_schema.sql
-- =====================================================================
--
-- Creates the user-specific portfolio.db SQLite database used by
-- DividendLab.
---- ---------------------------------------------------------------------
-- DESIGN PHILOSOPHY
-- ---------------------------------------------------------------------
-- DividendLab follows three core principles:
--
-- 1. Immutable Ledger
--    Transactions are never modified or deleted after creation.
--    Corrections are recorded as new transactions rather than editing
--    historical data.
--
-- 2. Cached Performance
--    Frequently used values (holdings, cash_balance,
--    portfolio_snapshots, average_cost, etc.) are maintained as caches
--    for performance but are always derived from immutable source data.
--
-- 3. Business Logic in Python
--    SQL enforces universal data integrity.
--    Workflow, calculations, portfolio rules, and cross-database
--    validation are implemented in the application layer.
--
-- Contributors should preserve these principles when extending
-- DividendLab.
-- ---------------------------------------------------------------------
--
-- ---------------------------------------------------------------------
-- PURPOSE
-- ---------------------------------------------------------------------
-- This database stores all user-owned portfolio data, including:
--
--   • Portfolios and their settings
--   • Holdings (current positions, maintained as a cache)
--   • Tax lots (source of truth for cost basis)
--   • Lot disposals (realized gain history)
--   • Transactions (immutable ledger)
--   • Contribution schedules
--   • Rebalancing rules and target allocations
--   • Portfolio snapshots (periodic performance cache)
--   • Simulation runs and results (V1 deterministic through V5+)
--   • Application settings
--
-- Market reference data (assets, prices, dividends) belongs in
-- market_data.db and is defined separately in market_schema.sql.
--
--
-- ---------------------------------------------------------------------
-- FIRST-TIME SETUP
-- ---------------------------------------------------------------------
-- DividendLab uses SQLite.
-- SQLite is NOT a database server and does NOT require running a local
-- server such as MySQL or PostgreSQL.
--
-- Clone the project, then create the database by executing this schema.
--
-- Linux / macOS
--
--     sqlite3 portfolio.db < portfolio_schema.sql
--
-- Windows PowerShell
--
--     sqlite3 portfolio.db ".read portfolio_schema.sql"
--
-- Alternatively, DividendLab's Python initialization script
-- (backend/data/database.py) will automatically create both databases
-- from their schemas if they do not already exist.
--
--
-- ---------------------------------------------------------------------
-- DATABASE LOCATION
-- ---------------------------------------------------------------------
-- Recommended project structure:
--
-- DividendLab/
-- │
-- ├── database/
-- │   ├── market_schema.sql
-- │   ├── portfolio_schema.sql
-- │   ├── market_data.db        <-- generated locally
-- │   └── portfolio.db          <-- generated locally
-- │
-- └── backend/
--
-- The *.db files should NOT be committed to Git.
-- Only the schema files belong in version control.
--
--
-- ---------------------------------------------------------------------
-- RUNTIME ATTACHMENT
-- ---------------------------------------------------------------------
-- At runtime, the application opens portfolio.db as the main database
-- and attaches market_data.db as a secondary database:
--
--     ATTACH DATABASE 'market_data.db' AS market;
--
-- Cross-database joins then use the alias:
--
--     SELECT h.total_shares, a.ticker
--     FROM holdings h
--     JOIN market.assets a ON h.asset_id = a.asset_id;
--
--
-- ---------------------------------------------------------------------
-- FOREIGN KEY BEHAVIOR
-- ---------------------------------------------------------------------
-- SQLite only enforces foreign keys within a single database file.
--
-- Foreign keys WITHIN portfolio.db (e.g., holdings → portfolios) are
-- fully enforced by SQLite.
--
-- References to market_data.db (asset_id in holdings, transactions,
-- and target_allocations) are NOT enforced by SQLite. DividendLab
-- validates these references in application code before any insert or
-- delete that crosses the attachment boundary.
-- See: backend/data/database.py
--
--
-- ---------------------------------------------------------------------
-- DATA INTEGRITY RULES
-- ---------------------------------------------------------------------
-- SQL constraints enforce universal data integrity rules:
--
--     ✔ shares cannot be negative
--     ✔ prices cannot be negative
--     ✔ cash balance cannot be negative
--     ✔ target allocations must be between 0 and 100
--     ✔ dates follow ISO-8601 format (YYYY-MM-DD)
--     ✔ enumerated fields are restricted to valid values
--
-- Application-specific validation (ticker existence, API responses,
-- business rules, etc.) is handled in Python rather than SQL.
--
-- The sum of target_allocations.target_percentage per portfolio must
-- equal 100. SQLite cannot enforce cross-row aggregate constraints
-- without complex triggers. This is enforced in application code.
-- See: backend/portfolio/rebalancing.py
--
-- The connecting application must enable:
--
--     PRAGMA foreign_keys = ON;
--
--
-- ---------------------------------------------------------------------
-- LEDGER HIERARCHY
-- ---------------------------------------------------------------------
-- Data flows from the most granular (immutable ledger) upward to
-- cached summaries:
--
--     transactions            immutable ledger of every event
--         │
--         ▼
--     tax_lots                source of truth for cost basis
--         │
--         ▼
--     lot_disposals           realized gain history per disposal
--         │
--         ▼
--     holdings                maintained cache of current positions
--         │
--         ▼
--     portfolios              running cash balance and metadata
--         │
--         ▼
--     portfolio_snapshots     periodic performance snapshots
--         │
--         ▼
--     simulation_runs         projection metadata
--         │
--         ▼
--     simulation_results      yearly projection outputs
--
-- Caches (holdings, portfolio cash_balance, portfolio_snapshots) are
-- updated atomically alongside every transaction write.
-- See: backend/data/database.py (transaction management)
-- =====================================================================


-- =====================================================================
-- PORTFOLIOS
-- =====================================================================

-- ---------------------------------------------------------------------
-- portfolios
-- ---------------------------------------------------------------------
-- Top-level container for a user's investment portfolio.
-- Stores portfolio settings and a running cash balance maintained
-- incrementally alongside every transaction.
--
-- cost_basis_method:
--   Set once at portfolio creation; no application-wide default.
--   Determines how lot disposals are selected on a sell:
--
--     FIFO        — oldest lots disposed first
--     LIFO        — newest lots disposed first
--     AVERAGE     — weighted average across all open lots
--     SPECIFIC_ID — user selects specific lots at time of sale
--
-- cash_balance:
--   Maintained incrementally; updated atomically with every
--   transaction. Never recomputed by replaying the full ledger
--   at load time.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS portfolios (
    portfolio_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    name                TEXT    NOT NULL,
    description         TEXT,
    base_currency       TEXT    NOT NULL DEFAULT 'USD' CHECK(length(base_currency)=3),
    benchmark           TEXT,
    cash_balance        REAL    NOT NULL DEFAULT 0.0
                            CHECK (cash_balance >= 0),
    cost_basis_method   TEXT    NOT NULL
                            CHECK (cost_basis_method IN (
                                'FIFO', 'LIFO', 'AVERAGE', 'SPECIFIC_ID'
                            )),
    created_at          TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at          TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TRIGGER IF NOT EXISTS trg_portfolios_updated_at
AFTER UPDATE ON portfolios
FOR EACH ROW
BEGIN
    UPDATE portfolios
    SET updated_at = datetime('now')
    WHERE portfolio_id = OLD.portfolio_id;
END;


-- =====================================================================
-- POSITIONS
-- =====================================================================

-- ---------------------------------------------------------------------
-- holdings
-- ---------------------------------------------------------------------
-- Maintained cache of a portfolio's current positions.
-- One row per (portfolio, asset) pair.
--
-- This table is NOT the source of truth for cost basis.
-- average_cost and cost_basis_total are derived from tax_lots
-- and updated atomically with every buy, sell, or DRIP transaction.
--
-- Do NOT recompute holdings from transactions on every load.
-- Treat this table as a live cache kept consistent by the application.
-- See: backend/portfolio/portfolio_manager.py
--
-- asset_id references market.assets in market_data.db.
-- This foreign key is NOT enforced by SQLite across attached databases.
-- Validated in application code before every insert.
-- See: backend/data/database.py
--
-- These values are stored as cached aggregates rather than recomputed
-- from tax_lots on every portfolio load. They must always remain
-- synchronized with tax_lots by the application.
--
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS holdings (
    holding_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id        INTEGER NOT NULL,
    asset_id            INTEGER NOT NULL,
    total_shares        REAL    NOT NULL DEFAULT 0.0
                            CHECK (total_shares >= 0),
    average_cost        REAL    NOT NULL DEFAULT 0.0
                            CHECK (average_cost >= 0),
    cost_basis_total    REAL    NOT NULL DEFAULT 0.0
                            CHECK (cost_basis_total >= 0),
    created_at          TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at          TEXT    NOT NULL DEFAULT (datetime('now')),

    FOREIGN KEY (portfolio_id) REFERENCES portfolios (portfolio_id)
        ON DELETE CASCADE,
    UNIQUE (portfolio_id, asset_id)
);

CREATE INDEX IF NOT EXISTS idx_holdings_portfolio
    ON holdings (portfolio_id);

CREATE TRIGGER IF NOT EXISTS trg_holdings_updated_at
AFTER UPDATE ON holdings
FOR EACH ROW
BEGIN
    UPDATE holdings
    SET updated_at = datetime('now')
    WHERE holding_id = OLD.holding_id;
END;


-- =====================================================================
-- COST BASIS
-- =====================================================================

-- ---------------------------------------------------------------------
-- tax_lots
-- ---------------------------------------------------------------------
-- Source of truth for cost basis.
-- Every buy or DRIP transaction creates one new lot.
-- shares_remaining decrements as shares are sold.
--
-- Supports all cost basis methods:
--   FIFO        — application orders lots by purchase_date ASC
--   LIFO        — application orders lots by purchase_date DESC
--   AVERAGE     — application averages across all open lots
--   SPECIFIC_ID — user selects lot_id directly
--
-- Lots are never deleted once created. A fully disposed lot has
-- shares_remaining = 0 and remains as a permanent record.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tax_lots (
    lot_id              INTEGER PRIMARY KEY AUTOINCREMENT,
    holding_id          INTEGER NOT NULL,
    purchase_date       TEXT    NOT NULL
                            CHECK (purchase_date GLOB '????-??-??'),
    shares_remaining    REAL    NOT NULL
                            CHECK (shares_remaining >= 0),
    purchase_price      REAL    NOT NULL
                            CHECK (purchase_price >= 0),
    fees                REAL    NOT NULL DEFAULT 0.0
                            CHECK (fees >= 0),

    FOREIGN KEY (holding_id) REFERENCES holdings (holding_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_tax_lots_holding
    ON tax_lots (holding_id, purchase_date);


-- ---------------------------------------------------------------------
-- lot_disposals
-- ---------------------------------------------------------------------
-- Records how shares were removed from each lot during a sell.
-- Provides a complete, auditable realized gain history.
--
-- One sell transaction may generate multiple lot_disposals rows when
-- shares are drawn from more than one lot.
--
-- cost_basis_per_share is copied from the lot at disposal time so the
-- record remains accurate even if lot data were ever amended.
--
-- realized_gain may be negative (a realized loss).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS lot_disposals (
    disposal_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    lot_id                  INTEGER NOT NULL,
    transaction_id          INTEGER NOT NULL,
    shares_disposed         REAL    NOT NULL
                                CHECK (shares_disposed > 0),
    cost_basis_per_share    REAL    NOT NULL
                                CHECK (cost_basis_per_share >= 0),
    proceeds_per_share      REAL    NOT NULL
                                CHECK (proceeds_per_share >= 0),
    realized_gain           REAL    NOT NULL,
    disposal_date           TEXT    NOT NULL
                                CHECK (disposal_date GLOB '????-??-??'),

    FOREIGN KEY (lot_id)         REFERENCES tax_lots    (lot_id)
        ON DELETE CASCADE,
    FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_lot_disposals_lot
    ON lot_disposals (lot_id);

CREATE INDEX IF NOT EXISTS idx_lot_disposals_transaction
    ON lot_disposals (transaction_id);


-- =====================================================================
-- TRANSACTION LEDGER
-- =====================================================================

-- ---------------------------------------------------------------------
-- transactions
-- ---------------------------------------------------------------------
-- Immutable ledger of every portfolio event.
-- Rows are never updated or deleted after creation.
--
-- Corrections should be represented by additional transactions rather than modifying historical records.
-- 
-- transaction_type values:
--
--   BUY         — purchase of shares; decrements cash, creates a lot
--   SELL        — sale of shares; increments cash, creates lot_disposals
--   DRIP        — dividend reinvestment; creates a lot at no cash cost
--   DIVIDEND    — cash dividend received; increments cash
--   DEPOSIT     — cash added to the portfolio; increments cash
--   WITHDRAWAL  — cash removed from the portfolio; decrements cash
--   FEE         — brokerage fee or account charge
--   SPLIT       — stock split adjustment; no cash impact
--
-- Future versions may store split_ratio or other corporate action metadata in a dedicated corporate_actions table rather than adding columns to this ledger.
-- total_amount stores the absolute transaction value.
--
-- Cash direction (in vs. out) is determined by transaction_type in
-- application code. See: backend/portfolio/portfolio_manager.py
--
-- shares and price_per_share are NULL for DEPOSIT, WITHDRAWAL,
-- and DIVIDEND transactions where no shares change hands.
--
-- asset_id is NULL for DEPOSIT and WITHDRAWAL transactions.
-- When non-null, validated against market.assets in application code.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id        INTEGER NOT NULL,
    asset_id            INTEGER,
    transaction_type    TEXT    NOT NULL
                            CHECK (transaction_type IN (
                                'BUY',
                                'SELL',
                                'DRIP',
                                'DIVIDEND',
                                'DEPOSIT',
                                'WITHDRAWAL',
                                'FEE',
                                'SPLIT'
                                )),
    transaction_date    TEXT    NOT NULL
                            CHECK (transaction_date GLOB '????-??-??'),
    shares              REAL
                            CHECK (shares IS NULL OR shares > 0),
    price_per_share     REAL
                            CHECK (price_per_share IS NULL OR price_per_share >= 0),
    fees                REAL    NOT NULL DEFAULT 0.0
                            CHECK (fees >= 0),
    total_amount        REAL    NOT NULL
                            CHECK (total_amount >= 0),
    notes               TEXT,
    created_at          TEXT    NOT NULL DEFAULT (datetime('now')),

    FOREIGN KEY (portfolio_id) REFERENCES portfolios (portfolio_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_transactions_portfolio_date
    ON transactions (portfolio_id, transaction_date);

CREATE INDEX IF NOT EXISTS idx_transactions_asset
    ON transactions (asset_id, transaction_date);


-- =====================================================================
-- CONTRIBUTION & REBALANCING
-- =====================================================================

-- ---------------------------------------------------------------------
-- contribution_schedules
-- ---------------------------------------------------------------------
-- Stores recurring cash contribution plans per portfolio.
-- Used by the deterministic projection engine (V1) and reused by
-- Monte Carlo simulations (V2+).
--
-- end_date is nullable; a NULL end_date means the schedule runs
-- indefinitely.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS contribution_schedules (
    schedule_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id        INTEGER NOT NULL,
    amount              REAL    NOT NULL
                            CHECK (amount > 0),
    frequency           TEXT    NOT NULL
                            CHECK (frequency IN (
                                'monthly', 'quarterly',
                                'semi_annual', 'annual'
                            )),
    start_date          TEXT    NOT NULL
                            CHECK (start_date GLOB '????-??-??'),
    end_date            TEXT
                            CHECK (end_date IS NULL
                                   OR end_date GLOB '????-??-??'),
    enabled             INTEGER NOT NULL DEFAULT 1
                            CHECK (enabled IN (0, 1)),

    FOREIGN KEY (portfolio_id) REFERENCES portfolios (portfolio_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_contribution_schedules_portfolio
    ON contribution_schedules (portfolio_id);


-- ---------------------------------------------------------------------
-- rebalancing_rules
-- ---------------------------------------------------------------------
-- Stores rebalancing configuration for a portfolio.
-- A portfolio may have multiple rules; V1 typically uses one.
--
-- rebalance_type values:
--
--   threshold   — rebalance when any asset drifts beyond
--                 threshold_percent from its target weight
--   periodic    — rebalance on a fixed schedule (rebalance_frequency)
--   both        — trigger on either condition
--
-- rebalance_frequency and threshold_percent may be NULL when not
-- applicable to the selected rebalance_type.
--
-- last_rebalanced is updated by the application after each rebalance.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rebalancing_rules (
    rule_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id        INTEGER NOT NULL,
    rebalance_type      TEXT    NOT NULL
                            CHECK (rebalance_type IN (
                                'threshold', 'periodic', 'both'
                            )),
    rebalance_frequency TEXT
                            CHECK (rebalance_frequency IS NULL OR
                                   rebalance_frequency IN (
                                'monthly', 'quarterly',
                                'semi_annual', 'annual'
                            )),
    threshold_percent   REAL
                            CHECK (threshold_percent IS NULL OR
                                   threshold_percent > 0),
    last_rebalanced     TEXT
                            CHECK (last_rebalanced IS NULL OR
                                   last_rebalanced GLOB '????-??-??'),
    enabled             INTEGER NOT NULL DEFAULT 1
                            CHECK (enabled IN (0, 1)),

    FOREIGN KEY (portfolio_id) REFERENCES portfolios (portfolio_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_rebalancing_rules_portfolio
    ON rebalancing_rules (portfolio_id);


-- ---------------------------------------------------------------------
-- target_allocations
-- ---------------------------------------------------------------------
-- Defines the desired weight of each asset within a portfolio.
-- Used by the rebalancing engine to calculate drift and required trades.
--
-- asset_id references market.assets in market_data.db.
-- This foreign key is NOT enforced by SQLite across attached databases.
-- Validated in application code before every insert.
--
-- IMPORTANT: The sum of target_percentage per portfolio_id must equal
-- 100. SQLite cannot enforce this constraint across multiple rows.
-- Enforced in application code.
-- See: backend/portfolio/rebalancing.py
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS target_allocations (
    allocation_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id        INTEGER NOT NULL,
    asset_id            INTEGER NOT NULL,
    target_percentage   REAL    NOT NULL
                            CHECK (target_percentage > 0
                               AND target_percentage <= 100),

    FOREIGN KEY (portfolio_id) REFERENCES portfolios (portfolio_id)
        ON DELETE CASCADE,
    UNIQUE (portfolio_id, asset_id)
);

CREATE INDEX IF NOT EXISTS idx_target_allocations_portfolio
    ON target_allocations (portfolio_id);


-- =====================================================================
-- PERFORMANCE HISTORY
-- =====================================================================

-- ---------------------------------------------------------------------
-- portfolio_snapshots
-- ---------------------------------------------------------------------
-- Periodic snapshots of a portfolio's financial state.
-- Stored to enable historical performance charts without replaying
-- the full transaction ledger on every page load.
--
-- Snapshots are written by the application at configurable intervals
-- (typically daily or end-of-week).
-- daily_return and total_return may be negative.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS portfolio_snapshots (
    snapshot_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id            INTEGER NOT NULL,
    snapshot_date           TEXT    NOT NULL
                                CHECK (snapshot_date GLOB '????-??-??'),
    market_value            REAL    NOT NULL
                                CHECK (market_value >= 0),
    cash_balance            REAL    NOT NULL
                                CHECK (cash_balance >= 0),
    cost_basis              REAL
                                CHECK (cost_basis IS NULL OR cost_basis >= 0),
    annual_dividend_income  REAL
                                CHECK (annual_dividend_income IS NULL
                                       OR annual_dividend_income >= 0),
    daily_return            REAL,
    total_return            REAL,

    FOREIGN KEY (portfolio_id) REFERENCES portfolios (portfolio_id)
        ON DELETE CASCADE,
    UNIQUE (portfolio_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_portfolio_snapshots_portfolio_date
    ON portfolio_snapshots (portfolio_id, snapshot_date);


-- =====================================================================
-- SIMULATIONS
-- =====================================================================

-- ---------------------------------------------------------------------
-- simulation_runs
-- ---------------------------------------------------------------------
-- Metadata record for every projection or simulation run.
-- One row per execution regardless of simulation type.
--
-- simulation_type values by version:
--
--   V1   deterministic   — fixed return and dividend growth assumptions
--   V2   gbm             — Geometric Brownian Motion
--        bootstrap       — historical bootstrap resampling
--   V3   jump_diffusion  — GBM with jump risk events
--        fat_tail        — fat-tail distributed returns
--   V4   regime_based    — macro regime-dependent parameters
--   V5   historical_analog — analog-informed scenario simulation
--
-- parameters_json stores the full assumption set used for the run
-- as a JSON string, providing a complete record for reproducibility.
--
-- Additional simulation types may be introduced in future schema
-- versions. Existing values should never be repurposed.
--
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS simulation_runs (
    simulation_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id        INTEGER NOT NULL,
    simulation_type     TEXT    NOT NULL
                            CHECK (simulation_type IN (
                                'deterministic',
                                'gbm',
                                'bootstrap',
                                'jump_diffusion',
                                'fat_tail',
                                'regime_based',
                                'historical_analog'
                            )),
    simulation_name     TEXT,
    start_date          TEXT    NOT NULL
                            CHECK (start_date GLOB '????-??-??'),
    projection_years    INTEGER NOT NULL
                            CHECK (projection_years > 0),
    parameters_json     TEXT,
    created_at          TEXT    NOT NULL DEFAULT (datetime('now')),

    FOREIGN KEY (portfolio_id) REFERENCES portfolios (portfolio_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_simulation_runs_portfolio
    ON simulation_runs (portfolio_id);


-- ---------------------------------------------------------------------
-- simulation_results
-- ---------------------------------------------------------------------
-- Yearly outputs for every simulation run.
-- Designed to support both V1 deterministic (single path) and V2+
-- probabilistic simulations (multiple percentile paths) without
-- requiring a schema change.
--
-- percentile values:
--
--   'deterministic'  — V1 single-path projection (no distribution)
--   'p5'  through 'p95' — Monte Carlo percentile outcomes (V2+)
--
-- Using a named TEXT value instead of a nullable REAL preserves the
-- UNIQUE constraint for deterministic runs while remaining extensible
-- for future simulation types.
--
-- portfolio_value_real is the inflation-adjusted equivalent of
-- portfolio_value in the same row.
--
-- All monetary values are in the portfolio's base_currency.
-- Negative values are valid for cumulative_return in loss scenarios.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS simulation_results (
    result_id               INTEGER PRIMARY KEY AUTOINCREMENT,
    simulation_id           INTEGER NOT NULL,
    year                    INTEGER NOT NULL
                                CHECK (year >= 0),
    percentile              TEXT    NOT NULL DEFAULT 'deterministic'
                                CHECK (percentile IN (
                                    'deterministic',
                                    'p5', 'p10', 'p25',
                                    'p50', 'p75', 'p90', 'p95'
                                )),
    portfolio_value         REAL
                                CHECK (portfolio_value IS NULL
                                       OR portfolio_value >= 0),
    portfolio_value_real    REAL
                                CHECK (portfolio_value_real IS NULL
                                       OR portfolio_value_real >= 0),
    annual_dividend_income  REAL
                                CHECK (annual_dividend_income IS NULL
                                       OR annual_dividend_income >= 0),
    annual_contributions    REAL
                                CHECK (annual_contributions IS NULL
                                       OR annual_contributions >= 0),
    annual_withdrawals      REAL
                                CHECK (annual_withdrawals IS NULL
                                       OR annual_withdrawals >= 0),
    inflation_rate          REAL,
    cumulative_return       REAL,

    FOREIGN KEY (simulation_id) REFERENCES simulation_runs (simulation_id)
        ON DELETE CASCADE,
    UNIQUE (simulation_id, year, percentile)
);

CREATE INDEX IF NOT EXISTS idx_simulation_results_run
    ON simulation_results (simulation_id, year);


-- =====================================================================
-- APPLICATION SETTINGS
-- =====================================================================

-- ---------------------------------------------------------------------
-- app_settings
-- ---------------------------------------------------------------------
-- This table stores defaults only.
--
--Portfolio-specific settings belong in the portfolios table or related portfolio configuration tables.
--
-- Global application configuration stored as key-value pairs.
-- Provides runtime defaults for projections, API configuration,
-- and user preferences without requiring code changes.
--
-- All values are stored as TEXT regardless of their logical type.
-- The application is responsible for parsing and validating values
-- when reading from this table.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app_settings (
    setting_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    setting_name    TEXT    NOT NULL,
    setting_value   TEXT    NOT NULL,
    description     TEXT,

    UNIQUE (setting_name)
);

INSERT OR IGNORE INTO app_settings (setting_name, setting_value, description)
VALUES
    ('default_inflation_rate',  '0.03',  'Default annual inflation rate assumption for projections (decimal, e.g. 0.03 = 3%)'),
    ('default_return_rate',     '0.07',  'Default nominal annual return assumption for deterministic projections (decimal)'),
    ('default_dividend_growth', '0.05',  'Default annual dividend growth rate assumption (decimal)'),
    ('default_projection_years','30',    'Default number of years for deterministic projections'),
    ('data_refresh_days',       '1',     'Number of days before cached market data is considered stale'),
    ('snapshot_frequency',      'daily', 'How often portfolio snapshots are recorded (daily, weekly, monthly)'),
    ('base_currency',           'USD',   'Application-wide default currency for display purposes');


-- =====================================================================
-- DATABASE METADATA
-- =====================================================================

-- ---------------------------------------------------------------------
-- database_metadata
-- ---------------------------------------------------------------------
-- Stores metadata about this database instance.
-- Used for versioning, compatibility checks, and future migration
-- support.
--
-- The application reads schema_version on startup to determine whether
-- a migration is required before proceeding.
-- See: backend/data/database.py
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS database_metadata (
    key     TEXT PRIMARY KEY,
    value   TEXT NOT NULL
);

INSERT OR IGNORE INTO database_metadata (key, value)
VALUES
    ('schema_version', '1.0'),
    ('database_name',  'portfolio'),
    ('created_by',     'DividendLab');


-- =====================================================================
-- FUTURE SCHEMA EXPANSION
-- =====================================================================
--
-- Potential future additions include:
--
-- • Corporate actions (splits, mergers, spin-offs)
-- • Tax reporting
-- • Multi-currency exchange rates
-- • Option positions
-- • Fixed-income securities
-- • Margin accounts
-- • Performance attribution
-- • Benchmark history
-- • User watchlists
--
-- These features should be added through schema migrations rather than
-- modifying existing historical data structures.
-- =====================================================================