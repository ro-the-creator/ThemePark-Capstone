#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RAW_DB="$REPO_ROOT/data/themepark-raw.db"
TMP_DB=$(mktemp "${TMPDIR:-/tmp}/themepark_validate.XXXXXX.db")

cleanup() {
    rm -f "$TMP_DB"
}

trap cleanup EXIT INT TERM

cp "$RAW_DB" "$TMP_DB"
sqlite3 "$TMP_DB" < "$REPO_ROOT/sql/01_wiring.sql" >/dev/null
sqlite3 "$TMP_DB" < "$REPO_ROOT/sql/02_cleaning_feature_pipeline.sql"

echo "[orphan_key_audit]"
sqlite3 -header -column "$TMP_DB" "SELECT * FROM vw_orphan_key_audit;"

echo
echo "[wait_bucket_summary]"
sqlite3 -header -column "$TMP_DB" "SELECT * FROM vw_feature_wait_bucket_summary;"

echo
echo "[guest_spend_segment_summary]"
sqlite3 -header -column "$TMP_DB" "SELECT * FROM vw_feature_guest_spend_segment_summary;"

echo
echo "[promo_code_performance]"
sqlite3 -header -column "$TMP_DB" "SELECT * FROM vw_feature_promo_code_performance;"