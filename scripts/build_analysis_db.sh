#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RAW_DB="$REPO_ROOT/data/themepark-raw.db"
ANALYSIS_DB="$REPO_ROOT/data/themepark_analysis.db"

if [ ! -f "$RAW_DB" ]; then
    echo "Missing raw database: $RAW_DB" >&2
    exit 1
fi

cp "$RAW_DB" "$ANALYSIS_DB"
sqlite3 "$ANALYSIS_DB" < "$REPO_ROOT/sql/01_wiring.sql" >/dev/null
sqlite3 "$ANALYSIS_DB" < "$REPO_ROOT/sql/02_cleaning_feature_pipeline.sql" >/dev/null

echo "Built $ANALYSIS_DB from $RAW_DB"