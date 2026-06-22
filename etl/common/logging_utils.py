"""Logging helpers for AMCOS ETL scripts."""

from __future__ import annotations

import logging
from typing import Optional

from config.settings import LOG_LEVEL


def configure_logging(level: Optional[str] = None) -> None:
    """Configure root logging once for CLI-friendly ETL output."""
    if logging.getLogger().handlers:
        logging.getLogger().setLevel(level or LOG_LEVEL)
        return
    logging.basicConfig(
        level=level or LOG_LEVEL,
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    )
