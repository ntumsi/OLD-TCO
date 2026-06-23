"""Orchestrate all cost imports, replacing the AMCOS.SSIS.ImportAll package."""

from __future__ import annotations

import logging

from common.logging_utils import configure_logging
from datasync.import_costs import import_costs

logger = logging.getLogger(__name__)


def import_all() -> dict[str, int]:
    """Run import_costs which covers ActiveDuty, ARNG, and USAR cost datasets."""
    results = import_costs()
    logger.info("ImportAll completed: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    import_all()
