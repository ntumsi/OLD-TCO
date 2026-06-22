"""File readers and discovery helpers used by AMCOS ETL modules."""

from __future__ import annotations

import csv
import re
from pathlib import Path
from typing import Iterable, Optional, Sequence

import pandas as pd


def ensure_directory(path: Path | str) -> Path:
    path = Path(path)
    path.mkdir(parents=True, exist_ok=True)
    return path


def normalize_column_name(value: str) -> str:
    value = re.sub(r"([^0-9A-Za-z]+)", "_", str(value).strip())
    value = re.sub(r"([a-z])([A-Z])", r"\1_\2", value)
    return re.sub(r"_+", "_", value).strip("_").lower()


def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df.columns = [normalize_column_name(column) for column in df.columns]
    return df


def clean_loaded_frame(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    return working.dropna(how="all")


def find_first_existing(base_dir: Path | str, patterns: Sequence[str]) -> Optional[Path]:
    base = Path(base_dir)
    for pattern in patterns:
        matches = sorted(base.glob(pattern))
        if matches:
            return matches[0]
    return None


def find_all_existing(base_dir: Path | str, patterns: Sequence[str]) -> list[Path]:
    base = Path(base_dir)
    results: list[Path] = []
    for pattern in patterns:
        results.extend(base.glob(pattern))
    return sorted({path.resolve() for path in results})


def sniff_delimiter(file_path: Path, sample_size: int = 4096) -> Optional[str]:
    sample = file_path.read_text(encoding="utf-8-sig", errors="ignore")[:sample_size]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",\t|;")
        return dialect.delimiter
    except csv.Error:
        return None


def read_csv_flexible(
    file_path: Path | str,
    *,
    delimiter: Optional[str] = None,
    header: int | None = 0,
    skiprows: int = 0,
    dtype: object = str,
) -> pd.DataFrame:
    path = Path(file_path)
    candidate_delimiters = [delimiter] if delimiter else [sniff_delimiter(path), ",", "\t", "|", ";"]
    seen: list[str] = []
    for candidate in candidate_delimiters:
        if not candidate or candidate in seen:
            continue
        seen.append(candidate)
        try:
            df = pd.read_csv(
                path,
                sep=candidate,
                dtype=dtype,
                header=header,
                skiprows=skiprows,
                engine="python",
                encoding="utf-8-sig",
            )
            if df.shape[1] > 1:
                return df
        except Exception:
            continue
    return pd.read_fwf(path, dtype=dtype, skiprows=skiprows, header=header, encoding="utf-8-sig")


def read_excel_sheet(file_path: Path | str, sheet_name: str | int = 0) -> pd.DataFrame:
    return pd.read_excel(Path(file_path), sheet_name=sheet_name, dtype=str)


def coerce_numeric(df: pd.DataFrame, columns: Iterable[str]) -> pd.DataFrame:
    df = df.copy()
    for column in columns:
        if column in df.columns:
            df[column] = pd.to_numeric(df[column], errors="coerce")
    return df
