"""Shared environment-based settings for AMCOS ETL scripts."""

from __future__ import annotations

import os
import sys
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

# ---------------------------------------------------------------------------
# Validation – fail fast so operators get a clear error before any DB work.
# ---------------------------------------------------------------------------

_errors: list[str] = []

if not DB_CONNECTION_STRING:
    _errors.append(
        "AMCOS_DB_CONNECTION is not set. "
        "Set it to a valid PostgreSQL connection string, e.g.:\n"
        "  export AMCOS_DB_CONNECTION='host=db-host dbname=amcos user=amcos_user ******'"
    )

for _name, _path in (("AMCOS_DATA_DIR", DATA_DIR), ("AMCOS_OUTPUT_DIR", OUTPUT_DIR)):
    try:
        _path.mkdir(parents=True, exist_ok=True)
    except OSError as _exc:
        _errors.append(f"Cannot create {_name} directory '{_path}': {_exc}")

if _errors:
    print("AMCOS ETL configuration errors:\n", file=sys.stderr)
    for _msg in _errors:
        print(f"  - {_msg}\n", file=sys.stderr)
    sys.exit(1)
