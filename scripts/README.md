# Scripts Overview For Evaluation

## Executive Overview

The scripts folder contains the operational entry points that make this capstone reproducible. These scripts standardize how the analysis database is built and how core pipeline outputs are validated, so reviewers can run the same workflow with consistent results.

<br>


The scripts layer sits between raw data and SQL analysis.

- Build workflow
  - Creates a fresh working analysis database from the immutable raw source.
- Validation workflow
  - Verifies that core cleaned and engineered outputs are available and consistent.

This keeps setup logic out of notebooks and prevents ad hoc manual steps.

<div align='center'>

## Scripts In This Folder

</div>

- [scripts/build_analysis_db.sh](scripts/build_analysis_db.sh)
  - Purpose: creates data/themepark_analysis.db from data/themepark-raw.db.
  - What it runs:
    - sql/01_wiring.sql
    - sql/02_cleaning_feature_pipeline.sql
  - Why it matters:
    - guarantees a deterministic analysis database for SQL files and notebook visuals.
  - Expected output:
    - a success message confirming the source and generated database paths.

- [scripts/validate_pipeline.sh](scripts/validate_pipeline.sh)
  - Purpose: validates pipeline outputs on a temporary database copy.
  - What it runs:
    - sql/01_wiring.sql
    - sql/02_cleaning_feature_pipeline.sql
    - key validation queries for orphan keys, wait buckets, spend segments, and promo performance.
  - Why it matters:
    - proves that the reproducible path works from raw data without altering source files.
  - Expected output sections:
    - [orphan_key_audit]
    - [wait_bucket_summary]
    - [guest_spend_segment_summary]
    - [promo_code_performance]

## Key Goal: Reproducibility

- Immutable source: data/themepark-raw.db remains untouched.
- Generated working state: data/themepark_analysis.db is rebuilt as needed.
- Repeatable execution: scripts can be run in the same order for consistent evaluator results.
- Isolation for validation: temporary databases are used for checks to avoid side effects.

## Quickstart

From the repository root in terminal, run:

```bash
./scripts/build_analysis_db.sh
./scripts/validate_pipeline.sh
```

This will run the raw database through the pipeline, producing a clean, analysis-ready database. 

> [!NOTE]
> For pipeline specifics, see [cleaning documentation](../sql/README.md).