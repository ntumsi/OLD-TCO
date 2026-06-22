"""PostgreSQL connection and bulk-load helpers for AMCOS ETL."""

from __future__ import annotations

import logging
import re
from contextlib import contextmanager
from typing import Optional, Sequence

import pandas as pd
import psycopg2
from psycopg2 import sql
from psycopg2.extras import execute_values

from config.settings import BATCH_SIZE, DB_CONNECTION_STRING

logger = logging.getLogger(__name__)


def _normalized(value: str) -> str:
    return re.sub(r"[^0-9a-z]", "", value.lower())


def split_qualified_table(table_name: str) -> tuple[str, str]:
    cleaned = table_name.strip().replace("[", "").replace("]", "")
    if "." in cleaned:
        schema_name, relation_name = cleaned.split(".", 1)
        return schema_name, relation_name
    return "public", cleaned


def qualified_identifier(table_name: str) -> sql.SQL:
    schema_name, relation_name = split_qualified_table(table_name)
    return sql.SQL("{}.{}").format(sql.Identifier(schema_name), sql.Identifier(relation_name))


@contextmanager
def get_connection():
    if not DB_CONNECTION_STRING:
        raise ValueError("AMCOS_DB_CONNECTION is required for database operations.")
    conn = psycopg2.connect(DB_CONNECTION_STRING)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def fetch_dataframe(query: str, params: Optional[Sequence[object]] = None) -> pd.DataFrame:
    with get_connection() as conn:
        return pd.read_sql_query(query, conn, params=params)


def _table_columns(cur, table_name: str) -> list[str]:
    schema_name, relation_name = split_qualified_table(table_name)
    cur.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        ORDER BY ordinal_position
        """,
        (schema_name, relation_name),
    )
    return [row[0] for row in cur.fetchall()]


def load_dataframe(
    df: pd.DataFrame,
    table_name: str,
    *,
    conflict_columns: Optional[Sequence[str]] = None,
    update_columns: Optional[Sequence[str]] = None,
    delete_where_clause: Optional[str] = None,
    delete_params: Optional[Sequence[object]] = None,
    chunk_size: int = BATCH_SIZE,
) -> int:
    if df.empty:
        logger.info("No rows to load for %s", table_name)
        return 0

    working = df.copy()
    working.columns = [str(column) for column in working.columns]

    with get_connection() as conn:
        with conn.cursor() as cur:
            if delete_where_clause:
                cur.execute(
                    sql.SQL("DELETE FROM {} WHERE ").format(qualified_identifier(table_name)) + sql.SQL(delete_where_clause),
                    delete_params,
                )

            table_columns = _table_columns(cur, table_name)
            lookup = {_normalized(column): column for column in table_columns}
            selected_columns: list[str] = []
            db_columns: list[str] = []
            for column in working.columns:
                match = lookup.get(_normalized(column))
                if match:
                    selected_columns.append(column)
                    db_columns.append(match)

            if not db_columns:
                raise ValueError(f"No matching destination columns found for {table_name}.")

            records = working[selected_columns].where(pd.notna(working[selected_columns]), None).values.tolist()
            insert_head = sql.SQL("INSERT INTO {} ({}) VALUES %s").format(
                qualified_identifier(table_name),
                sql.SQL(", ").join(sql.Identifier(column) for column in db_columns),
            )

            if conflict_columns:
                db_conflicts = [lookup.get(_normalized(column), column) for column in conflict_columns]
                db_updates = [
                    lookup.get(_normalized(column), column)
                    for column in (update_columns or db_columns)
                    if lookup.get(_normalized(column), column) not in db_conflicts
                ]
                if db_updates:
                    update_clause = sql.SQL(", ").join(
                        sql.SQL("{0} = EXCLUDED.{0}").format(sql.Identifier(column))
                        for column in db_updates
                    )
                    insert_head += sql.SQL(" ON CONFLICT ({}) DO UPDATE SET ").format(
                        sql.SQL(", ").join(sql.Identifier(column) for column in db_conflicts)
                    ) + update_clause
                else:
                    insert_head += sql.SQL(" ON CONFLICT ({}) DO NOTHING").format(
                        sql.SQL(", ").join(sql.Identifier(column) for column in db_conflicts)
                    )

            execute_values(cur, insert_head.as_string(cur), records, page_size=chunk_size)
            return len(records)
