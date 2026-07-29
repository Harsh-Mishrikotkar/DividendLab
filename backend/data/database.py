"""
backend/data/database.py

Project Niyati — Database Connection Manager
============================================

Provides the low-level database infrastructure used throughout Project
Niyati.

Responsibilities
----------------
This module is intentionally limited to database infrastructure only.

It is responsible for:

• Managing SQLite connections
• Attaching market_data.db
• Transaction management
• Query execution
• SQLite configuration
• Context manager support
• Row conversion helpers

This module deliberately does NOT contain:

• Database initialization
• Schema creation
• Schema version checking
• Portfolio business logic
• Generic CRUD helpers
• Repository logic

Those responsibilities belong in:

    backend/data/database_initializer.py

and

    backend/data/repositories/

Design Philosophy
-----------------
DatabaseManager should know nothing about portfolios, holdings,
transactions, or financial business rules.

It only knows how to safely communicate with SQLite.

Higher layers build on top of this abstraction:

    PortfolioManager
            ↓
    Repository Layer
            ↓
    DatabaseManager
            ↓
          SQLite
"""

from __future__ import annotations

import logging
import sqlite3

from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator, Optional

# ---------------------------------------------------------------------
# Module configuration
# ---------------------------------------------------------------------

logger = logging.getLogger(__name__)

# Resolve project root
#
# backend/data/database.py
#       parents[0] -> backend/data
#       parents[1] -> backend
#       parents[2] -> project root
#
_PROJECT_ROOT = Path(__file__).resolve().parents[2]

_DATABASE_DIR = _PROJECT_ROOT / "database"

# ---------------------------------------------------------------------
# Default database locations
# ---------------------------------------------------------------------

DEFAULT_PORTFOLIO_DB = _DATABASE_DIR / "portfolio.db"
DEFAULT_MARKET_DB = _DATABASE_DIR / "market_data.db"

# Schema files
#
# These are used by DatabaseInitializer during first-time setup.
#
DEFAULT_PORTFOLIO_SCHEMA = _DATABASE_DIR / "portfolio_schema.sql"
DEFAULT_MARKET_SCHEMA = _DATABASE_DIR / "market_schema.sql"

# Expected schema version.
#
# DatabaseInitializer verifies this value before allowing the
# application to start.
#
EXPECTED_SCHEMA_VERSION = "1.0"

# Common SQL parameter type.
#
# Example:
#
# execute_query(
#     "... WHERE portfolio_id = ?;",
#     (portfolio_id,)
# )
#
SQLParams = tuple[Any, ...]

# ---------------------------------------------------------------------
# Exceptions
# ---------------------------------------------------------------------


class DatabaseError(Exception):
    """
    Base exception for all database-related errors.

    Callers that simply want to catch any database failure should catch
    this exception.
    """


class SchemaVersionError(DatabaseError):
    """
    Raised when an existing database has an unexpected schema version.

    DatabaseInitializer is responsible for detecting version mismatches
    before the application begins using the database.
    """


# ---------------------------------------------------------------------
# DatabaseManager
# ---------------------------------------------------------------------


class DatabaseManager:
    """
    Low-level SQLite connection manager.

    Opens portfolio.db as the primary database and automatically attaches
    market_data.db under the alias:

        market

    This class intentionally contains no business logic.
    """

    def __init__(
        self,
        portfolio_db: Path = DEFAULT_PORTFOLIO_DB,
        market_db: Path = DEFAULT_MARKET_DB,
        portfolio_schema: Path = DEFAULT_PORTFOLIO_SCHEMA,
        market_schema: Path = DEFAULT_MARKET_SCHEMA,
    ) -> None:

        self._portfolio_db = Path(portfolio_db)
        self._market_db = Path(market_db)

        self._portfolio_schema = Path(portfolio_schema)
        self._market_schema = Path(market_schema)

        self._connection: Optional[sqlite3.Connection] = None

        # Tracks nested transaction depth.
        #
        # depth == 0
        #     No active transaction.
        #
        # depth > 0
        #     SAVEPOINTs are used for nested transactions.
        #
        self._transaction_depth = 0
        # Generates unique SAVEPOINT names for the lifetime of this connection.
        self._savepoint_counter = 0

    # -----------------------------------------------------------------
    # Connection lifecycle
    # -----------------------------------------------------------------

    def connect(self) -> None:
        """
        Open portfolio.db and attach market_data.db.

        Calling connect() when already connected is a no-op.
        """

        if self._connection is not None:
            logger.debug(
                "connect() called while already connected."
            )
            return

        self._connection = sqlite3.connect(
            self._portfolio_db,
            isolation_level=None,
        )

        self._connection.row_factory = sqlite3.Row

        conn = self.connection

        # Enforce foreign keys inside each database.
        conn.execute("PRAGMA foreign_keys = ON;")

        # Wait up to five seconds before raising
        # "database is locked".
        conn.execute("PRAGMA busy_timeout = 5000;")

        # Enable WAL mode.
        conn.execute("PRAGMA journal_mode = WAL;")

        # Recommended companion setting for WAL.
        conn.execute("PRAGMA synchronous = NORMAL;")

        # Attach shared market database.
        conn.execute(
            "ATTACH DATABASE ? AS market;",
            (str(self._market_db),),
        )

        # Configure attached database.
        conn.execute("PRAGMA market.journal_mode = WAL;")
        conn.execute("PRAGMA market.synchronous = NORMAL;")

        logger.info(
            "Connected to '%s' and attached '%s' as 'market'.",
            self._portfolio_db.name,
            self._market_db.name,
        )

    def disconnect(self) -> None:
        """
        Close the active SQLite connection.

        Any uncommitted transaction is rolled back automatically by
        SQLite.
        """

        if self._connection is None:
            logger.debug(
                "disconnect() called with no active connection."
            )
            return

        try:
            self._connection.execute(
                "DETACH DATABASE market;"
            )
        except sqlite3.Error:
            pass

        self._connection.close()
        self._connection = None

        logger.info("Database connection closed.")

    # -----------------------------------------------------------------
    # Context manager support
    # -----------------------------------------------------------------

    def __enter__(self) -> "DatabaseManager":
        """
        Open the database connection when entering a context manager.

        Example
        -------
            with DatabaseManager() as db:
                portfolio = db.fetch_one(
                    "SELECT * FROM portfolios WHERE portfolio_id = ?;",
                    (portfolio_id,)
                )
        """
        self.connect()
        return self

    def __exit__(
        self,
        exc_type: Optional[type],
        exc_value: Optional[BaseException],
        traceback: Optional[object],
    ) -> bool:
        """
        Close the database connection when leaving a context manager.

        Returning False allows any exception raised inside the
        context manager to propagate normally.
        """
        self.disconnect()
        return False

    # -----------------------------------------------------------------
    # Transaction management
    # -----------------------------------------------------------------

    @contextmanager
    def transaction(self) -> Iterator[None]:
        """
        Context manager providing atomic database transactions.

        Nested transactions are implemented using SQLite SAVEPOINTs.

        Example
        -------

        with db.transaction():

            transaction_repo.create(...)

            holding_repo.update(...)

            portfolio_repo.update_cash(...)

        If an exception occurs anywhere inside the transaction,
        all changes made within that transaction scope are rolled back.

        Nested Example
        --------------

        with db.transaction():

            portfolio.buy()

                with db.transaction():

                    transaction_repo.create(...)

        The outer transaction issues:

            BEGIN

        Inner transactions create SAVEPOINTs:

            SAVEPOINT sp_1

        On successful completion:

            RELEASE SAVEPOINT sp_1

            COMMIT

        If an exception occurs, only the appropriate transaction scope
        is rolled back.
        """

        conn = self.connection

        self._savepoint_counter += 1
        savepoint_name = f"sp_{self._savepoint_counter}"

        try:

            # ---------------------------------------------------------
            # Outermost transaction
            # ---------------------------------------------------------

            if self._transaction_depth == 0:

                conn.execute("BEGIN;")

                logger.debug(
                    "BEGIN transaction."
                )

            # ---------------------------------------------------------
            # Nested transaction
            # ---------------------------------------------------------

            else:

                conn.execute(
                    f"SAVEPOINT {savepoint_name};"
                )

                logger.debug(
                    "SAVEPOINT %s created.",
                    savepoint_name,
                )

            self._transaction_depth += 1

            yield

            self._transaction_depth -= 1

            # ---------------------------------------------------------
            # Commit outer transaction
            # ---------------------------------------------------------

            if self._transaction_depth == 0:

                conn.execute("COMMIT;")

                logger.debug(
                    "COMMIT transaction."
                )

            # ---------------------------------------------------------
            # Release nested savepoint
            # ---------------------------------------------------------

            else:

                conn.execute(
                    f"RELEASE SAVEPOINT {savepoint_name};"
                )

                logger.debug(
                    "Released SAVEPOINT %s.",
                    savepoint_name,
                )

        except Exception:

            self._transaction_depth -= 1

            # ---------------------------------------------------------
            # Roll back entire transaction
            # ---------------------------------------------------------

            if self._transaction_depth < 0:

                self._transaction_depth = 0

            if self._transaction_depth == 0:

                conn.execute("ROLLBACK;")

                logger.exception(
                    "Transaction rolled back."
                )

            # ---------------------------------------------------------
            # Roll back nested savepoint
            # ---------------------------------------------------------

            else:

                conn.execute(
                    f"ROLLBACK TO SAVEPOINT {savepoint_name};"
                )

                conn.execute(
                    f"RELEASE SAVEPOINT {savepoint_name};"
                )

                logger.exception(
                    "Rolled back SAVEPOINT %s.",
                    savepoint_name,
                )

            raise

    # -----------------------------------------------------------------
    # Query execution
    # -----------------------------------------------------------------

    def execute_query(
        self,
        sql: str,
        params: SQLParams = (),
    ) -> sqlite3.Cursor:
        """
        Execute a single SQL statement.

        Parameters
        ----------
        sql
            SQL statement to execute.

        params
            Positional parameters bound to '?' placeholders.

        Returns
        -------
        sqlite3.Cursor

        Raises
        ------
        DatabaseError
            If no database connection exists.

        sqlite3.Error
            If SQLite rejects the query.
        """

        conn = self.connection

        try:

            return conn.execute(sql, params)

        except sqlite3.Error as exc:

            logger.error(
                "SQL execution failed.\n"
                "SQL: %s\n"
                "Params: %s\n"
                "Error: %s",
                sql,
                params,
                exc,
            )

            raise

    def fetch_one(
        self,
        sql: str,
        params: SQLParams = (),
    ) -> Optional[sqlite3.Row]:
        """
        Execute a SELECT statement and return the first row.

        Returns None if no matching row exists.
        """

        return self.execute_query(
            sql,
            params,
        ).fetchone()

    def fetch_all(
        self,
        sql: str,
        params: SQLParams = (),
    ) -> list[sqlite3.Row]:
        """
        Execute a SELECT statement and return every matching row.

        Returns an empty list if no rows match.
        """

        return self.execute_query(
            sql,
            params,
        ).fetchall()

    # -----------------------------------------------------------------
    # Row conversion helpers
    # -----------------------------------------------------------------

    @staticmethod
    def row_to_dict(
        row: Optional[sqlite3.Row],
    ) -> Optional[dict[str, Any]]:
        """
        Convert a sqlite3.Row into a dictionary.

        Parameters
        ----------
        row
            Row returned by fetch_one().

        Returns
        -------
        dict | None

        Example
        -------
        row = db.fetch_one(...)
        data = DatabaseManager.row_to_dict(row)
        """

        if row is None:
            return None

        return dict(row)

    @staticmethod
    def rows_to_dicts(
        rows: list[sqlite3.Row],
    ) -> list[dict[str, Any]]:
        """
        Convert a list of sqlite3.Row objects into dictionaries.

        Useful when serializing query results for APIs or Streamlit.

        Parameters
        ----------
        rows
            Result of fetch_all().

        Returns
        -------
        list[dict]
        """

        return [dict(row) for row in rows]

    # -----------------------------------------------------------------
    # Connection properties
    # -----------------------------------------------------------------

    @property
    def connection(self) -> sqlite3.Connection:
        """
        Return the active SQLite connection.

        Raises
        ------
        DatabaseError
            If no connection is currently open.
        """

        if self._connection is None:
            raise DatabaseError(
                "No active database connection.\n"
                "Call connect() or use DatabaseManager "
                "as a context manager before executing queries."
            )

        return self._connection

    @property
    def is_connected(self) -> bool:
        """
        True if a database connection is currently open.
        """

        return self._connection is not None

    # -----------------------------------------------------------------
    # Database path properties
    # -----------------------------------------------------------------

    @property
    def portfolio_db_path(self) -> Path:
        """
        Location of portfolio.db.
        """

        return self._portfolio_db

    @property
    def market_db_path(self) -> Path:
        """
        Location of market_data.db.
        """

        return self._market_db

    @property
    def portfolio_schema_path(self) -> Path:
        """
        Location of portfolio_schema.sql.
        """

        return self._portfolio_schema

    @property
    def market_schema_path(self) -> Path:
        """
        Location of market_schema.sql.
        """

        return self._market_schema
