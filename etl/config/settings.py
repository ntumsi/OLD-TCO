"""Shared environment-based settings for AMCOS ETL scripts."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

ETL_ROOT = Path(__file__).resolve().parents[1]
DB_CONNECTION_STRING = os.environ.get("AMCOS_DB_CONNECTION", "")
DATA_DIR = Path(os.environ.get("AMCOS_DATA_DIR", str(ETL_ROOT / "data"))).expanduser()
OUTPUT_DIR = Path(os.environ.get("AMCOS_OUTPUT_DIR", str(ETL_ROOT / "output"))).expanduser()
LOG_LEVEL = os.environ.get("AMCOS_LOG_LEVEL", os.environ.get("LOG_LEVEL", "INFO")).upper()
AMCOS_VERSION_ID = os.environ.get("AMCOS_VERSION_ID", "202501")
BATCH_SIZE = int(os.environ.get("AMCOS_BATCH_SIZE", "1000"))
