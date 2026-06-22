"""AMCOS ETL package bootstrap."""

from __future__ import annotations

import sys
from pathlib import Path

_ETL_ROOT = Path(__file__).resolve().parent
if str(_ETL_ROOT) not in sys.path:
    sys.path.insert(0, str(_ETL_ROOT))
