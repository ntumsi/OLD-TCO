"""Default ETL entrypoint."""

from __future__ import annotations

from common.logging_utils import configure_logging
from dataload.main import run_all


def main() -> None:
    configure_logging()
    run_all()


if __name__ == "__main__":
    main()
