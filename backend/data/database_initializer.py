"""
backend/data/database_initializer.py

Project Niyati — Database Initialization
========================================

Creates Project Niyati's SQLite databases from their schema files and
verifies that existing databases match the schema version expected by
the application.

Responsibilities
----------------
This module is responsible only for installation and verification.

It does NOT manage database connections during normal application
runtime. That responsibility belongs to DatabaseManager.

Initialization Order
--------------------
market_data.db is created before portfolio.db because portfolio
records reference assets stored in market_data.db.

Future Expansion
----------------
This module is designed so schema migrations can later be added without
changing DatabaseManager.

Example
-------

db = DatabaseManager()

initializer = DatabaseInitializer(db)
initializer.initialize_databases()
"""

from __future__ import annotations

import logging
import sqlite3

from pathlib import Path

from backend.data.database import (
    DatabaseManager,
    DatabaseError,
    SchemaVersionError,
    EXPECTED_SCHEMA_VERSION,
)

logger = logging.getLogger(__name__)


class DatabaseInitializer:
    """
    Creates and verifies Project Niyati databases.
    """

    def __init__(
        self,
        database_manager: DatabaseManager,
    ) -> None:

        self.db = database_manager

    # --------------------------------------------------------------
    # Public interface
    # --------------------------------------------------------------

    def initialize_databases(self) -> None:
        """
        Ensure every required database exists and has the expected
        schema version.

        Databases are created only if they do not already exist.

        Existing databases are verified.

        Raises
        ------
        DatabaseError
            Schema file missing.

        SchemaVersionError
            Database version mismatch.
        """

        logger.info(
            "Initializing Project Niyati databases."
        )

        self._initialize_single_database(
            db_path=self.db.market_db_path,
            schema_path=self.db.market_schema_path,
            database_name="market_data",
        )

        self._initialize_single_database(
            db_path=self.db.portfolio_db_path,
            schema_path=self.db.portfolio_schema_path,
            database_name="portfolio",
        )

        logger.info(
            "Database initialization complete."
        )

    # --------------------------------------------------------------
    # Internal helpers
    # --------------------------------------------------------------

    def _initialize_single_database(
        self,
        db_path: Path,
        schema_path: Path,
        database_name: str,
    ) -> None:
        """
        Create a database if it does not exist.

        Existing databases are verified.
        """

        db_path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        is_new_database = (
            not db_path.exists()
            or db_path.stat().st_size == 0
        )

        connection = sqlite3.connect(
            db_path,
            isolation_level=None,
        )

        connection.row_factory = sqlite3.Row

        connection.execute(
            "PRAGMA foreign_keys = ON;"
        )

        connection.execute(
            "PRAGMA journal_mode = WAL;"
        )

        connection.execute(
            "PRAGMA synchronous = NORMAL;"
        )

        try:

            if is_new_database:

                self._create_database(
                    connection,
                    schema_path,
                    database_name,
                )

            else:

                self._verify_schema_version(
                    connection,
                    database_name,
                )

        finally:

            connection.close()

    def _create_database(
        self,
        connection: sqlite3.Connection,
        schema_path: Path,
        database_name: str,
    ) -> None:
        """
        Execute the schema SQL file.
        """

        if not schema_path.exists():

            raise DatabaseError(
                f"Schema file not found:\n"
                f"{schema_path}"
            )

        logger.info(
            "Creating %s database.",
            database_name,
        )

        schema_sql = schema_path.read_text(
            encoding="utf-8"
        )

        connection.executescript(schema_sql)

        logger.info(
            "%s database created successfully.",
            database_name,
        )

    def _verify_schema_version(
        self,
        connection: sqlite3.Connection,
        database_name: str,
    ) -> None:
        """
        Verify schema_version stored in database_metadata.
        """

        try:

            row = connection.execute(
                """
                SELECT value
                FROM database_metadata
                WHERE key = 'schema_version';
                """
            ).fetchone()

        except sqlite3.OperationalError:

            logger.warning(
                "%s database has no database_metadata table.",
                database_name,
            )

            return

        if row is None:

            logger.warning(
                "%s database has no schema_version.",
                database_name,
            )

            return

        stored_version = row["value"]

        if stored_version != EXPECTED_SCHEMA_VERSION:

            raise SchemaVersionError(
                f"{database_name} database "
                f"expects schema "
                f"{EXPECTED_SCHEMA_VERSION}, "
                f"but found "
                f"{stored_version}."
            )

        logger.info(
            "%s schema version verified (%s).",
            database_name,
            stored_version,
        )