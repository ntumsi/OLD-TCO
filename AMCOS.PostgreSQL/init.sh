#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# init.sh — Apply all AMCOS migrations then load seed data.
#
# Usage:
#   ./AMCOS.PostgreSQL/init.sh [OPTIONS]
#
# Options:
#   --host     PostgreSQL host      (default: localhost)
#   --port     PostgreSQL port      (default: 5432)
#   --db       Database name        (default: amcos)
#   --user     PostgreSQL username  (default: postgres)
#   --password PostgreSQL password  (default: postgr3s)
#   --fresh    Drop and recreate the database before running (destructive)
#   --no-seed  Run migrations only, skip seed data
#   --help     Show this message
#
# The script stops immediately if any SQL file fails (set -e + ON_ERROR_STOP).
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults — override via flags or environment variables.
PG_HOST="${PGHOST:-localhost}"
PG_PORT="${PGPORT:-5432}"
PG_DB="${PGDATABASE:-amcos}"
PG_USER="${PGUSER:-postgres}"
PG_PASSWORD="${PGPASSWORD:-postgr3s}"
RUN_SEED=true
FRESH=false

usage() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# \{0,1\}//'
    exit 0
}

# Parse flags.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)     PG_HOST="$2";     shift 2 ;;
        --port)     PG_PORT="$2";     shift 2 ;;
        --db)       PG_DB="$2";       shift 2 ;;
        --user)     PG_USER="$2";     shift 2 ;;
        --password) PG_PASSWORD="$2"; shift 2 ;;
        --fresh)    FRESH=true;       shift   ;;
        --no-seed)  RUN_SEED=false;   shift   ;;
        --help|-h)  usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

export PGPASSWORD="$PG_PASSWORD"

# psql against the target database.
run_sql() {
    local file="$1"
    echo "  → $(basename "$file")"
    psql \
        --host="$PG_HOST" \
        --port="$PG_PORT" \
        --dbname="$PG_DB" \
        --username="$PG_USER" \
        --variable=ON_ERROR_STOP=1 \
        --quiet \
        --file="$file"
}

# psql against the postgres maintenance database (for DROP/CREATE DATABASE).
run_admin() {
    psql \
        --host="$PG_HOST" \
        --port="$PG_PORT" \
        --dbname="postgres" \
        --username="$PG_USER" \
        --variable=ON_ERROR_STOP=1 \
        --quiet \
        --command="$1"
}

echo "=== AMCOS database initialisation ==="
echo "    host:     $PG_HOST:$PG_PORT"
echo "    database: $PG_DB"
echo "    user:     $PG_USER"
echo ""

if [[ "$FRESH" == true ]]; then
    echo "--- Fresh reset ---"
    echo "  → dropping $PG_DB"
    run_admin "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$PG_DB' AND pid <> pg_backend_pid();"
    run_admin "DROP DATABASE IF EXISTS \"$PG_DB\";"
    run_admin "CREATE DATABASE \"$PG_DB\";"
    echo "  → database recreated"
    echo ""
fi

echo "--- Migrations ---"
for f in \
    "$SCRIPT_DIR/migrations/000_schemas.sql" \
    "$SCRIPT_DIR/migrations/001_lookup_tables.sql" \
    "$SCRIPT_DIR/migrations/002_data_tables.sql" \
    "$SCRIPT_DIR/migrations/003_webuser_tables.sql" \
    "$SCRIPT_DIR/migrations/004_web_tables.sql" \
    "$SCRIPT_DIR/migrations/005_warehouse_tables.sql" \
    "$SCRIPT_DIR/migrations/006_functions.sql" \
    "$SCRIPT_DIR/migrations/007_stored_procedures.sql" \
    "$SCRIPT_DIR/migrations/008_views.sql"
do
    run_sql "$f"
done

if [[ "$RUN_SEED" == true ]]; then
    echo ""
    echo "--- Seed data ---"
    for f in \
        "$SCRIPT_DIR/seed/001_versions_and_lookups.sql" \
        "$SCRIPT_DIR/seed/002_cost_elements.sql" \
        "$SCRIPT_DIR/seed/003_warehouse_and_web.sql" \
        "$SCRIPT_DIR/seed/004_demo_users_and_project.sql"
    do
        run_sql "$f"
    done
fi

echo ""
echo "=== Done ==="
