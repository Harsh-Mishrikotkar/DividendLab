"""
backend/data/repositories/settings_repository.py

Project Niyati — Application Settings Repository
================================================

Provides typed access to the application's global settings stored in
the app_settings table.

Responsibilities
----------------
This repository owns all SQL related to application settings.

It does NOT perform any business logic.

All settings are stored in SQLite as TEXT. Typed helper methods convert
the values into Python types for callers.

Example
-------

settings = SettingsRepository(db)

inflation = settings.get_float(
    "default_inflation_rate"
)

currency = settings.get_string(
    "base_currency"
)
"""

from __future__ import annotations

from typing import Optional

from backend.data.database import DatabaseManager


class SettingsRepository:
    """
    Repository for application-wide settings.
    """

    def __init__(
        self,
        db: DatabaseManager,
    ) -> None:

        self.db = db
        self._cache: dict[str, str] = {}

        self._load_cache()

    # --------------------------------------------------------------
    # Basic access
    # --------------------------------------------------------------

    def get(
        self,
        setting_name: str,
    ) -> Optional[str]:
        """
        Return the raw setting value.

        Results are cached after the first lookup.
        """

        # Return cached value if available.
        if setting_name in self._cache:
            return self._cache[setting_name]

        row = self.db.fetch_one(
            """
            SELECT setting_value
            FROM app_settings
            WHERE setting_name = ?;
            """,
            (setting_name,),
        )

        if row is None:
            return None

        value = row["setting_value"]

        # Store in cache for future requests.
        self._cache[setting_name] = value

        return value

    def exists(
        self,
        setting_name: str,
    ) -> bool:
        """
        Return True if the setting exists.
        """

        return self.get(setting_name) is not None

    # --------------------------------------------------------------
    # Typed getters
    # --------------------------------------------------------------

    def get_string(
        self,
        setting_name: str,
        default: Optional[str] = None,
    ) -> Optional[str]:
        """
        Return a setting as a string.
        """

        value = self.get(setting_name)

        if value is None:
            return default

        return value

    def get_int(
        self,
        setting_name: str,
        default: Optional[int] = None,
    ) -> Optional[int]:
        """
        Return a setting as an integer.
        """

        value = self.get(setting_name)

        if value is None:
            return default

        return int(value)

    def get_float(
        self,
        setting_name: str,
        default: Optional[float] = None,
    ) -> Optional[float]:
        """
        Return a setting as a float.
        """

        value = self.get(setting_name)

        if value is None:
            return default

        return float(value)

    def get_bool(
        self,
        setting_name: str,
        default: Optional[bool] = None,
    ) -> Optional[bool]:
        """
        Return a setting as a boolean.

        Accepted true values:

            true
            1
            yes

        Accepted false values:

            false
            0
            no
        """

        value = self.get(setting_name)

        if value is None:
            return default

        value = value.strip().lower()

        if value in {"true", "1", "yes"}:
            return True

        if value in {"false", "0", "no"}:
            return False

        raise ValueError(
            f"Setting '{setting_name}' "
            f"cannot be converted to bool."
        )

    # --------------------------------------------------------------
    # Updates
    # --------------------------------------------------------------

    def set(
        self,
        setting_name: str,
        value: object,
    ) -> None:
        """
        Update an existing application setting.

        Raises
        ------
        ValueError
            If the setting does not exist.
        """

        if not self.exists(setting_name):
            raise ValueError(
                f"Unknown application setting: "
                f"{setting_name}"
            )

        self.db.execute_query(
                """
                UPDATE app_settings
                SET setting_value = ?
                WHERE setting_name = ?;
                """,
                (str(value), setting_name),
            )

        # Keep the cache synchronized with the database.
        self._cache[setting_name] = str(value)

    # --------------------------------------------------------------
    # Internal
    # --------------------------------------------------------------

    def _load_cache(self) -> None:
        rows = self.db.fetch_all(
            """
            SELECT setting_name, setting_value
            FROM app_settings;
            """
        )

        self._cache = {
            row["setting_name"]: row["setting_value"]
            for row in rows
        }